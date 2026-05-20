-- Allow dog members to see the profiles of co-members and dog owners.
-- Without this, viewers can't see the owner's name/email in Family Access,
-- and other members' display names fall back to their invited email.

drop policy if exists "Dog members can view co-member profiles" on public.users;

create policy "Dog members can view co-member profiles"
  on public.users for select using (
    -- Always see own profile (existing policy already covers this, belt-and-suspenders)
    id = auth.uid()
    or
    -- See the owner of any dog you're a member of
    exists (
      select 1 from public.dogs d
      join public.dog_owners doo on doo.dog_id = d.id
      where doo.user_id = auth.uid()
        and d.owner_id = users.id
    )
    or
    -- See co-members of dogs you own or are a member of
    exists (
      select 1 from public.dog_owners do1
      join public.dog_owners do2 on do1.dog_id = do2.dog_id
      where do1.user_id = auth.uid()
        and do2.user_id = users.id
    )
  );
