-- Add unique constraint on dog_owners so we can upsert by (dog_id, invited_email)
alter table public.dog_owners
  add constraint dog_owners_dog_id_invited_email_key
  unique (dog_id, invited_email);
