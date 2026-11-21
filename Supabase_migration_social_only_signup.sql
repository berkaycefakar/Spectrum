-- Spectrum — new accounts only through Sign in with Apple or Google, 21 Nov 2026
--
-- Email + password stays as a way to LOG IN (the App Review demo account uses it), but nobody
-- can create a new account with it. That removes the password surface for everyone new: no
-- leaked or reused passwords, no reset-link phishing, no throwaway-email bot sign-ups.
--
-- Enforced in Auth itself through the "before user created" hook, so calling the API directly
-- with the anon key can't get around it. The app also stops showing a sign-up form.
--
-- After running this, enable the hook: Auth → Hooks → Before User Created →
-- pg-functions://postgres/public/block_email_signups (done through the Management API). Applied 21 Nov 2026.

create or replace function public.block_email_signups(event jsonb)
returns jsonb
language plpgsql
stable
as $$
begin
    if coalesce(event #>> '{user,app_metadata,provider}', '') in ('email', 'phone') then
        return jsonb_build_object('error', jsonb_build_object(
            'http_code', 403,
            'message', 'Sign up with Apple or Google.'));
    end if;
    return '{}'::jsonb;
end;
$$;

revoke execute on function public.block_email_signups(jsonb) from public, anon, authenticated;
grant execute on function public.block_email_signups(jsonb) to supabase_auth_admin;
