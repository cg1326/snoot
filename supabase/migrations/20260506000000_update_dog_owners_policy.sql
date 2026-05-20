-- Update dog_owners policy to allow any member to see all other members of the same dog
drop policy if exists "Members can read their own dog_owners row" on dog_owners;

drop policy if exists "Dog members can view all family members" on public.dog_owners;
create policy "Dog members can view all family members"
  on public.dog_owners for select using (
    exists (
      select 1 from public.dog_owners as members
      where members.dog_id = dog_owners.dog_id
        and members.user_id = auth.uid()
    )
    or
    exists (
      select 1 from public.dogs
      where dogs.id = dog_owners.dog_id
        and dogs.owner_id = auth.uid()
    )
  );
