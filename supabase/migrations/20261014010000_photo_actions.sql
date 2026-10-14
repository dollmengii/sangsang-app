-- 사진 관리: 대표 사진 바꾸기, 사진 지우기. 사진 줄 넣기는 process-photo 서버 함수만 한다.

create or replace function public.set_primary_photo(p_photo uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.photos where id = p_photo and owner = auth.uid()) then
    raise exception 'not_owner';
  end if;
  update public.photos set is_primary = false where owner = auth.uid() and is_primary;
  update public.photos set is_primary = true where id = p_photo;
end $$;

-- 사진 줄을 지우고 파일 경로를 돌려준다. 앱이 그 경로로 보관함 파일을 지운다.
-- 대표 사진을 지우면 남은 사진 중 가장 오래된 것이 대표가 된다.
create or replace function public.delete_my_photo(p_photo uuid)
returns table (original_path text, mood_path text)
language plpgsql security definer set search_path = public as $$
declare
  was_primary boolean;
begin
  delete from public.photos p
   where p.id = p_photo and p.owner = auth.uid()
  returning p.is_primary, p.original_path, p.mood_path
    into was_primary, original_path, mood_path;
  if not found then raise exception 'not_owner'; end if;
  if was_primary then
    update public.photos set is_primary = true
     where id = (select id from public.photos where owner = auth.uid() order by created_at limit 1);
  end if;
  return next;
end $$;

create policy originals_delete_self on storage.objects for delete to authenticated
  using (bucket_id = 'originals' and (storage.foldername(name))[1] = auth.uid()::text);
create policy moods_delete_self on storage.objects for delete to authenticated
  using (bucket_id = 'moods' and (storage.foldername(name))[1] = auth.uid()::text);

-- 내 원본은 나만 볼 수 있다 (내 사진 화면). 다른 사람의 원본은 공개 수락 뒤 서버가 60초 주소로만 연다.
create policy originals_read_self on storage.objects for select to authenticated
  using (bucket_id = 'originals' and (storage.foldername(name))[1] = auth.uid()::text);
