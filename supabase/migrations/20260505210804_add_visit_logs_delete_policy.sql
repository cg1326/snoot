-- Add delete policy for visit_logs for the dog owner
drop policy if exists "Dog owner can delete visit logs" on public.visit_logs;
create policy "Dog owner can delete visit logs"
  on public.visit_logs for delete using (
    exists (select 1 from public.dogs where id = visit_logs.dog_id and owner_id = auth.uid())
  );

-- Add delete policy for visit_logs for editors
drop policy if exists "Editors can delete visit logs" on public.visit_logs;
create policy "Editors can delete visit logs"
  on public.visit_logs for delete using (
    exists (
      select 1 from public.dog_owners
      where dog_id = visit_logs.dog_id
        and user_id = auth.uid()
        and role in ('owner','editor')
        and accepted = true
    )
  );
