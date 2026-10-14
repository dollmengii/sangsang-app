-- 오늘의 카드(기획서 6장), 대화 목록과 첫 질문 카드(7장), 차단 처리.

insert into public.app_config (key, value) values
  ('extra_card_count',      '4'),
  ('active_within_days',    '7'),
  ('newcomer_days',         '3'),
  ('match_same_sido',       'false'),  -- 친구용은 사람이 적어서 지역을 따지지 않는다. 공개 출시 때 true.
  ('match_idle_close_hours','48')
on conflict (key) do nothing;

-- 카드 날짜는 한국 시간 기준
create or replace function public.kst_today() returns date
language sql stable as $$ select (now() at time zone 'Asia/Seoul')::date $$;

create or replace function public.age_of(birth_year int) returns int
language sql immutable as $$ select extract(year from (now() at time zone 'Asia/Seoul'))::int - birth_year $$;

-- 카드에 나올 수 있는 사람: 가입을 마쳤고, 정지되지 않았고, 무드 이미지가 있는 얼굴 사진이 있다.
create or replace function public.is_card_ready(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles pr
    where pr.id = p and pr.onboarded_at is not null and pr.status <> 'banned'
      and exists (select 1 from public.photos ph where ph.owner = p and ph.is_face and ph.mood_path is not null)
  )
$$;

-- viewer에게 보여줄 후보를 공정하게 고른다.
-- 서로의 성별·나이 조건이 맞고, 최근 N일 안에 들어온 사람. 이미 본 적 있거나 좋아요/넘기기, 대화방, 차단이 있는 사람은 뺀다.
-- 최근 7일 노출이 적은 사람 → 새로 온 사람 → 무작위 순. 얼굴로 순위를 매기지 않는다.
create or replace function public._card_candidates(v uuid, p_date date, p_limit int)
returns table (shown uuid)
language sql volatile security definer set search_path = public as $$
  with me as (select * from public.profiles where id = v)
  select c.id
  from public.profiles c, me
  where c.id <> me.id
    and public.is_card_ready(c.id)
    and c.gender = me.seeking and c.seeking = me.gender
    and public.age_of(c.birth_year) between me.age_min and me.age_max
    and public.age_of(me.birth_year) between c.age_min and c.age_max
    and c.last_active_at > now() - make_interval(days => public.cfg_int('active_within_days'))
    and (coalesce((select value from public.app_config where key = 'match_same_sido'), 'false') <> 'true'::jsonb
         or c.region_sido = me.region_sido)
    and not exists (select 1 from public.daily_cards d where d.viewer = v and d.shown = c.id)
    and not exists (select 1 from public.likes l where l.from_id = v and l.to_id = c.id)
    and not exists (select 1 from public.matches m where m.user_a = least(v, c.id) and m.user_b = greatest(v, c.id))
    and not exists (select 1 from public.blocks b where (b.blocker = v and b.blocked = c.id) or (b.blocker = c.id and b.blocked = v))
  order by
    (select count(*) from public.daily_cards d2 where d2.shown = c.id and d2.card_date > p_date - 7),
    (c.created_at > now() - make_interval(days => public.cfg_int('newcomer_days'))) desc,
    random()
  limit p_limit
$$;
revoke all on function public._card_candidates(uuid, date, int) from public, anon, authenticated;

-- 밤 10시(한국 시간)에 pg_cron으로 돌린다. 이미 오늘 카드를 받은 사람은 건너뛴다.
create or replace function public.generate_daily_cards(p_date date default public.kst_today())
returns int
language plpgsql security definer set search_path = public as $$
declare
  v uuid;
  n int := 0;
  k int;
begin
  for v in
    select id from public.profiles
    where onboarded_at is not null and status <> 'banned'
      and last_active_at > now() - make_interval(days => public.cfg_int('active_within_days'))
      and not exists (select 1 from public.daily_cards d where d.viewer = profiles.id and d.card_date = p_date)
    order by random()
  loop
    insert into public.daily_cards (viewer, shown, card_date)
      select v, shown, p_date from public._card_candidates(v, p_date, public.cfg_int('daily_card_count'));
    get diagnostics k = row_count;
    n := n + k;
  end loop;
  return n;
end $$;
revoke all on function public.generate_daily_cards(date) from public, anon, authenticated;

