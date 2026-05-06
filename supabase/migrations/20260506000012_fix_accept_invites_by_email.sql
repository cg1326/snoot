-- Extend accept_pending_invites_for_me to match on invited_email as well.
-- Previously it only matched on user_id = auth.uid(), so any invite row
-- created when the user didn't yet exist (user_id = null) was never accepted.
-- Now it also matches on email and sets user_id at the same time.
-- Also grants EXECUTE to authenticated so the web app can call it.

create or replace function public.accept_pending_invites_for_me()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  select email into v_email from public.users where id = auth.uid();

  update public.dog_owners
  set
    -- Fill in user_id if it was null (invite created before user signed up)
    user_id  = coalesce(user_id, auth.uid()),
    accepted = true
  where accepted = false
    and (
      user_id = auth.uid()
      or (v_email is not null and invited_email = v_email)
    );
end;
$$;

grant execute on function public.accept_pending_invites_for_me() to authenticated;
