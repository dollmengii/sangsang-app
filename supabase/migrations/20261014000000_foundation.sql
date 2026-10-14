-- 상상 소개팅: 친구용 첫 버전 기본 스키마
-- 기획서 13장(기술 구조), 8장(얼굴 공개), 9장(크레딧), 10장(신고) 기준.
-- 원칙: 크레딧, 공개, 제재는 클라이언트가 직접 쓰지 못하고 아래 security definer 함수로만 바뀐다.

create extension if not exists pgcrypto;

-- ───────────────────────── 설정 값 (기획서 9.1, 친구용 크레딧) ─────────────────────────
create table public.app_config (
  key   text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.app_config (key, value) values
  ('reveal_cost',            '10'),
  ('extra_cards_cost',       '3'),
  ('signup_grant',           '100'),
  ('reveal_min_messages',    '10'),
  ('reveal_expire_hours',    '48'),
  ('reveal_retry_hours',     '24'),
  ('reveal_max_per_match',   '2'),
  ('daily_card_count',       '8'),
  ('reanalysis_limit_30d',   '3');

create or replace function public.cfg_int(k text) returns int
language sql stable security definer set search_path = public as $$
  select (value #>> '{}')::int from public.app_config where key = k
$$;

-- ───────────────────────── 초대 목록과 관리자 ─────────────────────────
-- 친구용 버전은 jemin이 넣은 구글 계정만 가입한다 (기획서 "누구에게, 어떻게 나눠 주나").
create table public.invites (
  email      text primary key check (email = lower(email)),
  note       text,
  created_at timestamptz not null default now()
);

create table public.admins (
  user_id uuid primary key references auth.users on delete cascade
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;

-- ───────────────────────── 프로필 (기획서 5장) ─────────────────────────
-- 친구용 버전은 나이와 성별을 본인이 입력한다. 키, 몸무게, 종교, 정치, 건강은 받지 않는다.
create table public.profiles (
  id             uuid primary key references auth.users on delete cascade,
  nickname       text check (char_length(nickname) between 1 and 12),
  birth_year     int  check (birth_year between 1900 and extract(year from now())::int - 19),
  gender         text check (gender in ('male', 'female')),
  seeking        text check (seeking in ('male', 'female')),
  region_sido    text,
  region_sigungu text,
  age_min        int  check (age_min >= 19),
  age_max        int  check (age_max >= age_min),
  bio            text check (char_length(bio) <= 40),
  smoking        text check (smoking in ('no', 'sometimes', 'yes')),
  drinking       text check (drinking in ('no', 'sometimes', 'yes')),
  job_field      text,
  qa             jsonb not null default '[]'::jsonb,  -- 질문 답변 1~2개 [{q, a}]
  gemini_consent_at timestamptz,                      -- Gemini 무료 등급 안내 동의 시각
  onboarded_at   timestamptz,
  status         text not null default 'active'
                 check (status in ('active', 'reveal_suspended', 'banned')),
  last_active_at timestamptz not null default now(),
  created_at     timestamptz not null default now()
);

-- ───────────────────────── 태그 표 (기획서 4.10) ─────────────────────────
create table public.tags (
  id                 text primary key,
  category           text not null check (category in
                       ('animal', 'energy', 'mood', 'character', 'hobby', 'date_style', 'pace')),
  name_male          text not null,
  name_female        text not null,
  description        text not null default '',
  enabled            boolean not null default true,
  suggest_to         text not null default 'all' check (suggest_to in ('all', 'male', 'female')),
  sort_order         int not null default 0,
  version            int not null default 1,
  cleared_for_public boolean not null default true  -- 공개 출시 때 써도 되는지 (권리 확인됨)
);

-- 꺼진 태그를 비슷한 태그로 옮겨 주는 연결 표
create table public.tag_migrations (
  from_tag text primary key references public.tags,
  to_tag   text not null references public.tags
);

create table public.profile_tags (
  profile_id uuid not null references public.profiles on delete cascade,
  slot       text not null check (slot in
               ('animal', 'outer_energy', 'inner_energy', 'mood', 'character', 'hobby', 'date_style', 'pace')),
  tag_id     text not null references public.tags,
  source     text not null check (source in ('ai', 'self')),  -- "AI 추천" / "직접 고름"
  hidden     boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (profile_id, slot, tag_id)
);

-- AI 분석 기록. 점수는 저장하지 않고 상위 후보만 남긴다 (기획서 4.9).
create table public.tag_analyses (
  id                   uuid primary key default gen_random_uuid(),
  profile_id           uuid not null references public.profiles on delete cascade,
  photo_ids            uuid[] not null,
  animal_candidates    text[] not null default '{}',
  outer_energy         text,
  mood_candidates      text[] not null default '{}',
  character_candidates text[] not null default '{}',
  outcome              text not null check (outcome in ('ok', 'refused', 'error', 'rejected_photo')),
  latency_ms           int,
  created_at           timestamptz not null default now()
);

-- ───────────────────────── 사진 (기획서 13.5) ─────────────────────────
create table public.photos (
  id           uuid primary key default gen_random_uuid(),
  owner        uuid not null references public.profiles on delete cascade,
  original_path text not null,       -- originals 버킷 (비공개)
  mood_path    text,                 -- moods 버킷 (16~24px 무드 이미지)
  is_face      boolean not null default true,
  is_primary   boolean not null default false,
  status       text not null default 'pending'
               check (status in ('pending', 'approved', 'rejected', 'review')),
  created_at   timestamptz not null default now()
);
create unique index photos_one_primary on public.photos (owner) where is_primary;

-- ───────────────────────── 카드, 좋아요, 매칭 (기획서 6장) ─────────────────────────
create table public.daily_cards (
  viewer    uuid not null references public.profiles on delete cascade,
  shown     uuid not null references public.profiles on delete cascade,
  card_date date not null,
  extra     boolean not null default false,  -- 크레딧으로 더 본 카드
  primary key (viewer, shown, card_date)
);

create table public.likes (
  from_id    uuid not null references public.profiles on delete cascade,
  to_id      uuid not null references public.profiles on delete cascade,
  liked      boolean not null,               -- false = 넘기기
  comment    text check (char_length(comment) <= 60),
  created_at timestamptz not null default now(),
  primary key (from_id, to_id),
  check (from_id <> to_id)
);

create table public.matches (
  id         uuid primary key default gen_random_uuid(),
  user_a     uuid not null references public.profiles on delete cascade,
  user_b     uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  closed_at  timestamptz,
  closed_reason text check (closed_reason in ('left', 'blocked', 'inactive', 'admin')),
  check (user_a < user_b),
  unique (user_a, user_b)
);

create or replace function public.is_match_member(m uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.matches
                 where id = m and auth.uid() in (user_a, user_b))
$$;

create table public.messages (
  id         bigint generated always as identity primary key,
  match_id   uuid not null references public.matches on delete cascade,
  sender     uuid not null references public.profiles on delete cascade,
  body       text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index messages_match_idx on public.messages (match_id, id);

create table public.blocks (
  blocker    uuid not null references public.profiles on delete cascade,
  blocked    uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked)
);

-- ───────────────────────── 크레딧 장부 (기획서 9.5, 친구용 크레딧) ─────────────────────────
-- 한 줄씩 쌓기만 하고 고치지 않는다. 잔액 = delta 합계.
-- grant: 무료 지급, purchase: 구매, hold: 공개 요청 보류(-), release: 보류 해제(+),
-- spend: 실제 차감(-), refund: 반환(+, 사진과 달라요 등)
create table public.credit_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles on delete cascade,
  delta      int not null check (delta <> 0),
  kind       text not null check (kind in ('grant', 'purchase', 'hold', 'release', 'spend', 'refund')),
  ref_id     uuid,          -- reveal_requests.id 등
  note       text,
  created_at timestamptz not null default now()
);
create index credit_ledger_user_idx on public.credit_ledger (user_id);

create or replace function public.credit_balance(u uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(delta), 0)::int from public.credit_ledger where user_id = u
$$;

create or replace function public.my_credit_balance() returns int
language sql stable security definer set search_path = public as $$
  select public.credit_balance(auth.uid())
$$;

-- ───────────────────────── 얼굴 공개 (기획서 8장) ─────────────────────────
create table public.reveal_requests (
  id                  uuid primary key default gen_random_uuid(),
  match_id            uuid not null references public.matches on delete cascade,
  requester           uuid not null references public.profiles on delete cascade,
  responder           uuid not null references public.profiles on delete cascade,
  requester_photo_ids uuid[] not null,
  responder_photo_ids uuid[],
  view_mode           text check (view_mode in ('keep', 'thirty_seconds')),
  cost                int not null,
  status              text not null default 'pending'
                      check (status in ('pending', 'accepted', 'later', 'declined', 'expired', 'cancelled')),
  created_at          timestamptz not null default now(),
  responded_at        timestamptz,
  expires_at          timestamptz not null
);
create unique index reveal_one_pending on public.reveal_requests (match_id) where status = 'pending';

-- ───────────────────────── 신고 (기획서 10.2~10.4) ─────────────────────────
create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter    uuid not null references public.profiles on delete cascade,
  target      uuid not null references public.profiles on delete cascade,
  match_id    uuid references public.matches on delete set null,
  reveal_id   uuid references public.reveal_requests on delete set null,
  kind        text not null check (kind in
                ('not_as_pictured', 'sexual', 'pressure_reveal', 'money', 'married', 'minor', 'other')),
  detail      text check (char_length(detail) <= 500),
  status      text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  check (reporter <> target)
);

-- 운영자가 원본 사진이나 신고된 대화를 본 기록, 공개 사진 열람 기록
create table public.access_logs (
  id         bigint generated always as identity primary key,
  actor      uuid not null,
  action     text not null,   -- 'admin_view_photo', 'admin_view_chat', 'reveal_view'
  target_id  uuid,
  created_at timestamptz not null default now()
);

-- ───────────────────────── 가입 처리 ─────────────────────────
-- 초대 목록에 없는 구글 계정은 가입 자체를 막는다. 가입하면 빈 프로필과 무료 크레딧을 만든다.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.invites where email = lower(new.email)) then
    raise exception 'not_invited' using errcode = 'P0001';
  end if;
  insert into public.profiles (id) values (new.id);
  insert into public.credit_ledger (user_id, delta, kind, note)
    values (new.id, public.cfg_int('signup_grant'), 'grant', '가입 축하');
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────── 매칭: 서로 좋아요 ─────────────────────────
create or replace function public.handle_like() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.liked and exists (
    select 1 from public.likes where from_id = new.to_id and to_id = new.from_id and liked
  ) then
    insert into public.matches (user_a, user_b)
      values (least(new.from_id, new.to_id), greatest(new.from_id, new.to_id))
      on conflict do nothing;
  end if;
  return new;
