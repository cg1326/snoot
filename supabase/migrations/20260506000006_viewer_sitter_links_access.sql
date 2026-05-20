-- Allow viewers (and all accepted family members) to read sitter links.
-- Previously only owners and editors had any policy on this table,
-- so viewers got zero rows back from fetchSitterLinks.

drop policy if exists "Members can view sitter links" on public.sitter_links;

create policy "Members can view sitter links"
  on public.sitter_links for select using (
    -- Primary dog owner
    exists (
      select 1 from public.dogs
      where id = sitter_links.dog_id
        and owner_id = auth.uid()
    )
    or
    -- Any accepted family member (editor or viewer)
    exists (
      select 1 from public.dog_owners
      where dog_id = sitter_links.dog_id
        and user_id = auth.uid()
        and accepted = true
    )
  );