-- 크레딧 3개로 오늘 카드 4장 더 보기 (기획서 6장)
create or replace function public.buy_extra_cards() returns int
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  cost int := public.cfg_int('extra_cards_cost');
  added int;
begin
  if cost > 0 and public.credit_balance(me) < cost then raise exception 'insufficient_credits'; end if;
  insert into public.daily_cards (viewer, shown, card_date, extra)
    select me, shown, public.kst_today(), true
    from public._card_candidates(me, public.kst_today(), public.cfg_int('extra_card_count'));
  get diagnostics added = row_count;
  if added = 0 then raise exception 'no_more_cards'; end if;
  if cost > 0 then
    insert into public.credit_ledger (user_id, delta, kind, note) values (me, -cost, 'spend', '카드 더 보기');
  end if;
  return added;
end $$;

-- 내 오늘 카드. 상대의 원본 사진 경로는 주지 않고 무드 이미지 경로만 준다.
create or replace function public.today_cards()
returns table (
  profile_id uuid, nickname text, age int, region text, bio text, qa jsonb,
  mood_path text, tags jsonb, liked boolean, extra boolean
)
language sql stable security definer set search_path = public as $$
  select pr.id, pr.nickname, public.age_of(pr.birth_year),
         concat_ws(' ', pr.region_sido, pr.region_sigungu), pr.bio, pr.qa,
         (select ph.mood_path from public.photos ph where ph.owner = pr.id and ph.is_face and ph.mood_path is not null
           order by ph.is_primary desc, ph.created_at limit 1),
         coalesce((select jsonb_agg(jsonb_build_object(
                     'slot', pt.slot, 'id', t.id, 'category', t.category,
                     'name', case when pr.gender = 'female' then t.name_female else t.name_male end,
                     'source', pt.source) order by t.category, t.sort_order)
                   from public.profile_tags pt join public.tags t on t.id = pt.tag_id
                   where pt.profile_id = pr.id and not pt.hidden and t.enabled), '[]'::jsonb),
         (select l.liked from public.likes l where l.from_id = auth.uid() and l.to_id = pr.id),
         d.extra
  from public.daily_cards d
  join public.profiles pr on pr.id = d.shown
  where d.viewer = auth.uid() and d.card_date = public.kst_today() and pr.status <> 'banned'
  order by d.extra, pr.id
$$;

-- 앱을 열 때마다 부른다. 최근 7일 안에 들어온 사람만 카드에 나온다.
create or replace function public.touch_active() returns void
language sql security definer set search_path = public as $$
  update public.profiles set last_active_at = now() where id = auth.uid()
$$;

-- ───────────────────────── 대화 ─────────────────────────
create table public.match_reads (
  match_id     uuid not null references public.matches on delete cascade,
  user_id      uuid not null references public.profiles on delete cascade,
  last_read_id bigint not null default 0,
  primary key (match_id, user_id)
);
alter table public.match_reads enable row level security;
create policy match_reads_self on public.match_reads for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_match_member(match_id));

-- 내 대화방 목록
create or replace function public.my_matches()
returns table (
  match_id uuid, other_id uuid, nickname text, mood_path text, created_at timestamptz, closed boolean,
  last_body text, last_at timestamptz, last_sender uuid, unread int, my_count int, their_count int, revealed boolean
)
language sql stable security definer set search_path = public as $$
  with mine as (
    select m.*, case when m.user_a = auth.uid() then m.user_b else m.user_a end as other
    from public.matches m where auth.uid() in (m.user_a, m.user_b)
  )
  select mine.id, mine.other, pr.nickname,
         (select ph.mood_path from public.photos ph where ph.owner = mine.other and ph.is_face and ph.mood_path is not null
           order by ph.is_primary desc, ph.created_at limit 1),
         mine.created_at, mine.closed_at is not null,
         lm.body, lm.created_at, lm.sender,
         (select count(*)::int from public.messages x where x.match_id = mine.id and x.sender <> auth.uid()
            and x.id > coalesce((select r.last_read_id from public.match_reads r where r.match_id = mine.id and r.user_id = auth.uid()), 0)),
         (select count(*)::int from public.messages x where x.match_id = mine.id and x.sender = auth.uid()),
         (select count(*)::int from public.messages x where x.match_id = mine.id and x.sender = mine.other),
         exists (select 1 from public.reveal_requests rr where rr.match_id = mine.id and rr.status = 'accepted')
  from mine
  join public.profiles pr on pr.id = mine.other
  left join lateral (select body, created_at, sender from public.messages
                     where match_id = mine.id order by id desc limit 1) lm on true
  order by coalesce(lm.created_at, mine.created_at) desc
