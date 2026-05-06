-- ============================================================
-- Snoot – Initial Supabase Schema
-- ============================================================

-- ─── users ───────────────────────────────────────────────────
create table public.users (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text not null,
  display_name text not null default '',
  created_at   timestamptz not null default now()
);

-- ─── dogs ────────────────────────────────────────────────────
create table public.dogs (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.users(id) on delete cascade,
  name       text not null,
  breed      text not null default '',
  dob        date,
  weight_lbs numeric(5,1),
  photo_url  text,
  bio        text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ─── dog_owners ──────────────────────────────────────────────
create table public.dog_owners (
  id            uuid primary key default gen_random_uuid(),
  dog_id        uuid not null references public.dogs(id) on delete cascade,
  user_id       uuid references public.users(id) on delete set null,
  role          text not null default 'viewer' check (role in ('owner','editor','viewer')),
  invited_email text,
  accepted      boolean not null default false,
  created_at    timestamptz not null default now()
);

-- ─── care_profile ────────────────────────────────────────────
create table public.care_profile (
  id         uuid primary key default gen_random_uuid(),
  dog_id     uuid not null references public.dogs(id) on delete cascade,
  section    text not null check (section in ('feeding','walks','behaviour','health','bedtime')),
  data       jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id),
  unique (dog_id, section)
);

