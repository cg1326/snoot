-- Add gender and personality_tags columns to dogs table if they don't already exist.
-- These fields were in the iOS upsert payload but missing from the initial schema,
-- causing them to be silently dropped by PostgREST on every push.

alter table public.dogs
  add column if not exists gender text not null default '',
  add column if not exists personality_tags text[] not null default '{}';
