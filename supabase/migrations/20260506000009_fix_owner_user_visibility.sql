-- The existing "Dog members can view co-member profiles" policy only checks
-- dog_owners for membership, so the original dog owner (stored in dogs.owner_id,
-- never in dog_owners) can't see family members' profiles.
-- Replace it with a version that also covers the original owner.

drop policy if exists "Dog members can view co-member profiles" on public.users;

create policy "Dog members can view co-member profiles"
  on public.users for select using (
    -- Always see own profile
    id = auth.uid()
    or
    -- Original dog owner: see profiles of anyone who is a member of your dog
    exists (
      select 1 from public.dogs d
      join public.dog_owners doo on doo.dog_id = d.id
      where d.owner_id = auth.uid()
        and doo.user_id = users.id
    )
    or
    -- Member (editor/viewer): see the profile of the dog's original owner
    exists (
      select 1 from public.dogs d
      join public.dog_owners doo on doo.dog_id = d.id
      where doo.user_id = auth.uid()
        and d.owner_id = users.id
    )
    or
    -- Member: see profiles of co-members on the same dog
    exists (
      select 1 from public.dog_owners do1
      join public.dog_owners do2 on do1.dog_id = do2.dog_id
      where do1.user_id = auth.uid()
        and do2.user_id = users.id
    )
  );
