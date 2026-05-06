-- Security-definer RPC so an authenticated user can accept their own pending invites
-- without being blocked by RLS on the dog_owners table.
create or replace function public.accept_pending_invites_for_me()
returns void
language sql
security definer
set search_path = public
as $$
  update public.dog_owners
  set accepted = true
  where user_id = auth.uid()
    and accepted = false;
$$;
