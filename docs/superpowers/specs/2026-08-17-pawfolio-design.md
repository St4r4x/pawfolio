# Pawfolio — Design v1

## Purpose

Pawfolio is a mobile app that lets pet owners keep a digital health record book
for their animals: vaccinations, weight, treatments, and vet visits, with
reminders for upcoming due dates.

Target: a public product (not a personal-use-only tool) — implies per-user
accounts and data isolation from day one, but no multi-user sharing of a
single pet's record in v1.

## Scope (v1 / MVP)

In scope:
- Pet profiles (multiple pets per account)
- Vaccination tracking with due dates
- Weight tracking over time
- Treatment tracking (dewormer, antiparasitic, other) with due dates
- Vet visit history and next-visit dates
- Local reminders/notifications for upcoming due dates
- Email/password authentication
- Android only (build + test); iOS not attempted in v1 (no Mac available for
  local testing)

Out of scope (deferred):
- Offline support / local cache with sync (online-only for v1; add later if
  real usage shows a need)
- Document/photo attachments (prescriptions, X-rays, invoices)
- Sharing a pet's record between multiple user accounts (family/co-owner
  access)
- Push notifications via a server (reminders are computed and scheduled
  locally on-device instead)
- iOS build/release

## Architecture

- **Client**: Flutter (Dart), Riverpod for state management, `go_router` for
  navigation.
- **Backend**: Supabase — Postgres for data, Supabase Auth for
  authentication. No custom server component.
- **Notifications**: `flutter_local_notifications`. On each app launch and
  pull-to-refresh, the app reloads all `next_due_date` values from Supabase,
  cancels previously scheduled local notifications, and reschedules one
  notification per current due date. This avoids a separate "reminders"
  table and avoids needing server-side push (FCM/APNs) infrastructure.

Rationale: a lightweight Riverpod + repository layer (screens → providers →
Supabase-backed repository classes) was chosen over a full clean-architecture
split (domain/data/presentation + use-cases + DI) or BLoC. For a solo-built
MVP with no team behind it yet, the extra layering trades speed of delivery
for a "future-proofing" benefit that isn't needed until the product actually
has users and multiple contributors.

## Data model (Supabase / Postgres)

Row-Level Security is enabled on every table. Ownership is enforced via
`auth.uid()`: `pets.owner_id = auth.uid()` directly, and via a join through
`pets` for the four child tables (a row is visible/writable only if it
belongs to a pet owned by the requesting user).

```
pets
  id              uuid primary key
  owner_id        uuid references auth.users, not null
  name            text, not null
  species         text check (species in ('dog','cat','other')), not null
  breed           text, nullable
  birth_date      date, nullable
  created_at      timestamptz, default now()

vaccinations
  id                  uuid primary key
  pet_id              uuid references pets, not null
  name                text, not null
  date_administered   date, not null
  next_due_date       date, nullable
  notes               text, nullable

weight_entries
  id            uuid primary key
  pet_id        uuid references pets, not null
  weight_kg     numeric, not null
  recorded_at   date, not null

treatments
  id              uuid primary key
  pet_id          uuid references pets, not null
  type            text check (type in ('dewormer','antiparasitic','other')), not null
  name            text, not null
  date_given      date, not null
  next_due_date   date, nullable
  notes           text, nullable

vet_visits
  id                uuid primary key
  pet_id            uuid references pets, not null
  visit_date        date, not null
  reason            text, not null
  notes             text, nullable
  next_visit_date   date, nullable
```

No `reminders` table: due dates already live on the four child tables, and
reminders are a derived/computed view over them at read time, not a stored
entity.

## Screens & navigation (`go_router`)

- `/login`, `/signup` — email/password auth via Supabase, inline error
  messages (wrong password, email already registered, etc.)
- `/` — Home: list of the user's pets as cards, plus an "upcoming" section
  showing the next 3 due dates across all pets, sorted by date
- `/pets/:id` — Pet detail: header with the pet's info (name, species, breed,
  birth date) and four tabs — **Vaccinations / Weight / Treatments / Vet
  visits** — each a chronological list with a floating `+` button
- Adding/editing a pet, or an entry in any of the four record types, is done
  via a bottom sheet form, not a dedicated route. Forms are short (3-5
  fields), so a separate screen per form isn't warranted.

## Error handling

- Every screen models its data loading as Riverpod `AsyncValue`
  (loading/data/error) and handles all three states consistently.
- Network/Supabase failures surface as a `SnackBar` with a "retry" action.
- Form validation happens client-side before submission (required fields,
  numeric weight, valid dates); invalid fields show an inline message.
- Auth errors are shown inline on the login/signup form.

## Testing

- Unit tests on the pure logic most likely to have bugs: computing next-due
  reminders and sorting the "upcoming" list.
- One end-to-end widget test: add a pet → add a vaccination → see it appear
  in that pet's vaccination list.
- No exhaustive per-screen test coverage for v1; expand if/when the product
  grows beyond a solo-maintained MVP.

## Open questions / explicit non-decisions

None outstanding — all decisions above were confirmed during brainstorming.
Anything not listed under "Scope (v1 / MVP)" is deliberately deferred, not
forgotten.
