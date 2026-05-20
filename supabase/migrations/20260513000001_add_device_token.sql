-- Store APNs device tokens so the sitter-view Edge Function can push
-- notifications to dog owners when a sitter logs a visit.
alter table public.users
  add column if not exists device_token text;