end $$;

create trigger on_like after insert on public.likes
  for each row execute function public.handle_like();

-- ───────────────────────── 공개 요청 함수 ─────────────────────────
create or replace function public.request_reveal(p_match uuid, p_photo_ids uuid[])
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  m  public.matches;
  other uuid;
  v_cost int := public.cfg_int('reveal_cost');
  min_msgs int := public.cfg_int('reveal_min_messages');
  req_id uuid;
begin
  select * into m from public.matches where id = p_match for update;
  if m is null or me not in (m.user_a, m.user_b) then raise exception 'not_member'; end if;
  if m.closed_at is not null then raise exception 'match_closed'; end if;
  other := case when me = m.user_a then m.user_b else m.user_a end;

  if (select status from public.profiles where id = me) <> 'active' then
    raise exception 'reveal_suspended';
  end if;

  -- 8.1 조건: 두 사람 모두 검사 통과한 얼굴 사진, 각자 메시지 N번 이상, 처리 중인 신고 없음
  if not exists (select 1 from public.photos where owner = me and status = 'approved' and is_face)
     or not exists (select 1 from public.photos where owner = other and status = 'approved' and is_face) then
    raise exception 'no_approved_photo';
  end if;
  if (select count(*) from public.messages where match_id = p_match and sender = me) < min_msgs
     or (select count(*) from public.messages where match_id = p_match and sender = other) < min_msgs then
    raise exception 'not_enough_messages';
  end if;
  if exists (select 1 from public.reports where status = 'open'
             and ((reporter = me and target = other) or (reporter = other and target = me))) then
    raise exception 'open_report';
  end if;

  -- 보낼 사진은 내 승인된 얼굴 사진 1~3장
  if coalesce(array_length(p_photo_ids, 1), 0) not between 1 and 3
     or exists (select 1 from unnest(p_photo_ids) pid
                where not exists (select 1 from public.photos
                                  where id = pid and owner = me and status = 'approved')) then
    raise exception 'invalid_photos';
  end if;

  -- 이미 공개됐거나 대기 중이면 안 됨
  if exists (select 1 from public.reveal_requests
             where match_id = p_match and status in ('pending', 'accepted')) then
    raise exception 'already_pending_or_revealed';
  end if;

  -- 한 대화방에서 내 요청은 최대 N번, 직전 요청 뒤 24시간
  if (select count(*) from public.reveal_requests where match_id = p_match and requester = me)
       >= public.cfg_int('reveal_max_per_match') then
    raise exception 'request_limit';
  end if;
  if exists (select 1 from public.reveal_requests where match_id = p_match and requester = me
             and created_at > now() - make_interval(hours => public.cfg_int('reveal_retry_hours'))) then
    raise exception 'retry_too_soon';
  end if;

  if v_cost > 0 and public.credit_balance(me) < v_cost then
    raise exception 'insufficient_credits';
  end if;

  insert into public.reveal_requests
    (match_id, requester, responder, requester_photo_ids, cost, expires_at)
  values
    (p_match, me, other, p_photo_ids, v_cost,
     now() + make_interval(hours => public.cfg_int('reveal_expire_hours')))
  returning id into req_id;

  if v_cost > 0 then
    insert into public.credit_ledger (user_id, delta, kind, ref_id, note)
      values (me, -v_cost, 'hold', req_id, '얼굴 공개 요청 보류');
  end if;
  return req_id;