$$;

-- 첫 질문 카드 (기획서 7장). jemin이 미리 써 둔 질문 중, 두 사람의 태그 조합에 맞는 것을 고른다.
create table public.icebreakers (
  id      bigint generated always as identity primary key,
  tag_a   text references public.tags,   -- 둘 다 비면 아무 조합에나 쓰는 질문
  tag_b   text references public.tags,
  body    text not null,
  enabled boolean not null default true
);
alter table public.icebreakers enable row level security;
create policy icebreakers_admin on public.icebreakers for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create or replace function public.match_icebreaker(p_match uuid) returns text
language sql stable security definer set search_path = public as $$
  with m as (select * from public.matches where id = p_match and auth.uid() in (user_a, user_b)),
  ta as (select tag_id from public.profile_tags, m where profile_id = m.user_a),
  tb as (select tag_id from public.profile_tags, m where profile_id = m.user_b)
  select body from public.icebreakers i
  where i.enabled and exists (select 1 from m)
    and (
      (i.tag_a is null and i.tag_b is null)
      or (i.tag_a in (select tag_id from ta) and coalesce(i.tag_b in (select tag_id from tb), true))
      or (i.tag_a in (select tag_id from tb) and coalesce(i.tag_b in (select tag_id from ta), true))
    )
  -- 태그가 더 많이 맞는 질문 먼저, 같은 대화방에서는 늘 같은 질문
  order by (i.tag_a is not null)::int + (i.tag_b is not null)::int desc, md5(p_match::text || i.id::text)
  limit 1
$$;

-- 차단하면 그 사람과의 대화방을 바로 닫는다. 공개된 사진도 대화방이 닫히면 더는 열리지 않는다(8.3).
create or replace function public.handle_block() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.matches set closed_at = now(), closed_reason = 'blocked'
   where user_a = least(new.blocker, new.blocked) and user_b = greatest(new.blocker, new.blocked)
     and closed_at is null;
  return new;
end $$;
create trigger on_block after insert on public.blocks
  for each row execute function public.handle_block();

-- 대화방 나가기
create or replace function public.leave_match(p_match uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.matches set closed_at = now(), closed_reason = 'left'
   where id = p_match and auth.uid() in (user_a, user_b) and closed_at is null;
  if not found then raise exception 'not_member'; end if;
end $$;

-- 매칭 뒤 48시간 동안 아무도 말을 걸지 않으면 닫는다. pg_cron으로 1시간마다.
create or replace function public.close_idle_matches() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update public.matches m set closed_at = now(), closed_reason = 'inactive'
   where m.closed_at is null
     and m.created_at < now() - make_interval(hours => public.cfg_int('match_idle_close_hours'))
     and not exists (select 1 from public.messages x where x.match_id = m.id);
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.close_idle_matches() from public, anon, authenticated;

-- 좋아요는 오늘 카드로 받은 사람에게만 (기존 정책은 날짜를 보지 않았다)
drop policy likes_insert_self on public.likes;
create policy likes_insert_self on public.likes for insert to authenticated
  with check (from_id = auth.uid()
              and exists (select 1 from public.daily_cards
                          where viewer = auth.uid() and shown = to_id and card_date = public.kst_today()));

-- 좋아요할 때 남긴 한 줄 코멘트 (기획서 6장). 대화방이 열린 두 사람에게만 보인다.
create or replace function public.match_like_comments(p_match uuid)
returns table (from_id uuid, comment text)
language sql stable security definer set search_path = public as $$
  select l.from_id, l.comment
  from public.matches m
  join public.likes l on (l.from_id = m.user_a and l.to_id = m.user_b) or (l.from_id = m.user_b and l.to_id = m.user_a)
  where m.id = p_match and auth.uid() in (m.user_a, m.user_b) and l.comment is not null
$$;
