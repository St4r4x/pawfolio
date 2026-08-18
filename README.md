# Pawfolio

A Flutter app for tracking your pets' health: profiles, vaccinations, weight,
treatments, and vet visits, with upcoming-reminder notifications.

## Stack

- Flutter + Riverpod + go_router
- Supabase (auth, Postgres) via `supabase_flutter`
- Local notifications (`flutter_local_notifications`) for upcoming reminders

## Getting started

Start the local Supabase stack, then run the app against it:

```bash
supabase start
./scripts/run_local.sh            # defaults to emulator-5554
```

`scripts/run_local.sh` reads the local stack's anon key from `supabase status`
and passes it to `flutter run` via `--dart-define`.

## Testing

```bash
flutter test
```

## Project layout

- `lib/screens/` — auth (login/signup), home, and pet detail screens
- `lib/repositories/` + `lib/providers/` — Supabase-backed data access via Riverpod
- `lib/models/` — pet, vaccination, weight entry, treatment, vet visit
- `lib/reminders.dart` — upcoming-reminder sorting and urgency classification
- `lib/notifications/` — local notification scheduling for reminders
- `lib/theme.dart` — brand colors and typography
- `supabase/migrations/` — database schema