-- ─── sitter_links ────────────────────────────────────────────
create table public.sitter_links (
  id         uuid primary key default gen_random_uuid(),
  dog_id     uuid not null references public.dogs(id) on delete cascade,
  token      text not null unique default replace(gen_random_uuid()::text, '-', ''),
  mode       text not null default 'daytime' check (mode in ('daytime','overnight','both')),
  created_by uuid not null references public.users(id),
  expires_at timestamptz,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- ─── visit_logs ──────────────────────────────────────────────
create table public.visit_logs (
  id                 uuid primary key default gen_random_uuid(),
  dog_id             uuid not null references public.dogs(id) on delete cascade,
  sitter_link_id     uuid references public.sitter_links(id) on delete set null,
  logged_by_name     text not null,
  visited_at         timestamptz not null default now(),
  fed                boolean not null default false,
  walked             boolean not null default false,
  walk_duration_mins int,
  notes              text not null default '',
  created_at         timestamptz not null default now()
);

-- ─── dog_media ───────────────────────────────────────────────
create table public.dog_media (
  id          uuid primary key default gen_random_uuid(),
  dog_id      uuid not null references public.dogs(id) on delete cascade,
  url         text not null,
  type        text not null default 'photo' check (type in ('photo','video')),
  uploaded_by uuid references public.users(id),
  created_at  timestamptz not null default now()
);

-- ============================================================
-- Enable Row Level Security on all tables
-- ============================================================
alter table public.users        enable row level security;
alter table public.dogs         enable row level security;
alter table public.dog_owners   enable row level security;
alter table public.care_profile enable row level security;
alter table public.sitter_links enable row level security;
alter table public.visit_logs   enable row level security;
alter table public.dog_media    enable row level security;

-- ============================================================
-- Policies — users
-- ============================================================
create policy "Users can view their own profile"
  on public.users for select using (auth.uid() = id);

create policy "Users can update their own profile"
  on public.users for update using (auth.uid() = id);

-- ============================================================
-- Policies — dogs
-- ============================================================
create policy "Owner can do anything with their dogs"
  on public.dogs for all using (auth.uid() = owner_id);

create policy "Shared members can read dogs"
  on public.dogs for select using (
    exists (
      select 1 from public.dog_owners
      where dog_id = dogs.id
        and user_id = auth.uid()
        and accepted = true
    )
  );

create policy "Editors can update dogs"
  on public.dogs for update using (
    exists (
      select 1 from public.dog_owners
      where dog_id = dogs.id
        and user_id = auth.uid()
        and role in ('owner','editor')
        and accepted = true
    )
  );

-- ============================================================
-- Policies — dog_owners
-- ============================================================
-- Security-definer function breaks the dogs ↔ dog_owners RLS recursion
create or replace function public.is_dog_owner(p_dog_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.dogs
    where id = p_dog_id and owner_id = auth.uid()
  );
$$;

create policy "Dog owner can manage dog_owners"
  on public.dog_owners for all using (
    public.is_dog_owner(dog_id)
  );

create policy "Members can read their own dog_owners row"
  on public.dog_owners for select using (user_id = auth.uid());

create policy "Invited user can accept their invitation"
  on public.dog_owners for update using (user_id = auth.uid());

-- ============================================================
-- Policies — care_profile
-- ============================================================
create policy "Owner can manage care profiles"
  on public.care_profile for all using (
    exists (select 1 from public.dogs where id = care_profile.dog_id and owner_id = auth.uid())
  );

create policy "Shared members can read care profiles"
  on public.care_profile for select using (
    exists (
      select 1 from public.dog_owners
      where dog_id = care_profile.dog_id
        and user_id = auth.uid()
        and accepted = true
    )
  );

create policy "Editors can update care profiles"
  on public.care_profile for update using (
    exists (
      select 1 from public.dog_owners
      where dog_id = care_profile.dog_id
        and user_id = auth.uid()
        and role in ('owner','editor')
        and accepted = true
    )
  );

-- ============================================================
-- Policies — sitter_links
-- ============================================================
create policy "Owner can manage sitter links"
  on public.sitter_links for all using (
    exists (select 1 from public.dogs where id = sitter_links.dog_id and owner_id = auth.uid())
  );

create policy "Editors can manage sitter links"
  on public.sitter_links for all using (
    exists (
      select 1 from public.dog_owners
      where dog_id = sitter_links.dog_id
        and user_id = auth.uid()
        and role in ('owner','editor')
        and accepted = true
    )
  );

-- ============================================================
-- Policies — visit_logs
-- ============================================================
create policy "Dog owner can read visit logs"
  on public.visit_logs for select using (
    exists (select 1 from public.dogs where id = visit_logs.dog_id and owner_id = auth.uid())
  );

create policy "Shared members can read visit logs"
  on public.visit_logs for select using (
    exists (
      select 1 from public.dog_owners
      where dog_id = visit_logs.dog_id
        and user_id = auth.uid()
        and accepted = true
    )
  );

create policy "Anyone can log a visit"
  on public.visit_logs for insert with check (true);

-- ============================================================
-- Policies — dog_media
-- ============================================================
create policy "Owner can manage dog media"
  on public.dog_media for all using (
    exists (select 1 from public.dogs where id = dog_media.dog_id and owner_id = auth.uid())
  );

create policy "Shared members can read dog media"
  on public.dog_media for select using (
    exists (
      select 1 from public.dog_owners
      where dog_id = dog_media.dog_id
        and user_id = auth.uid()
        and accepted = true
    )
  );

-- ============================================================
-- Role grants (required for RLS policies to take effect)
-- ============================================================
grant select, insert, update on public.users          to authenticated;
grant select, insert, update, delete on public.dogs         to authenticated;
grant select, insert, update, delete on public.dog_owners   to authenticated;
grant select, insert, update, delete on public.care_profile to authenticated;
grant select, insert, update, delete on public.sitter_links to authenticated;
grant select, insert, update, delete on public.visit_logs   to authenticated;
grant select, insert, update, delete on public.dog_media    to authenticated;

grant select on public.sitter_links to anon;
grant select on public.dogs         to anon;
grant select on public.care_profile to anon;
grant insert on public.visit_logs   to anon;

-- Insert policy so the app can upsert a missing users row
create policy "Users can insert own profile"
  on public.users for insert
  with check (auth.uid() = id);

-- ============================================================
-- Storage bucket for dog photos
-- ============================================================
insert into storage.buckets (id, name, public)
values ('dog-photos', 'dog-photos', true)
on conflict do nothing;

create policy "Authenticated users can upload dog photos"
  on storage.objects for insert
  with check (bucket_id = 'dog-photos' and auth.role() = 'authenticated');

create policy "Anyone can read dog photos"
  on storage.objects for select
  using (bucket_id = 'dog-photos');

create policy "Owner can delete their dog photos"
  on storage.objects for delete
  using (bucket_id = 'dog-photos' and auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================
-- Auto-create public.users row on signup
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Realtime
-- ============================================================
alter publication supabase_realtime add table public.visit_logs;
alter publication supabase_realtime add table public.care_profile;