end $$;

-- 보류된 크레딧을 돌려주거나(release) 실제로 차감(release + spend)한다.
create or replace function public._settle_reveal_hold(r public.reveal_requests, charge boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if r.cost <= 0 then return; end if;
  insert into public.credit_ledger (user_id, delta, kind, ref_id, note)
    values (r.requester, r.cost, 'release', r.id, '보류 해제');
  if charge then
    insert into public.credit_ledger (user_id, delta, kind, ref_id, note)
      values (r.requester, -r.cost, 'spend', r.id, '얼굴 공개');
  end if;
end $$;
revoke all on function public._settle_reveal_hold(public.reveal_requests, boolean) from public, anon, authenticated;

create or replace function public.respond_reveal(
  p_request uuid, p_choice text, p_photo_ids uuid[] default null, p_view_mode text default 'keep')
returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  r public.reveal_requests;
begin
  select * into r from public.reveal_requests where id = p_request for update;
  if r is null or r.responder <> me then raise exception 'not_responder'; end if;
  if r.status <> 'pending' then raise exception 'not_pending'; end if;
  if r.expires_at < now() then raise exception 'expired'; end if;

  if p_choice = 'accept' then
    if coalesce(array_length(p_photo_ids, 1), 0) not between 1 and 3
       or exists (select 1 from unnest(p_photo_ids) pid
                  where not exists (select 1 from public.photos
                                    where id = pid and owner = me and status = 'approved')) then
      raise exception 'invalid_photos';
    end if;
    if p_view_mode not in ('keep', 'thirty_seconds') then raise exception 'invalid_view_mode'; end if;

    -- 두 사람의 공개 상태를 한 번에 바꾸고, 그때 요청자의 크레딧이 실제로 빠진다.
    update public.reveal_requests
       set status = 'accepted', responder_photo_ids = p_photo_ids,
           view_mode = p_view_mode, responded_at = now()
     where id = r.id;
    perform public._settle_reveal_hold(r, true);
  elsif p_choice in ('later', 'declined') then
    update public.reveal_requests set status = p_choice, responded_at = now() where id = r.id;
    perform public._settle_reveal_hold(r, false);
  else
    raise exception 'invalid_choice';
  end if;
end $$;

-- 48시간 동안 답이 없으면 만료하고 크레딧을 돌려준다. pg_cron으로 10분마다 돌린다.
create or replace function public.expire_reveal_requests() returns int
language plpgsql security definer set search_path = public as $$
declare
  r public.reveal_requests;
  n int := 0;
begin
  for r in select * from public.reveal_requests
           where status = 'pending' and expires_at < now() for update skip locked loop
    update public.reveal_requests set status = 'expired' where id = r.id;
    perform public._settle_reveal_hold(r, false);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.expire_reveal_requests() from public, anon, authenticated;

-- ───────────────────────── 관리자 함수 ─────────────────────────
create or replace function public.admin_grant_credits(p_user uuid, p_amount int, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if p_amount <= 0 then raise exception 'invalid_amount'; end if;
  insert into public.credit_ledger (user_id, delta, kind, note)
    values (p_user, p_amount, 'grant', coalesce(p_note, '관리자 지급'));
end $$;

-- ───────────────────────── 행 단위 보안 (RLS) ─────────────────────────
alter table public.app_config      enable row level security;
alter table public.invites         enable row level security;
alter table public.admins          enable row level security;
alter table public.profiles        enable row level security;
alter table public.tags            enable row level security;
alter table public.tag_migrations  enable row level security;
alter table public.profile_tags    enable row level security;
alter table public.tag_analyses    enable row level security;
alter table public.photos          enable row level security;
alter table public.daily_cards     enable row level security;
alter table public.likes           enable row level security;
alter table public.matches         enable row level security;
alter table public.messages        enable row level security;
alter table public.blocks          enable row level security;
alter table public.credit_ledger   enable row level security;
alter table public.reveal_requests enable row level security;
alter table public.reports         enable row level security;
alter table public.access_logs     enable row level security;

-- 설정과 태그는 로그인한 사람이 읽고, 관리자만 바꾼다.
create policy cfg_read   on public.app_config for select to authenticated using (true);
create policy cfg_admin  on public.app_config for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy tags_read  on public.tags       for select to authenticated using (enabled or public.is_admin());
create policy tags_admin on public.tags       for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy tagmig_admin on public.tag_migrations for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy invites_admin on public.invites for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admins_self  on public.admins  for select to authenticated using (user_id = auth.uid());

-- 프로필: 내 것은 읽고 고치고, 다른 사람 것은 정지되지 않은 경우만 읽는다. 상태(status)는 관리자만.
create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or status <> 'banned' or public.is_admin());
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and status = (select p.status from public.profiles p where p.id = auth.uid()));
create policy profiles_admin on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 태그: 숨기지 않은 태그는 모두 읽고, 내 태그만 쓴다. AI 태그는 서버 함수(service role)가 넣는다.
create policy ptags_read on public.profile_tags for select to authenticated
  using (profile_id = auth.uid() or not hidden);
