-- Spectrum — fixes from the 20 Nov 2026 security scan (CLAUDE-SECURITY-20261120-095126)
--
-- 1. List covers could be listed by anyone. The public `list-covers` bucket had a SELECT
--    policy for every role, and Storage's list endpoint runs under it, so the anon key in the
--    app could enumerate every user's cover, private lists included. A public bucket serves a
--    known URL without any SELECT policy; the policy is only needed by the owner (upsert reads
--    the existing object). So: owner-only.
-- 2. Blocking didn't stop comments or likes. The INSERT policies only checked the author, so
--    a blocked user kept posting under the blocker's logs while the blocker's client hid it.
--    Inserts now fail across a block in either direction.
-- 3. avatar_url took any URL, so a user could point it at their own server and log the IP of
--    everyone who saw their comments. It must now be this project's avatars bucket, under the
--    user's own id (both the old flat "{ID}.jpg" and the "{id}/avatar.jpg" layouts match).
--
-- Run in Supabase → SQL Editor. Safe to re-run.

-- 1 -------------------------------------------------------------------------------------------

drop policy if exists "List covers are publicly readable" on storage.objects;
drop policy if exists "Owners read their list covers" on storage.objects;
create policy "Owners read their list covers"
    on storage.objects for select
    to authenticated
    using (bucket_id = 'list-covers' and (storage.foldername(name))[1] = auth.uid()::text);

-- Cover files of deleted lists are removed by the app (SupabaseManager.deleteList) and by the
-- delete-user function, through the Storage API. A trigger can't do it: Supabase blocks
-- direct deletes from storage.objects ("Direct deletion from storage tables is not
-- allowed"), and a trigger trying it made the whole list delete fail.
drop trigger if exists lists_delete_cover on public.lists;
drop function if exists public.delete_list_cover();

-- 2 -------------------------------------------------------------------------------------------

-- True when neither the caller nor the owner of the target has blocked the other. The owner
-- is looked up per content type; SECURITY DEFINER because a blocked user can't read the
-- blocker's rows (on purpose: being told you're blocked is how blocks turn into harassment).
create or replace function public.not_blocked_with_owner(p_content_type text, p_content_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    owner_id uuid;
begin
    owner_id := case p_content_type
        when 'song_review'   then (select user_id from reviews where id = p_content_id)
        when 'album_review'  then (select user_id from album_reviews where id = p_content_id)
        when 'artist_review' then (select user_id from artist_reviews where id = p_content_id)
        when 'comment'       then (select user_id from review_comments where id = p_content_id)
        else null
    end;
    if owner_id is null then
        return true;
    end if;
    return not exists (
        select 1 from user_blocks
        where (blocker_id = owner_id and blocked_id = auth.uid())
           or (blocker_id = auth.uid() and blocked_id = owner_id)
    );
end;
$$;

revoke all on function public.not_blocked_with_owner(text, uuid) from public;
grant execute on function public.not_blocked_with_owner(text, uuid) to authenticated;

drop policy if exists "users comment as themselves" on public.review_comments;
create policy "users comment as themselves"
    on public.review_comments for insert
    with check (auth.uid() = user_id and public.not_blocked_with_owner(content_type, content_id));

drop policy if exists "users like as themselves" on public.review_likes;
create policy "users like as themselves"
    on public.review_likes for insert
    with check (auth.uid() = user_id and public.not_blocked_with_owner(content_type, content_id));

-- 3 -------------------------------------------------------------------------------------------

alter table public.profiles drop constraint if exists profiles_avatar_url_own_bucket;
alter table public.profiles add constraint profiles_avatar_url_own_bucket
    check (
        avatar_url is null
        or lower(avatar_url) like lower('https://ysgbqlltzdhgsezukxxm.supabase.co/storage/v1/object/public/avatars/' || id::text) || '%'
    );
