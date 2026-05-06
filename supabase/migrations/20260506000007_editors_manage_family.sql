-- Allow editors to manage family access (invite, remove, change roles).
-- Previously only the original dog owner could manage dog_owners.
-- Editors are trusted family members who should share this responsibility.

create policy "Editors can manage dog_owners"
  on public.dog_owners for all using (
    exists (
      select 1 from public.dog_owners as membership
      where membership.dog_id = dog_owners.dog_id
        and membership.user_id = auth.uid()
        and membership.role in ('owner', 'editor')
        and membership.accepted = true
    )
  );
