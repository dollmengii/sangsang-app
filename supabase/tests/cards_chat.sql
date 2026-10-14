-- 오늘의 카드, 매칭, 대화방 목록, 첫 질문, 차단 점검.
-- m1(남, 여성을 찾음)과 f1~f3(여, 남성을 찾음). f3은 나이 조건이 안 맞고, f2는 사진이 없다.
begin;

insert into public.invites (email) values ('m1@x.com'), ('f1@x.com'), ('f2@x.com'), ('f3@x.com');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'm1@x.com'),
  ('00000000-0000-0000-0000-0000000000b1', 'f1@x.com'),
  ('00000000-0000-0000-0000-0000000000b2', 'f2@x.com'),
  ('00000000-0000-0000-0000-0000000000b3', 'f3@x.com');

update public.profiles set nickname = 'M1', birth_year = 1996, gender = 'male', seeking = 'female',
  age_min = 24, age_max = 34, region_sido = '서울', onboarded_at = now()
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set nickname = 'F' || right(id::text, 1), birth_year = 1998, gender = 'female', seeking = 'male',
  age_min = 25, age_max = 35, region_sido = '경기', onboarded_at = now()
  where id in ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b2');
update public.profiles set nickname = 'F3', birth_year = 1990, gender = 'female', seeking = 'male',
  age_min = 34, age_max = 40, region_sido = '서울', onboarded_at = now()
  where id = '00000000-0000-0000-0000-0000000000b3';

insert into public.photos (owner, original_path, mood_path, is_primary) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1/1.jpg', 'a1/1.png', true),
  ('00000000-0000-0000-0000-0000000000b1', 'b1/1.jpg', 'b1/1.png', true),
  ('00000000-0000-0000-0000-0000000000b3', 'b3/1.jpg', 'b3/1.png', true);
insert into public.profile_tags (profile_id, slot, tag_id, source) values
  ('00000000-0000-0000-0000-0000000000a1', 'inner_energy', 'teto', 'self'),
  ('00000000-0000-0000-0000-0000000000b1', 'inner_energy', 'egen', 'self'),
  ('00000000-0000-0000-0000-0000000000b1', 'hobby', 'h_cafe', 'self');

-- 카드 만들기: m1은 f1만 받는다 (f2 사진 없음, f3 나이 조건 불일치).
do $$ begin
  assert public.generate_daily_cards() = 3, 'm1→f1, f1→m1, f2→m1 (f2 has no photo but can still view)';
  assert (select array_agg(shown) from public.daily_cards where viewer = '00000000-0000-0000-0000-0000000000a1')
         = array['00000000-0000-0000-0000-0000000000b1'::uuid], 'm1 sees f1 only';
  assert public.generate_daily_cards() = 0, 'idempotent per day';
end $$;

-- 같은 지역만 켜면 서울 m1과 경기 f1은 서로 안 나온다
update public.app_config set value = 'true' where key = 'match_same_sido';
do $$ begin
  assert (select count(*) from public._card_candidates('00000000-0000-0000-0000-0000000000a1', public.kst_today() + 1, 8)) = 0,
    'same sido filter';
end $$;
update public.app_config set value = 'false' where key = 'match_same_sido';

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
do $$
declare c record;
begin
  select * into c from public.today_cards();
  assert c.nickname = 'F1' and c.age = public.age_of(1998) and c.mood_path = 'b1/1.png', 'card fields';
  assert c.tags @> '[{"name": "에겐녀", "slot": "inner_energy"}]', 'female tag name';
  assert c.liked is null, 'not liked yet';
end $$;

-- 카드로 받지 않은 사람에게는 좋아요 못 함
do $$ begin
  insert into public.likes (from_id, to_id, liked) values
    ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b3', true);
  raise exception 'FAIL: like without card';
exception when insufficient_privilege then null;
end $$;

insert into public.likes (from_id, to_id, liked, comment) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', true, '카페 좋아하시는구나');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
insert into public.likes (from_id, to_id, liked) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', true);

-- 매칭, 첫 질문(테토×에겐 조합 질문이 일반 질문보다 먼저), 메시지, 안 읽은 수
do $$
declare mm record;
begin
  select * into mm from public.my_matches();
  assert mm.nickname = 'M1' and mm.unread = 0 and not mm.closed, 'match listed';
  assert public.match_icebreaker(mm.match_id) like '테토와 에겐이 만났네요%', 'combo icebreaker';
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
insert into public.messages (match_id, sender, body)
  select match_id, '00000000-0000-0000-0000-0000000000a1', '안녕하세요' from public.my_matches();
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
do $$ begin
  assert (select unread from public.my_matches()) = 1, 'one unread';
  assert (select last_body from public.my_matches()) = '안녕하세요', 'last message';
end $$;
insert into public.match_reads (match_id, user_id, last_read_id)
  select match_id, auth.uid(), (select max(id) from public.messages) from public.my_matches();
do $$ begin assert (select unread from public.my_matches()) = 0, 'read'; end $$;

-- 차단하면 대화방이 닫히고 메시지를 못 보낸다
insert into public.blocks (blocker, blocked) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1');
do $$ begin assert (select closed from public.my_matches()), 'closed by block'; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
do $$ begin
  insert into public.messages (match_id, sender, body)
    select match_id, auth.uid(), '왜요' from public.my_matches();
  raise exception 'FAIL: message after block';
exception when insufficient_privilege then null;
end $$;

-- 크레딧 3개로 카드 더 보기: 더 보여줄 사람이 없으면 크레딧은 그대로
do $$ begin
  perform public.buy_extra_cards();
  raise exception 'FAIL: extra cards with no candidates';
exception when others then
  if sqlerrm <> 'no_more_cards' then raise; end if;
end $$;
do $$ begin assert public.my_credit_balance() = 100, 'no charge'; end $$;

reset role;
rollback;
\echo CARDS_CHAT_TESTS_PASSED
