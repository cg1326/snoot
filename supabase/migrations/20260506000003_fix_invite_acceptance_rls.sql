-- Allow users to update dog_owners rows where their email matches the invited email
drop policy if exists "Invited user can accept their invitation" on dog_owners;

create policy "Invited user can accept their invitation"
  on public.dog_owners for update using (
    user_id = auth.uid() 
    or 
    invited_email = (select email from auth.users where id = auth.uid())
  );
