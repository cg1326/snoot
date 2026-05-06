-- Grant full access to service_role for all app tables
-- (service_role bypasses RLS but still needs GRANT permissions via PostgREST)
grant all on public.dog_owners   to service_role;
grant all on public.dogs         to service_role;
grant all on public.care_profile to service_role;
grant all on public.sitter_links to service_role;
grant all on public.visit_logs   to service_role;
grant all on public.dog_media    to service_role;
grant all on public.users        to service_role;
