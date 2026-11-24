-- Spectrum — push notifications, 24 Nov 2026
-- One row per phone (APNs token). Users can only see and manage their own tokens; the
-- server reads them with the service role to send pushes.
create table if not exists public.device_tokens (
    token       text primary key,
    user_id     uuid not null references auth.users(id) on delete cascade,
    environment text not null default 'production' check (environment in ('production','development')),
    updated_at  timestamptz not null default now(),
    created_at  timestamptz not null default now()
);
create index if not exists device_tokens_user_idx on public.device_tokens(user_id);
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon;

drop policy if exists "own tokens select" on public.device_tokens;
create policy "own tokens select" on public.device_tokens for select to authenticated using (user_id = auth.uid());
drop policy if exists "own tokens insert" on public.device_tokens;
create policy "own tokens insert" on public.device_tokens for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "own tokens update" on public.device_tokens;
-- A token row can be taken over by whoever is signed in on that phone now.
create policy "own tokens update" on public.device_tokens for update to authenticated using (true) with check (user_id = auth.uid());
drop policy if exists "own tokens delete" on public.device_tokens;
create policy "own tokens delete" on public.device_tokens for delete to authenticated using (user_id = auth.uid());
