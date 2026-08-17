create extension if not exists pgcrypto;

create table public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  species text not null check (species in ('dog', 'cat', 'other')),
  breed text,
  birth_date date,
  created_at timestamptz not null default now()
);

create table public.vaccinations (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  name text not null,
  date_administered date not null,
  next_due_date date,
  notes text
);

create table public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  weight_kg numeric not null,
  recorded_at date not null
);

create table public.treatments (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  type text not null check (type in ('dewormer', 'antiparasitic', 'other')),
  name text not null,
  date_given date not null,
  next_due_date date,
  notes text
);

create table public.vet_visits (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  visit_date date not null,
  reason text not null,
  notes text,
  next_visit_date date
);

alter table public.pets enable row level security;
alter table public.vaccinations enable row level security;
alter table public.weight_entries enable row level security;
alter table public.treatments enable row level security;
alter table public.vet_visits enable row level security;

create policy "pets_owner_all" on public.pets
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "vaccinations_owner_all" on public.vaccinations
  for all using (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()))
  with check (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()));

create policy "weight_entries_owner_all" on public.weight_entries
  for all using (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()))
  with check (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()));

create policy "treatments_owner_all" on public.treatments
  for all using (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()))
  with check (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()));

create policy "vet_visits_owner_all" on public.vet_visits
  for all using (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()))
  with check (exists (select 1 from public.pets where pets.id = pet_id and pets.owner_id = auth.uid()));
