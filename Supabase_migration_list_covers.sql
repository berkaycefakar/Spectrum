-- Spectrum — list cover photos
--
-- A list can carry a cover the user picks from their photo library. The image lives in the
-- public `list-covers` bucket under the owner's folder ({user_id}/{list_id}.jpg); the list
-- row keeps its public URL. Same rules as avatars: anyone can read, only the owner writes
-- in their own folder, 5 MB and images only.
--
-- Run in Supabase → SQL Editor. Safe to re-run.

alter table public.lists add column if not exists cover_url text;

alter table public.lists drop constraint if exists lists_cover_url_shape;
alter table public.lists add constraint lists_cover_url_shape
    check (cover_url is null or (char_length(cover_url) <= 500 and cover_url like 'https://%'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('list-covers', 'list-covers', true, 5242880, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "List covers are publicly readable" on storage.objects;
create policy "List covers are publicly readable"
    on storage.objects for select
    using (bucket_id = 'list-covers');

drop policy if exists "Users upload list covers to their folder" on storage.objects;
create policy "Users upload list covers to their folder"
    on storage.objects for insert
    with check (bucket_id = 'list-covers' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users replace their list covers" on storage.objects;
create policy "Users replace their list covers"
    on storage.objects for update
    using (bucket_id = 'list-covers' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete their list covers" on storage.objects;
create policy "Users delete their list covers"
    on storage.objects for delete
    using (bucket_id = 'list-covers' and (storage.foldername(name))[1] = auth.uid()::text);
