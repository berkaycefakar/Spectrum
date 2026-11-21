-- Spectrum — hardening pass, 20 Nov 2026
--
-- Everything Supabase's own security advisor flagged, plus abuse limits the code scan can't
-- see. Run AFTER Supabase_migration_field_limits.sql (or together). Applied 20 Nov 2026. Safe to re-run.
--
-- 1. GraphQL is switched off. The app only talks to PostgREST; pg_graphql just published the
--    whole schema (including content_reports, user_blocks, shares) to anyone with the anon key.
-- 2. Tables nobody signed-out should touch lose their anon grants entirely (RLS already hid
--    the rows; this removes the table from anon's reach at all).
-- 3. SECURITY DEFINER functions are no longer callable over /rest/v1/rpc by anon. Trigger
--    functions are not callable by anyone (triggers don't need EXECUTE). The two helpers used
--    inside RLS policies stay executable by signed-in users, because a policy runs as them.
-- 4. Two functions get a fixed search_path.
-- 5. Avatars: same as list covers, the bucket can no longer be listed by anyone; public URLs
--    still load.
-- 6. Rate limits per account, so one script can't flood the feed, comments, likes, follows or
--    reports. Generous for a person, tight for a bot.

-- 1 -------------------------------------------------------------------------------------------
drop extension if exists pg_graphql;

-- 2 -------------------------------------------------------------------------------------------
revoke all on public.content_reports from anon;
revoke all on public.user_blocks from anon;
revoke all on public.shares from anon;

-- 3 -------------------------------------------------------------------------------------------
revoke execute on function public.delete_comments_for_review() from public, anon, authenticated;
revoke execute on function public.delete_orphaned_review_likes() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.shares_rate_limit() from public, anon, authenticated;
revoke execute on function public.touch_list_updated_at() from public, anon, authenticated;
revoke execute on function public.unfollow_on_block() from public, anon, authenticated;
revoke execute on function public.can_share_with(uuid) from public, anon;
revoke execute on function public.not_blocked_with_owner(text, uuid) from public, anon;
grant execute on function public.can_share_with(uuid) to authenticated;
grant execute on function public.not_blocked_with_owner(text, uuid) to authenticated;

-- 4 -------------------------------------------------------------------------------------------
alter function public.review_like_counts(text, uuid[]) set search_path = public;
alter function public.list_item_counts(uuid[]) set search_path = public;

-- 5 -------------------------------------------------------------------------------------------
drop policy if exists "Avatar images are publicly accessible" on storage.objects;
drop policy if exists "Owners read their avatars" on storage.objects;
create policy "Owners read their avatars"
    on storage.objects for select
    to authenticated
    using (bucket_id = 'avatars' and lower((storage.foldername(name))[1]) = auth.uid()::text);

-- 6 -------------------------------------------------------------------------------------------
-- tg_argv: owner column, max rows, window. Counts the caller's own recent rows in the table.
create or replace function public.enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    owner_col text := tg_argv[0];
    max_rows  int := tg_argv[1]::int;
    win       interval := tg_argv[2]::interval;
    owner_val text := to_jsonb(new) ->> owner_col;
    recent    int;
begin
    execute format('select count(*) from %I.%I where %I::text = $1 and created_at > now() - $2',
                   tg_table_schema, tg_table_name, owner_col)
        into recent using owner_val, win;
    if recent >= max_rows then
        raise exception 'rate limit reached' using errcode = 'P0001';
    end if;
    return new;
end;
$$;
revoke execute on function public.enforce_rate_limit() from public, anon, authenticated;

drop trigger if exists rate_limit on public.reviews;
create trigger rate_limit before insert on public.reviews
    for each row execute function public.enforce_rate_limit('user_id', '120', '1 hour');
drop trigger if exists rate_limit on public.album_reviews;
create trigger rate_limit before insert on public.album_reviews
    for each row execute function public.enforce_rate_limit('user_id', '60', '1 hour');
drop trigger if exists rate_limit on public.artist_reviews;
create trigger rate_limit before insert on public.artist_reviews
    for each row execute function public.enforce_rate_limit('user_id', '60', '1 hour');
drop trigger if exists rate_limit on public.review_comments;
create trigger rate_limit before insert on public.review_comments
    for each row execute function public.enforce_rate_limit('user_id', '60', '1 hour');
drop trigger if exists rate_limit on public.review_likes;
create trigger rate_limit before insert on public.review_likes
    for each row execute function public.enforce_rate_limit('user_id', '300', '1 hour');
drop trigger if exists rate_limit on public.follows;
create trigger rate_limit before insert on public.follows
    for each row execute function public.enforce_rate_limit('follower_id', '100', '1 hour');
drop trigger if exists rate_limit on public.lists;
create trigger rate_limit before insert on public.lists
    for each row execute function public.enforce_rate_limit('user_id', '30', '1 hour');
drop trigger if exists rate_limit on public.list_items;
create trigger rate_limit before insert on public.list_items
    for each row execute function public.enforce_rate_limit('list_id', '300', '1 hour');
drop trigger if exists rate_limit on public.content_reports;
create trigger rate_limit before insert on public.content_reports
    for each row execute function public.enforce_rate_limit('reporter_id', '30', '1 hour');
