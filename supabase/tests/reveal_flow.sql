-- 공개 흐름 점검: 초대 막기, 가입 크레딧, 매칭, 공개 보류·차감·반환, RLS.
-- 실패하면 예외로 멈춘다. 실행: psql -v ON_ERROR_STOP=1 -f tests/reveal_flow.sql
begin;

-- 초대 안 된 계정은 가입이 막힌다
do $$ begin
  insert into auth.users (email) values ('stranger@gmail.com');
  raise exception 'FAIL: uninvited signup allowed';
exception when sqlstate 'P0001' then
  if sqlerrm <> 'not_invited' then raise; end if;
end $$;

insert into public.invites (email) values ('a@gmail.com'), ('b@gmail.com');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@gmail.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@gmail.com');
do $$ begin
  assert public.credit_balance('00000000-0000-0000-0000-00000000000a') = 100, 'signup grant';
end $$;

insert into public.photos (id, owner, original_path, status) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', 'a/1.jpg', 'approved'),
  ('10000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', 'b/1.jpg', 'approved');
insert into public.daily_cards values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', current_date, false),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a', current_date, false);

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
insert into public.likes (from_id, to_id, liked) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', true);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
insert into public.likes (from_id, to_id, liked) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a', true);

-- 서로 좋아요 → 대화방
do $$ begin assert (select count(*) from public.matches) = 1, 'match created'; end $$;

-- 남의 장부는 안 보인다
do $$ begin
  assert (select count(*) from public.credit_ledger
          where user_id = '00000000-0000-0000-0000-00000000000a') = 0, 'ledger RLS';
end $$;

-- 메시지가 부족하면 공개 요청 불가
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
do $$ begin
  perform public.request_reveal((select id from public.matches), array['10000000-0000-0000-0000-00000000000a'::uuid]);
  raise exception 'FAIL: reveal allowed without messages';
exception when others then
  if sqlerrm <> 'not_enough_messages' then raise; end if;
end $$;

insert into public.messages (match_id, sender, body)
  select (select id from public.matches), '00000000-0000-0000-0000-00000000000a', 'hi ' || g from generate_series(1, 10) g;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
insert into public.messages (match_id, sender, body)
  select (select id from public.matches), '00000000-0000-0000-0000-00000000000b', 'yo ' || g from generate_series(1, 10) g;

-- A가 요청 → 10 보류 (잔액 90)
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select public.request_reveal((select id from public.matches), array['10000000-0000-0000-0000-00000000000a'::uuid]) as req \gset
do $$ begin assert public.my_credit_balance() = 90, 'held'; end $$;

-- B가 "조금 더" → 반환 (잔액 100)
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select public.respond_reveal(:'req', 'later');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
do $$ begin assert public.my_credit_balance() = 100, 'released'; end $$;

-- 24시간 안에 다시 요청 불가
do $$ begin
  perform public.request_reveal((select id from public.matches), array['10000000-0000-0000-0000-00000000000a'::uuid]);
  raise exception 'FAIL: retry allowed too soon';
exception when others then
  if sqlerrm <> 'retry_too_soon' then raise; end if;
end $$;

-- B가 직접 요청하고 A가 수락 → B만 10 차감, A는 그대로
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select public.request_reveal((select id from public.matches), array['10000000-0000-0000-0000-00000000000b'::uuid]) as req2 \gset
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select public.respond_reveal(:'req2', 'accept', array['10000000-0000-0000-0000-00000000000a'::uuid], 'thirty_seconds');
do $$ begin assert public.my_credit_balance() = 100, 'responder pays nothing'; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$ begin assert public.my_credit_balance() = 90, 'requester charged'; end $$;

-- 클라이언트가 장부에 직접 쓸 수 없다
do $$ begin
  insert into public.credit_ledger (user_id, delta, kind)
    values ('00000000-0000-0000-0000-00000000000b', 1000, 'grant');
  raise exception 'FAIL: client wrote ledger';
exception when insufficient_privilege then null;
end $$;

-- 내 상태(status)를 스스로 바꿀 수 없다
update public.profiles set status = 'active', nickname = '비' where id = '00000000-0000-0000-0000-00000000000b';
do $$ begin
  update public.profiles set status = 'banned' where id = auth.uid();
  raise exception 'FAIL: self status change';
exception when insufficient_privilege then null;
end $$;

reset role;
-- 만료: 48시간 동안 답이 없던 요청은 보류가 풀린다
update public.reveal_requests set status = 'cancelled' where id = :'req2';
insert into public.reveal_requests (id, match_id, requester, responder, requester_photo_ids, cost, expires_at)
  select '20000000-0000-0000-0000-000000000001', id, user_a, user_b,
         array['10000000-0000-0000-0000-00000000000a'::uuid], 10, now() - interval '1 minute'
  from public.matches;
insert into public.credit_ledger (user_id, delta, kind, ref_id)
  values ('00000000-0000-0000-0000-00000000000a', -10, 'hold', '20000000-0000-0000-0000-000000000001');
do $$ begin
  assert public.expire_reveal_requests() = 1, 'expired one';
  assert public.credit_balance('00000000-0000-0000-0000-00000000000a') = 100, 'expire releases hold';
end $$;

rollback;
\echo ALL_TESTS_PASSED
