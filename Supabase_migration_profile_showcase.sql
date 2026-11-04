-- Spectrum — profile showcase: the favourite four and the cover banner
--
-- Two columns on `profiles` rather than a new table. Both belong to the profile itself, are
-- read every time the profile is, and the existing policies already say the right thing:
-- anyone signed in can read a profile, only its owner can update it.
--
--   favorite_album_ids — up to four Apple collection ids, in shelf order.
--   cover_album_id     — the album whose artwork fills the banner; null means the banner is
--                        drawn from the user's own vibe colours instead.
--
-- Run this in Supabase → SQL Editor. Safe to re-run: every statement is idempotent.

alter table public.profiles
    add column if not exists favorite_album_ids bigint[] not null default '{}';

alter table public.profiles
    add column if not exists cover_album_id bigint;

alter table public.profiles
    drop constraint if exists profiles_favorite_album_ids_max_four;
alter table public.profiles
    add constraint profiles_favorite_album_ids_max_four
    check (coalesce(array_length(favorite_album_ids, 1), 0) <= 4);