create policy ptags_write_self on public.profile_tags for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid() and source = 'self');
-- AI 후보 중 하나를 고르는 일은 다음 단계의 서버 함수가 맡는다 (후보 밖 선택 방지).
create policy analyses_read_self on public.tag_analyses for select to authenticated
  using (profile_id = auth.uid() or public.is_admin());

-- 사진 행: 내 것과 관리자만. 다른 사람은 무드 이미지 경로만 따로 받는다 (카드 함수에서).
create policy photos_self on public.photos for select to authenticated
  using (owner = auth.uid() or public.is_admin());

-- 카드: 내가 받은 카드만 읽는다. 카드는 서버가 만든다.
create policy cards_read_self on public.daily_cards for select to authenticated using (viewer = auth.uid());

-- 좋아요: 내가 누른 것만 쓰고 읽는다. "나를 좋아요한 사람 목록"은 만들지 않는다 (6장).
create policy likes_insert_self on public.likes for insert to authenticated
  with check (from_id = auth.uid()
              and exists (select 1 from public.daily_cards
                          where viewer = auth.uid() and shown = to_id));
create policy likes_read_self on public.likes for select to authenticated using (from_id = auth.uid());

-- 매칭과 메시지: 대화방 두 사람만.
create policy matches_read on public.matches for select to authenticated
  using (auth.uid() in (user_a, user_b) or public.is_admin());
