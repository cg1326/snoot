-- The previous "Editors can manage dog_owners" policy caused infinite recursion
-- by querying dog_owners from within a dog_owners RLS policy.
-- Fix: use a security-definer function (same pattern as is_dog_member/is_dog_owner).

drop policy if exists "Editors can manage dog_owners" on public.dog_owners;

create or replace function public.is_dog_editor(p_dog_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.dogs
    where id = p_dog_id and owner_id = auth.uid()
  )
  or exists (
    select 1 from public.dog_owners
    where dog_id = p_dog_id
      and user_id = auth.uid()
      and role in ('owner', 'editor')
      and accepted = true
  );
$$;

create policy "Editors can manage dog_owners"
  on public.dog_owners for all using (
    public.is_dog_editor(dog_id)
  );
