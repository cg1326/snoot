-- The "Invited user can accept their invitation" policy contained:
--   invited_email = (select email from auth.users where id = auth.uid())
-- The authenticated role cannot query auth.users directly, so this threw
-- "permission denied for table users" on every dog_owners UPDATE (role changes,
-- removals, etc.), not just acceptance. The auth.users subquery was redundant
-- anyway since the invite edge function already sets user_id at invite creation.

drop policy if exists "Invited user can accept their invitation" on public.dog_owners;

create policy "Invited user can accept their invitation"
  on public.dog_owners for update using (
    user_id = auth.uid()
  );