create policy messages_read on public.messages for select to authenticated
  using (public.is_match_member(match_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (sender = auth.uid()
              and exists (select 1 from public.matches m
                          where m.id = match_id and auth.uid() in (m.user_a, m.user_b)
                            and m.closed_at is null));

create policy blocks_self on public.blocks for all to authenticated
  using (blocker = auth.uid()) with check (blocker = auth.uid());

-- 크레딧 장부: 내 줄만 읽는다. 쓰기는 함수만.
create policy ledger_read_self on public.credit_ledger for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- 공개 요청: 두 사람만 읽는다. 쓰기는 request_reveal / respond_reveal 함수만.
create policy reveals_read on public.reveal_requests for select to authenticated
  using (auth.uid() in (requester, responder) or public.is_admin());

-- 신고: 내가 한 신고만 쓰고 읽는다. 관리자는 모두.
create policy reports_insert_self on public.reports for insert to authenticated
  with check (reporter = auth.uid() and status = 'open');
create policy reports_read on public.reports for select to authenticated
  using (reporter = auth.uid() or public.is_admin());
create policy reports_admin on public.reports for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy access_logs_admin on public.access_logs for select to authenticated using (public.is_admin());

-- 채팅 실시간 구독
alter publication supabase_realtime add table public.messages, public.reveal_requests, public.matches;

-- ───────────────────────── 파일 보관함 (기획서 13.2, 13.5) ─────────────────────────
-- originals: 원본 (비공개, 본인 업로드만, 읽기는 서버만)
-- moods: 16~24px 무드 이미지 (로그인한 사람 읽기, 쓰기는 서버만)
-- 공개 사진은 서버 함수가 originals에서 60초짜리 주소를 발급한다.
insert into storage.buckets (id, name, public) values
  ('originals', 'originals', false),
  ('moods', 'moods', false)
on conflict (id) do nothing;

create policy originals_upload_self on storage.objects for insert to authenticated
  with check (bucket_id = 'originals' and (storage.foldername(name))[1] = auth.uid()::text);
create policy moods_read on storage.objects for select to authenticated
  using (bucket_id = 'moods');
