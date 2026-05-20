-- Fix orphaned dog_owners rows when a user deletes their account.
--
-- Problem 1: dog_owners.user_id FK was ON DELETE SET NULL, so deleting a user
-- left membership rows behind with user_id = NULL (effectively orphaned).
-- Fix: change to ON DELETE CASCADE so accepted invitations are removed automatically.
--
-- Problem 2: No RLS DELETE policy existed for users to remove their own
-- dog_owners rows, so the client-side deletes in deleteAccount() silently failed.
-- Fix: add a policy that lets users delete rows where they are the member
-- OR where their email is the pending invited_email (uses auth.email() to
-- avoid recursion into public.users).

-- 1. Swap the FK to CASCADE (drop old constraint, re-add with new behaviour).
alter table public.dog_owners
  drop constraint if exists dog_owners_user_id_fkey;

alter table public.dog_owners
  add constraint dog_owners_user_id_fkey
    foreign key (user_id) references public.users(id) on delete cascade;

-- 2. Allow users to delete their own membership / pending-invitation rows.
drop policy if exists "Users can delete their own dog_owners rows" on public.dog_owners;

create policy "Users can delete their own dog_owners rows"
  on public.dog_owners
  for delete
  using (
    user_id = auth.uid()
    or invited_email = auth.email()
  );
