-- Tighten visit_logs insert policy so arbitrary rows can't be spammed.
-- Require the sitter_link_id to reference an active, non-expired link.

drop policy if exists "Anyone can insert visit logs" on public.visit_logs;

create policy "Insert via active sitter link"
  on public.visit_logs
  for insert
  with check (
    exists (
      select 1 from public.sitter_links sl
      where sl.id = sitter_link_id
        and sl.active = true
        and (sl.expires_at is null or sl.expires_at > now())
    )
  );
