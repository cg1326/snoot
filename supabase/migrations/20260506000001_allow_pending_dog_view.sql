-- Update dogs policy to allow pending family members to view the dog
drop policy if exists "Shared members can read dogs" on dogs;

create policy "Shared members can read dogs"
  on public.dogs for select using (
    exists (
      select 1 from public.dog_owners
      where dog_id = dogs.id
        and user_id = auth.uid()
    )
  );
