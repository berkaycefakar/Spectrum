-- Spectrum — avatar folder case
--
-- Builds before 1.0 (9) upload avatars to "{USER-ID-UPPERCASE}/avatar.jpg", while the policy
-- compared the folder with auth.uid()::text, which is lowercase. Every upload from those
-- builds failed with "new row violates row-level security policy". Comparing lowercased
-- keeps the owner-only rule and lets installed older builds work again.
--
-- Run in Supabase → SQL Editor. Safe to re-run.

drop policy if exists "Users manage their own avatar" on storage.objects;
create policy "Users manage their own avatar"
    on storage.objects for insert
    with check (bucket_id = 'avatars' and lower((storage.foldername(name))[1]) = auth.uid()::text);

drop policy if exists "Users update their own avatar" on storage.objects;
create policy "Users update their own avatar"
    on storage.objects for update
    using (bucket_id = 'avatars' and lower((storage.foldername(name))[1]) = auth.uid()::text);

drop policy if exists "users delete their own avatar" on storage.objects;
create policy "users delete their own avatar"
    on storage.objects for delete
    using (bucket_id = 'avatars' and lower((storage.foldername(name))[1]) = auth.uid()::text);
