-- Remove any dog_owners rows where user_id matches the dog's owner_id.
-- The primary dog owner is identified by dogs.owner_id and should never
-- appear in dog_owners — doing so suppresses the synthetic owner row in
-- the Family Access UI and inflates the family member count.
delete from public.dog_owners
where user_id = (
  select owner_id from public.dogs where dogs.id = dog_owners.dog_id
);
