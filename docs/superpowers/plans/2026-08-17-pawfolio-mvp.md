# Pawfolio MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working Android Flutter app where a user can sign up, add pets, and track vaccinations, weight, treatments, and vet visits, with local reminders for upcoming due dates.

**Architecture:** Flutter client (Riverpod + go_router) talking directly to a Supabase backend (Postgres + Auth) with row-level security; no offline cache, no server-side push — reminders are computed from Supabase data and scheduled as local notifications on-device.

**Tech Stack:** Flutter/Dart, flutter_riverpod, go_router, supabase_flutter, flutter_local_notifications, timezone. Backend: Supabase CLI local stack (Postgres + GoTrue) via Docker for development.

## Global Constraints

- Android only for v1 — do not add iOS build config or attempt to test on iOS (spec: Scope).
- Online-only — no local database, no offline cache/sync layer (spec: Scope, Architecture).
- No document/photo attachments and no multi-user sharing of a pet's record in v1 (spec: Scope).
- Reminders are local notifications recomputed from Supabase data on each app launch/refresh — no server-side push infrastructure (spec: Architecture).
- State management is Riverpod with a lightweight repository layer (screens → providers → Supabase-backed repositories) — no full clean-architecture layering, no BLoC (spec: Architecture).
- Forms for adding/editing a pet or a record are bottom sheets, not dedicated routes (spec: Screens & navigation).
- Every Supabase table has row-level security enabled, scoped to `auth.uid()` (spec: Data model).
- Package name / repo name: `pawfolio`.

---

## Task 1: Flutter SDK, Android toolchain, and project scaffold

**Files:**
- Create: entire Flutter project scaffold under `/home/missia03/Projects/pawfolio` (`pubspec.yaml`, `lib/main.dart`, `android/`, `test/widget_test.dart`, `.gitignore`)

**Interfaces:**
- Produces: a working `flutter` command on PATH, a working Android toolchain, and a buildable Flutter project at the repo root that later tasks add code to.

- [ ] **Step 1: Install the Flutter SDK (no sudo — clone to the user's home directory)**

```bash
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc
export PATH="$PATH:$HOME/development/flutter/bin"
flutter --version
```

Expected: prints a Flutter/Dart version (this also downloads the Dart SDK and engine artifacts on first run — can take a few minutes).

- [ ] **Step 2: Run `flutter doctor` and confirm Android toolchain is the only failing check**

```bash
flutter doctor -v
```

Expected: `[✓] Flutter`, and `[✗] Android toolchain` (missing SDK — expected at this point).

- [ ] **Step 3: Install the Android command-line tools (no sudo — install under `~/Android/Sdk`)**

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
curl -fSL -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q cmdline-tools.zip
mv cmdline-tools latest
rm cmdline-tools.zip
```

If that URL 404s (Google rotates build numbers), grab the current "Command line tools only" Linux link from https://developer.android.com/studio#command-line-tools-only and substitute it.

- [ ] **Step 4: Set Android env vars and add SDK tools to PATH**

```bash
cat >> ~/.bashrc << 'EOF'
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
EOF
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
```

- [ ] **Step 5: Install SDK packages and accept licenses**

```bash
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator" "system-images;android-34;google_apis;x86_64"
```

- [ ] **Step 6: Create an Android Virtual Device (used for final verification in Task 11)**

```bash
avdmanager create avd -n pawfolio -k "system-images;android-34;google_apis;x86_64" --force
```

- [ ] **Step 7: Point Flutter at the SDK and re-run doctor**

```bash
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor -v
```

Expected: `[✓] Android toolchain - develop for Android devices`. An "Android Studio not installed" note is fine to ignore — it's not required to build or run.

- [ ] **Step 8: Scaffold the Flutter project in place (the repo already has `.git` and `docs/`)**

```bash
cd /home/missia03/Projects/pawfolio
flutter create --platforms=android --org com.pawfolio --project-name pawfolio .
```

- [ ] **Step 9: Verify the toolchain actually builds an APK**

```bash
cd /home/missia03/Projects/pawfolio
flutter pub get
flutter build apk --debug
```

Expected: ends with `Built build/app/outputs/flutter-apk/app-debug.apk`.

If this fails with a Gradle/Java error (the machine's default JDK is a very new version that the Android Gradle Plugin may not yet support), install a known-good JDK without sudo and point Flutter at it, then retry this step:

```bash
curl -fSL -o /tmp/jdk17.tar.gz "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"
mkdir -p ~/jdks && tar xzf /tmp/jdk17.tar.gz -C ~/jdks
flutter config --jdk-dir "$(echo ~/jdks/jdk-17*)"
flutter build apk --debug
```

- [ ] **Step 10: Add `.gitignore` and commit the scaffold**

```bash
cd /home/missia03/Projects/pawfolio
cat > .gitignore << 'EOF'
.dart_tool/
.flutter-plugin-dependencies
build/
.gradle/
*.iml
.idea/
local.properties
android/local.properties
android/.gradle/
android/app/debug
android/app/profile
android/app/release
supabase/.branches/
supabase/.temp/
.env.local
.superpowers/
EOF
git add -A
git commit -m "chore: scaffold Flutter Android project"
```

---

## Task 2: Supabase local stack and database schema

**Files:**
- Create: `supabase/config.toml`, `supabase/migrations/20260817000000_init_schema.sql`

**Interfaces:**
- Produces: a running local Supabase stack (Postgres on `127.0.0.1:54322`, API on `127.0.0.1:54321`) with tables `pets`, `vaccinations`, `weight_entries`, `treatments`, `vet_visits`, all RLS-enabled and owner-scoped.

- [ ] **Step 1: Initialize the Supabase project**

```bash
cd /home/missia03/Projects/pawfolio
supabase init
```

- [ ] **Step 2: Disable email confirmation for local dev (so sign-up logs the user in immediately, no fake-inbox step)**

Open `supabase/config.toml`, find the `[auth.email]` section, and set:

```toml
enable_confirmations = false
```

- [ ] **Step 3: Write the schema migration**

Create `supabase/migrations/20260817000000_init_schema.sql`:

```sql
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
```

- [ ] **Step 4: Start the local stack and apply the migration**

```bash
supabase start
```

Expected: prints `API URL`, `anon key`, etc. Keep this output — Task 3 needs the anon key.

- [ ] **Step 5: Verify the schema**

```bash
PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -c "\dt public.*"
PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -c "select relname, relrowsecurity from pg_class where relname in ('pets','vaccinations','weight_entries','treatments','vet_visits');"
```

Expected: first command lists all 5 tables; second command shows `relrowsecurity = t` for all 5.

- [ ] **Step 6: Commit**

```bash
cd /home/missia03/Projects/pawfolio
git add supabase
git commit -m "feat: add Supabase schema for pets and health records"
```

---

## Task 3: App wiring — Supabase client, Riverpod, go_router skeleton

**Files:**
- Create: `lib/supabase_config.dart`, `lib/app_router.dart`, `lib/screens/home/home_screen.dart`, `scripts/run_local.sh`, `test/app_smoke_test.dart`
- Modify: `lib/main.dart`, `pubspec.yaml`
- Delete: `test/widget_test.dart` (default counter-app test, no longer applicable)

**Interfaces:**
- Produces: `PawfolioApp` widget (in `lib/main.dart`) usable directly in widget tests without touching Supabase; `appRouterProvider` (in `lib/app_router.dart`) of type `Provider<GoRouter>`.

- [ ] **Step 1: Add dependencies**

```bash
cd /home/missia03/Projects/pawfolio
flutter pub add flutter_riverpod go_router supabase_flutter
```

- [ ] **Step 2: Create `lib/supabase_config.dart`**

```dart
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
```

- [ ] **Step 3: Create `lib/screens/home/home_screen.dart` (placeholder, replaced for real in Task 5)**

```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Pawfolio')),
    );
  }
}
```

- [ ] **Step 4: Create `lib/app_router.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/home/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ],
  );
});
```

- [ ] **Step 5: Rewrite `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_router.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(SupabaseConfig.url.isNotEmpty, 'SUPABASE_URL must be passed via --dart-define');
  assert(SupabaseConfig.anonKey.isNotEmpty, 'SUPABASE_ANON_KEY must be passed via --dart-define');
  await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  runApp(const ProviderScope(child: PawfolioApp()));
}

class PawfolioApp extends ConsumerWidget {
  const PawfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Pawfolio',
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 6: Delete the default test and write a smoke test**

```bash
rm -f test/widget_test.dart
```

Create `test/app_smoke_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/main.dart';

void main() {
  testWidgets('app boots and shows the home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PawfolioApp()));
    await tester.pumpAndSettle();
    expect(find.text('Pawfolio'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run the test**

```bash
flutter test test/app_smoke_test.dart
```

Expected: PASS. (This test never calls `main()`/`Supabase.initialize`, so it doesn't need a live Supabase instance.)

- [ ] **Step 8: Add a helper script to run against the local Supabase stack**

Create `scripts/run_local.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
eval "$(supabase status -o env | sed -E 's/^([A-Z_]+)=/export \1=/')"
flutter run -d "${1:-emulator-5554}" \
  --dart-define=SUPABASE_URL="http://10.0.2.2:54321" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
```

```bash
chmod +x scripts/run_local.sh
```

Note: `10.0.2.2` is the Android emulator's alias for the host machine's `localhost` — it only works from the emulator, not from `curl` on the host.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: wire Supabase client, Riverpod, and go_router skeleton"
```

---

## Task 4: Authentication

**Files:**
- Create: `lib/auth_redirect.dart`, `lib/screens/auth/login_screen.dart`, `lib/screens/auth/signup_screen.dart`, `test/auth_redirect_test.dart`
- Modify: `lib/app_router.dart`, `test/app_smoke_test.dart`

**Interfaces:**
- Consumes: `appRouterProvider` from Task 3.
- Produces: `authRedirect({required bool loggedIn, required String location})` returning `String?`, used by the router.

**Addendum (discovered during implementation):** Step 7's router reads `Supabase.instance.client.auth.currentSession` at build time, which requires `Supabase.initialize()` to have run — Task 3's `test/app_smoke_test.dart` pumps `PawfolioApp` directly without ever calling it, so it now crashes on an uninitialized-client assertion. Fixing this is in scope for this task (see Step 8 below) since this task is what introduces the dependency; the fix updates the smoke test, not the router.

- [ ] **Step 1: Write the failing test for the redirect logic**

Create `test/auth_redirect_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/auth_redirect.dart';

void main() {
  test('redirects to login when logged out and not already on an auth screen', () {
    expect(authRedirect(loggedIn: false, location: '/'), '/login');
  });

  test('redirects to home when logged in and on the login screen', () {
    expect(authRedirect(loggedIn: true, location: '/login'), '/');
  });

  test('no redirect when logged in and on a normal screen', () {
    expect(authRedirect(loggedIn: true, location: '/pets/123'), isNull);
  });

  test('no redirect when logged out and already on the signup screen', () {
    expect(authRedirect(loggedIn: false, location: '/signup'), isNull);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/auth_redirect_test.dart
```

Expected: FAIL — `lib/auth_redirect.dart` doesn't exist yet.

- [ ] **Step 3: Implement `lib/auth_redirect.dart`**

```dart
String? authRedirect({required bool loggedIn, required String location}) {
  final loggingIn = location == '/login' || location == '/signup';
  if (!loggedIn && !loggingIn) return '/login';
  if (loggedIn && loggingIn) return '/';
  return null;
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/auth_redirect_test.dart
```

Expected: PASS.

- [ ] **Step 5: Create `lib/screens/auth/login_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Se connecter'),
            ),
            TextButton(
              onPressed: () => context.push('/signup'),
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create `lib/screens/auth/signup_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("S'inscrire"),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Wire auth + redirect into `lib/app_router.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_redirect.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    redirect: (context, state) => authRedirect(
      loggedIn: Supabase.instance.client.auth.currentSession != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 8: Fix `test/app_smoke_test.dart` for the now-auth-gated router**

The router now redirects an unauthenticated user away from `/` to `/login`, so the smoke test's original "shows Pawfolio" assertion is stale — with no session, booting the app correctly lands on `LoginScreen`, not `HomeScreen`. Update the test to assert the new, correct behavior instead of working around it:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('app boots with no session and shows the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PawfolioApp()));
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);
  });
}
```

`Supabase.initialize` with a fake local URL/key does not require network access for this test: it only sets up the client and local session storage, and the redirect this test exercises reads `currentSession` synchronously (no session was ever persisted, so it's `null`) — no real HTTP call happens before the assertion runs.

- [ ] **Step 9: Run the full test suite and commit**

```bash
flutter test
git add -A
git commit -m "feat: add email/password auth with router redirect guard"
```

---

## Task 5: Pet model, repository, Home screen, and pet detail shell

**Files:**
- Create: `lib/date_only.dart`, `lib/models/pet.dart`, `lib/repositories/pets_repository.dart`, `lib/providers/pets_provider.dart`, `lib/screens/pet_detail/pet_detail_screen.dart`, `lib/screens/pet_detail/widgets/vaccinations_tab.dart`, `lib/screens/pet_detail/widgets/weight_tab.dart`, `lib/screens/pet_detail/widgets/treatments_tab.dart`, `lib/screens/pet_detail/widgets/vet_visits_tab.dart`, `test/models/pet_test.dart`, `test/screens/home_screen_test.dart`
- Modify: `lib/screens/home/home_screen.dart` (replace placeholder), `lib/app_router.dart` (add `/pets/:id` route)

**Interfaces:**
- Produces: `Pet` model, `PetsRepository` (abstract) + `SupabasePetsRepository` (impl), `petsRepositoryProvider` (`Provider<PetsRepository>`), `petsProvider` (`FutureProvider<List<Pet>>`). `PetDetailScreen(petId: String)` widget. `dateOnly(DateTime) -> String` helper used by every later model/screen that displays or serializes a date.

- [ ] **Step 1: Write the failing model test**

Create `test/models/pet_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';

void main() {
  test('Pet.fromJson parses a full record', () {
    final pet = Pet.fromJson({
      'id': 'p1',
      'owner_id': 'u1',
      'name': 'Rex',
      'species': 'dog',
      'breed': 'Labrador',
      'birth_date': '2020-05-01',
    });
    expect(pet.name, 'Rex');
    expect(pet.species, 'dog');
    expect(pet.breed, 'Labrador');
    expect(pet.birthDate, DateTime(2020, 5, 1));
  });

  test('Pet.fromJson handles null optional fields', () {
    final pet = Pet.fromJson({
      'id': 'p1',
      'owner_id': 'u1',
      'name': 'Mia',
      'species': 'cat',
      'breed': null,
      'birth_date': null,
    });
    expect(pet.breed, isNull);
    expect(pet.birthDate, isNull);
  });

  test('toInsertJson omits null optional fields', () {
    const pet = Pet(id: '', ownerId: '', name: 'Mia', species: 'cat');
    final json = pet.toInsertJson(ownerId: 'u1');
    expect(json.containsKey('breed'), isFalse);
    expect(json.containsKey('birth_date'), isFalse);
    expect(json['name'], 'Mia');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/models/pet_test.dart
```

Expected: FAIL — `lib/models/pet.dart` doesn't exist.

- [ ] **Step 3: Create `lib/date_only.dart`**

```dart
String dateOnly(DateTime date) => date.toIso8601String().split('T').first;
```

- [ ] **Step 4: Create `lib/models/pet.dart`**

```dart
import '../date_only.dart';

class Pet {
  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
  });

  final String id;
  final String ownerId;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        species: json['species'] as String,
        breed: json['breed'] as String?,
        birthDate: json['birth_date'] == null ? null : DateTime.parse(json['birth_date'] as String),
      );

  Map<String, dynamic> toInsertJson({required String ownerId}) => {
        'owner_id': ownerId,
        'name': name,
        'species': species,
        if (breed != null) 'breed': breed,
        if (birthDate != null) 'birth_date': dateOnly(birthDate!),
      };
}
```

- [ ] **Step 5: Run the model test again**

```bash
flutter test test/models/pet_test.dart
```

Expected: PASS.

- [ ] **Step 6: Create `lib/repositories/pets_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';

abstract class PetsRepository {
  Future<List<Pet>> fetchAll();
  Future<Pet> create(Pet pet);
}

class SupabasePetsRepository implements PetsRepository {
  SupabasePetsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Pet>> fetchAll() async {
    final rows = await _client.from('pets').select().order('created_at');
    return rows.map((row) => Pet.fromJson(row)).toList();
  }

  @override
  Future<Pet> create(Pet pet) async {
    final ownerId = _client.auth.currentUser!.id;
    final row = await _client.from('pets').insert(pet.toInsertJson(ownerId: ownerId)).select().single();
    return Pet.fromJson(row);
  }
}
```

- [ ] **Step 7: Create `lib/providers/pets_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';
import '../repositories/pets_repository.dart';

final petsRepositoryProvider =
    Provider<PetsRepository>((ref) => SupabasePetsRepository(Supabase.instance.client));

final petsProvider = FutureProvider<List<Pet>>((ref) {
  return ref.watch(petsRepositoryProvider).fetchAll();
});
```

- [ ] **Step 8: Write the failing widget test for the Home screen**

Create `test/screens/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/screens/home/home_screen.dart';

void main() {
  testWidgets('shows pets returned by petsProvider', (tester) async {
    final pets = [
      const Pet(id: '1', ownerId: 'u1', name: 'Rex', species: 'dog'),
      const Pet(id: '2', ownerId: 'u1', name: 'Mia', species: 'cat'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => pets)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mia'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no pets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => <Pet>[])],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun animal pour le moment'), findsOneWidget);
  });
}
```

- [ ] **Step 9: Run it to confirm it fails**

```bash
flutter test test/screens/home_screen_test.dart
```

Expected: FAIL — `HomeScreen` is still the Task 3 placeholder.

- [ ] **Step 10: Replace `lib/screens/home/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pet.dart';
import '../../providers/pets_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pawfolio'),
        actions: [
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(petsProvider.future),
        child: petsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erreur: $error'),
                TextButton(onPressed: () => ref.invalidate(petsProvider), child: const Text('Réessayer')),
              ],
            ),
          ),
          data: (pets) => pets.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun animal pour le moment')),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return ListTile(
                      title: Text(pet.name),
                      subtitle: Text(pet.species),
                      onTap: () => context.push('/pets/${pet.id}'),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPetSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String species = 'dog';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
              DropdownButton<String>(
                value: species,
                items: const [
                  DropdownMenuItem(value: 'dog', child: Text('Chien')),
                  DropdownMenuItem(value: 'cat', child: Text('Chat')),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (value) => setState(() => species = value!),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    await ref.read(petsRepositoryProvider).create(
                          Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                        );
                    ref.invalidate(petsProvider);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 11: Run the Home screen test again**

```bash
flutter test test/screens/home_screen_test.dart
```

Expected: PASS.

- [ ] **Step 12: Create placeholder tab widgets (filled in for real in Tasks 6-9)**

Create `lib/screens/pet_detail/widgets/vaccinations_tab.dart`:

```dart
import 'package:flutter/material.dart';

class VaccinationsTab extends StatelessWidget {
  const VaccinationsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('Vaccins'));
}
```

Create `lib/screens/pet_detail/widgets/weight_tab.dart`:

```dart
import 'package:flutter/material.dart';

class WeightTab extends StatelessWidget {
  const WeightTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('Poids'));
}
```

Create `lib/screens/pet_detail/widgets/treatments_tab.dart`:

```dart
import 'package:flutter/material.dart';

class TreatmentsTab extends StatelessWidget {
  const TreatmentsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('Traitements'));
}
```

Create `lib/screens/pet_detail/widgets/vet_visits_tab.dart`:

```dart
import 'package:flutter/material.dart';

class VetVisitsTab extends StatelessWidget {
  const VetVisitsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) => const Center(child: Text('RDV'));
}
```

- [ ] **Step 13: Create `lib/screens/pet_detail/pet_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';

import 'widgets/treatments_tab.dart';
import 'widgets/vaccinations_tab.dart';
import 'widgets/vet_visits_tab.dart';
import 'widgets/weight_tab.dart';

class PetDetailScreen extends StatelessWidget {
  const PetDetailScreen({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Animal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vaccins'),
              Tab(text: 'Poids'),
              Tab(text: 'Traitements'),
              Tab(text: 'RDV'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            VaccinationsTab(petId: petId),
            WeightTab(petId: petId),
            TreatmentsTab(petId: petId),
            VetVisitsTab(petId: petId),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 14: Add the `/pets/:id` route to `lib/app_router.dart`**

Add the import:

```dart
import 'screens/pet_detail/pet_detail_screen.dart';
```

Add this route inside the `routes:` list, alongside `/`:

```dart
GoRoute(
  path: '/pets/:id',
  builder: (context, state) => PetDetailScreen(petId: state.pathParameters['id']!),
),
```

- [ ] **Step 15: Run the full suite and commit**

```bash
flutter test
git add -A
git commit -m "feat: add pet profiles, home screen, and pet detail shell"
```

---

## Task 6: Vaccinations

**Files:**
- Create: `lib/models/vaccination.dart`, `lib/repositories/vaccinations_repository.dart`, `lib/providers/vaccinations_provider.dart`, `test/models/vaccination_test.dart`, `test/screens/vaccinations_tab_test.dart`
- Modify: `lib/screens/pet_detail/widgets/vaccinations_tab.dart` (replace placeholder)

**Interfaces:**
- Consumes: `dateOnly` from `lib/date_only.dart` (Task 5).
- Produces: `Vaccination` model, `VaccinationsRepository` (abstract) + `SupabaseVaccinationsRepository` (impl), `vaccinationsRepositoryProvider` (`Provider<VaccinationsRepository>`), `vaccinationsProvider` (`FutureProvider.family<List<Vaccination>, String>`, keyed by `petId`).

- [ ] **Step 1: Write the failing model test**

Create `test/models/vaccination_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vaccination.dart';

void main() {
  test('Vaccination.fromJson parses a full record', () {
    final vaccination = Vaccination.fromJson({
      'id': 'v1',
      'pet_id': 'p1',
      'name': 'Rage',
      'date_administered': '2024-01-15',
      'next_due_date': '2025-01-15',
      'notes': 'Bien toléré',
    });
    expect(vaccination.name, 'Rage');
    expect(vaccination.dateAdministered, DateTime(2024, 1, 15));
    expect(vaccination.nextDueDate, DateTime(2025, 1, 15));
    expect(vaccination.notes, 'Bien toléré');
  });

  test('toInsertJson omits null optional fields', () {
    final vaccination = Vaccination(
      id: '',
      petId: 'p1',
      name: 'Rage',
      dateAdministered: DateTime(2024, 1, 15),
    );
    final json = vaccination.toInsertJson();
    expect(json.containsKey('next_due_date'), isFalse);
    expect(json.containsKey('notes'), isFalse);
    expect(json['date_administered'], '2024-01-15');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/models/vaccination_test.dart
```

Expected: FAIL — `lib/models/vaccination.dart` doesn't exist.

- [ ] **Step 3: Create `lib/models/vaccination.dart`**

```dart
import '../date_only.dart';

class Vaccination {
  const Vaccination({
    required this.id,
    required this.petId,
    required this.name,
    required this.dateAdministered,
    this.nextDueDate,
    this.notes,
  });

  final String id;
  final String petId;
  final String name;
  final DateTime dateAdministered;
  final DateTime? nextDueDate;
  final String? notes;

  factory Vaccination.fromJson(Map<String, dynamic> json) => Vaccination(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        name: json['name'] as String,
        dateAdministered: DateTime.parse(json['date_administered'] as String),
        nextDueDate: json['next_due_date'] == null ? null : DateTime.parse(json['next_due_date'] as String),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'name': name,
        'date_administered': dateOnly(dateAdministered),
        if (nextDueDate != null) 'next_due_date': dateOnly(nextDueDate!),
        if (notes != null) 'notes': notes,
      };
}
```

- [ ] **Step 4: Run the model test again**

```bash
flutter test test/models/vaccination_test.dart
```

Expected: PASS.

- [ ] **Step 5: Create `lib/repositories/vaccinations_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vaccination.dart';

abstract class VaccinationsRepository {
  Future<List<Vaccination>> fetchForPet(String petId);
  Future<void> create(Vaccination vaccination);
}

class SupabaseVaccinationsRepository implements VaccinationsRepository {
  SupabaseVaccinationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async {
    final rows = await _client
        .from('vaccinations')
        .select()
        .eq('pet_id', petId)
        .order('date_administered', ascending: false);
    return rows.map((row) => Vaccination.fromJson(row)).toList();
  }

  @override
  Future<void> create(Vaccination vaccination) async {
    await _client.from('vaccinations').insert(vaccination.toInsertJson());
  }
}
```

- [ ] **Step 6: Create `lib/providers/vaccinations_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vaccination.dart';
import '../repositories/vaccinations_repository.dart';

final vaccinationsRepositoryProvider =
    Provider<VaccinationsRepository>((ref) => SupabaseVaccinationsRepository(Supabase.instance.client));

final vaccinationsProvider = FutureProvider.family<List<Vaccination>, String>((ref, petId) {
  return ref.watch(vaccinationsRepositoryProvider).fetchForPet(petId);
});
```

- [ ] **Step 7: Write the failing widget test**

Create `test/screens/vaccinations_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vaccinations_tab.dart';

void main() {
  testWidgets('shows vaccinations for the given pet', (tester) async {
    final vaccinations = [
      Vaccination(id: 'v1', petId: 'p1', name: 'Rage', dateAdministered: DateTime(2024, 1, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaccinationsProvider('p1').overrideWith((ref) async => vaccinations)],
        child: const MaterialApp(home: VaccinationsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rage'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no vaccinations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaccinationsProvider('p1').overrideWith((ref) async => <Vaccination>[])],
        child: const MaterialApp(home: VaccinationsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun vaccin enregistré'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run it to confirm it fails**

```bash
flutter test test/screens/vaccinations_tab_test.dart
```

Expected: FAIL — `VaccinationsTab` is still the Task 5 placeholder.

- [ ] **Step 9: Replace `lib/screens/pet_detail/widgets/vaccinations_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../date_only.dart';
import '../../../models/vaccination.dart';
import '../../../providers/vaccinations_provider.dart';

class VaccinationsTab extends ConsumerWidget {
  const VaccinationsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaccinationsAsync = ref.watch(vaccinationsProvider(petId));

    return Scaffold(
      body: vaccinationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(vaccinationsProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (vaccinations) => vaccinations.isEmpty
            ? const Center(child: Text('Aucun vaccin enregistré'))
            : ListView.builder(
                itemCount: vaccinations.length,
                itemBuilder: (context, index) {
                  final vaccination = vaccinations[index];
                  final nextDue = vaccination.nextDueDate;
                  return ListTile(
                    title: Text(vaccination.name),
                    subtitle: Text(
                      'Fait le ${dateOnly(vaccination.dateAdministered)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVaccinationSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddVaccinationSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    DateTime dateAdministered = DateTime.now();
    DateTime? nextDueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du vaccin'),
              ),
              ListTile(
                title: Text('Administré le ${dateOnly(dateAdministered)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: dateAdministered,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => dateAdministered = picked);
                },
              ),
              ListTile(
                title: Text(nextDueDate == null ? 'Pas de rappel' : 'Rappel le ${dateOnly(nextDueDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: nextDueDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => nextDueDate = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    await ref.read(vaccinationsRepositoryProvider).create(Vaccination(
                          id: '',
                          petId: petId,
                          name: nameController.text.trim(),
                          dateAdministered: dateAdministered,
                          nextDueDate: nextDueDate,
                        ));
                    ref.invalidate(vaccinationsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run the full suite and commit**

```bash
flutter test
git add -A
git commit -m "feat: add vaccination tracking"
```

---

## Task 7: Weight tracking

**Files:**
- Create: `lib/models/weight_entry.dart`, `lib/repositories/weight_entries_repository.dart`, `lib/providers/weight_entries_provider.dart`, `test/models/weight_entry_test.dart`, `test/screens/weight_tab_test.dart`
- Modify: `lib/screens/pet_detail/widgets/weight_tab.dart` (replace placeholder)

**Interfaces:**
- Produces: `WeightEntry` model, `WeightEntriesRepository`, `weightEntriesRepositoryProvider`, `weightEntriesProvider` (`FutureProvider.family<List<WeightEntry>, String>`).

- [ ] **Step 1: Write the failing model test**

Create `test/models/weight_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/weight_entry.dart';

void main() {
  test('WeightEntry.fromJson parses a record', () {
    final entry = WeightEntry.fromJson({
      'id': 'w1',
      'pet_id': 'p1',
      'weight_kg': '12.5',
      'recorded_at': '2024-03-01',
    });
    expect(entry.weightKg, 12.5);
    expect(entry.recordedAt, DateTime(2024, 3, 1));
  });

  test('toInsertJson serializes weight and date', () {
    final entry = WeightEntry(id: '', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 3, 1));
    final json = entry.toInsertJson();
    expect(json['weight_kg'], 12.5);
    expect(json['recorded_at'], '2024-03-01');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/models/weight_entry_test.dart
```

Expected: FAIL — `lib/models/weight_entry.dart` doesn't exist.

- [ ] **Step 3: Create `lib/models/weight_entry.dart`**

Postgres `numeric` columns are returned as strings by the Supabase Dart client, so parse with `num.parse`.

```dart
import '../date_only.dart';

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.petId,
    required this.weightKg,
    required this.recordedAt,
  });

  final String id;
  final String petId;
  final double weightKg;
  final DateTime recordedAt;

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        weightKg: num.parse(json['weight_kg'].toString()).toDouble(),
        recordedAt: DateTime.parse(json['recorded_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'weight_kg': weightKg,
        'recorded_at': dateOnly(recordedAt),
      };
}
```

- [ ] **Step 4: Run the model test again**

```bash
flutter test test/models/weight_entry_test.dart
```

Expected: PASS.

- [ ] **Step 5: Create `lib/repositories/weight_entries_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';

class WeightEntriesRepository {
  WeightEntriesRepository(this._client);

  final SupabaseClient _client;

  Future<List<WeightEntry>> fetchForPet(String petId) async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('pet_id', petId)
        .order('recorded_at', ascending: false);
    return rows.map((row) => WeightEntry.fromJson(row)).toList();
  }

  Future<void> create(WeightEntry entry) async {
    await _client.from('weight_entries').insert(entry.toInsertJson());
  }
}
```

- [ ] **Step 6: Create `lib/providers/weight_entries_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';
import '../repositories/weight_entries_repository.dart';

final weightEntriesRepositoryProvider =
    Provider((ref) => WeightEntriesRepository(Supabase.instance.client));

final weightEntriesProvider = FutureProvider.family<List<WeightEntry>, String>((ref, petId) {
  return ref.watch(weightEntriesRepositoryProvider).fetchForPet(petId);
});
```

- [ ] **Step 7: Write the failing widget test**

Create `test/screens/weight_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/weight_entry.dart';
import 'package:pawfolio/providers/weight_entries_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/weight_tab.dart';

void main() {
  testWidgets('shows weight entries for the given pet', (tester) async {
    final entries = [
      WeightEntry(id: 'w1', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 3, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [weightEntriesProvider('p1').overrideWith((ref) async => entries)],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('12.5'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no entries', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [weightEntriesProvider('p1').overrideWith((ref) async => <WeightEntry>[])],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune pesée enregistrée'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run it to confirm it fails**

```bash
flutter test test/screens/weight_tab_test.dart
```

Expected: FAIL — `WeightTab` is still the Task 5 placeholder.

- [ ] **Step 9: Replace `lib/screens/pet_detail/widgets/weight_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../date_only.dart';
import '../../../models/weight_entry.dart';
import '../../../providers/weight_entries_provider.dart';

class WeightTab extends ConsumerWidget {
  const WeightTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(weightEntriesProvider(petId));

    return Scaffold(
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(weightEntriesProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (entries) => entries.isEmpty
            ? const Center(child: Text('Aucune pesée enregistrée'))
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text('${entry.weightKg} kg'),
                    subtitle: Text(dateOnly(entry.recordedAt)),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWeightSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWeightSheet(BuildContext context, WidgetRef ref) {
    final weightController = TextEditingController();
    DateTime recordedAt = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              ListTile(
                title: Text('Pesée le ${dateOnly(recordedAt)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: recordedAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => recordedAt = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
                  if (weight == null) return;
                  try {
                    await ref.read(weightEntriesRepositoryProvider).create(WeightEntry(
                          id: '',
                          petId: petId,
                          weightKg: weight,
                          recordedAt: recordedAt,
                        ));
                    ref.invalidate(weightEntriesProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run the full suite and commit**

```bash
flutter test
git add -A
git commit -m "feat: add weight tracking"
```

---

## Task 8: Treatments

**Files:**
- Create: `lib/models/treatment.dart`, `lib/repositories/treatments_repository.dart`, `lib/providers/treatments_provider.dart`, `test/models/treatment_test.dart`, `test/screens/treatments_tab_test.dart`
- Modify: `lib/screens/pet_detail/widgets/treatments_tab.dart` (replace placeholder)

**Interfaces:**
- Produces: `Treatment` model, `TreatmentsRepository`, `treatmentsRepositoryProvider`, `treatmentsProvider` (`FutureProvider.family<List<Treatment>, String>`).

- [ ] **Step 1: Write the failing model test**

Create `test/models/treatment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/treatment.dart';

void main() {
  test('Treatment.fromJson parses a full record', () {
    final treatment = Treatment.fromJson({
      'id': 't1',
      'pet_id': 'p1',
      'type': 'dewormer',
      'name': 'Milbemax',
      'date_given': '2024-02-01',
      'next_due_date': '2024-05-01',
      'notes': null,
    });
    expect(treatment.type, 'dewormer');
    expect(treatment.name, 'Milbemax');
    expect(treatment.dateGiven, DateTime(2024, 2, 1));
    expect(treatment.nextDueDate, DateTime(2024, 5, 1));
  });

  test('toInsertJson omits null optional fields', () {
    final treatment = Treatment(
      id: '',
      petId: 'p1',
      type: 'antiparasitic',
      name: 'Frontline',
      dateGiven: DateTime(2024, 2, 1),
    );
    final json = treatment.toInsertJson();
    expect(json.containsKey('next_due_date'), isFalse);
    expect(json.containsKey('notes'), isFalse);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/models/treatment_test.dart
```

Expected: FAIL — `lib/models/treatment.dart` doesn't exist.

- [ ] **Step 3: Create `lib/models/treatment.dart`**

```dart
import '../date_only.dart';

class Treatment {
  const Treatment({
    required this.id,
    required this.petId,
    required this.type,
    required this.name,
    required this.dateGiven,
    this.nextDueDate,
    this.notes,
  });

  final String id;
  final String petId;
  final String type;
  final String name;
  final DateTime dateGiven;
  final DateTime? nextDueDate;
  final String? notes;

  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        dateGiven: DateTime.parse(json['date_given'] as String),
        nextDueDate: json['next_due_date'] == null ? null : DateTime.parse(json['next_due_date'] as String),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'type': type,
        'name': name,
        'date_given': dateOnly(dateGiven),
        if (nextDueDate != null) 'next_due_date': dateOnly(nextDueDate!),
        if (notes != null) 'notes': notes,
      };
}
```

- [ ] **Step 4: Run the model test again**

```bash
flutter test test/models/treatment_test.dart
```

Expected: PASS.

- [ ] **Step 5: Create `lib/repositories/treatments_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/treatment.dart';

class TreatmentsRepository {
  TreatmentsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Treatment>> fetchForPet(String petId) async {
    final rows = await _client
        .from('treatments')
        .select()
        .eq('pet_id', petId)
        .order('date_given', ascending: false);
    return rows.map((row) => Treatment.fromJson(row)).toList();
  }

  Future<void> create(Treatment treatment) async {
    await _client.from('treatments').insert(treatment.toInsertJson());
  }
}
```

- [ ] **Step 6: Create `lib/providers/treatments_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/treatment.dart';
import '../repositories/treatments_repository.dart';

final treatmentsRepositoryProvider =
    Provider((ref) => TreatmentsRepository(Supabase.instance.client));

final treatmentsProvider = FutureProvider.family<List<Treatment>, String>((ref, petId) {
  return ref.watch(treatmentsRepositoryProvider).fetchForPet(petId);
});
```

- [ ] **Step 7: Write the failing widget test**

Create `test/screens/treatments_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/treatment.dart';
import 'package:pawfolio/providers/treatments_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/treatments_tab.dart';

void main() {
  testWidgets('shows treatments for the given pet', (tester) async {
    final treatments = [
      Treatment(id: 't1', petId: 'p1', type: 'dewormer', name: 'Milbemax', dateGiven: DateTime(2024, 2, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [treatmentsProvider('p1').overrideWith((ref) async => treatments)],
        child: const MaterialApp(home: TreatmentsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milbemax'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no treatments', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [treatmentsProvider('p1').overrideWith((ref) async => <Treatment>[])],
        child: const MaterialApp(home: TreatmentsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun traitement enregistré'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run it to confirm it fails**

```bash
flutter test test/screens/treatments_tab_test.dart
```

Expected: FAIL — `TreatmentsTab` is still the Task 5 placeholder.

- [ ] **Step 9: Replace `lib/screens/pet_detail/widgets/treatments_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../date_only.dart';
import '../../../models/treatment.dart';
import '../../../providers/treatments_provider.dart';

class TreatmentsTab extends ConsumerWidget {
  const TreatmentsTab({required this.petId, super.key});

  final String petId;

  static const _typeLabels = {
    'dewormer': 'Vermifuge',
    'antiparasitic': 'Antiparasitaire',
    'other': 'Autre',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsProvider(petId));

    return Scaffold(
      body: treatmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(treatmentsProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (treatments) => treatments.isEmpty
            ? const Center(child: Text('Aucun traitement enregistré'))
            : ListView.builder(
                itemCount: treatments.length,
                itemBuilder: (context, index) {
                  final treatment = treatments[index];
                  final nextDue = treatment.nextDueDate;
                  return ListTile(
                    title: Text(treatment.name),
                    subtitle: Text(
                      '${_typeLabels[treatment.type]} · fait le ${dateOnly(treatment.dateGiven)}'
                      '${nextDue != null ? ' · rappel le ${dateOnly(nextDue)}' : ''}',
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTreatmentSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTreatmentSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String type = 'dewormer';
    DateTime dateGiven = DateTime.now();
    DateTime? nextDueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du traitement'),
              ),
              DropdownButton<String>(
                value: type,
                items: _typeLabels.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) => setState(() => type = value!),
              ),
              ListTile(
                title: Text('Donné le ${dateOnly(dateGiven)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: dateGiven,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => dateGiven = picked);
                },
              ),
              ListTile(
                title: Text(nextDueDate == null ? 'Pas de rappel' : 'Rappel le ${dateOnly(nextDueDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: nextDueDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => nextDueDate = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    await ref.read(treatmentsRepositoryProvider).create(Treatment(
                          id: '',
                          petId: petId,
                          type: type,
                          name: nameController.text.trim(),
                          dateGiven: dateGiven,
                          nextDueDate: nextDueDate,
                        ));
                    ref.invalidate(treatmentsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run the full suite and commit**

```bash
flutter test
git add -A
git commit -m "feat: add treatment tracking"
```

---

## Task 9: Vet visits

**Files:**
- Create: `lib/models/vet_visit.dart`, `lib/repositories/vet_visits_repository.dart`, `lib/providers/vet_visits_provider.dart`, `test/models/vet_visit_test.dart`, `test/screens/vet_visits_tab_test.dart`
- Modify: `lib/screens/pet_detail/widgets/vet_visits_tab.dart` (replace placeholder)

**Interfaces:**
- Produces: `VetVisit` model, `VetVisitsRepository`, `vetVisitsRepositoryProvider`, `vetVisitsProvider` (`FutureProvider.family<List<VetVisit>, String>`).

- [ ] **Step 1: Write the failing model test**

Create `test/models/vet_visit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vet_visit.dart';

void main() {
  test('VetVisit.fromJson parses a full record', () {
    final visit = VetVisit.fromJson({
      'id': 'vv1',
      'pet_id': 'p1',
      'visit_date': '2024-04-10',
      'reason': 'Contrôle annuel',
      'notes': 'RAS',
      'next_visit_date': '2025-04-10',
    });
    expect(visit.reason, 'Contrôle annuel');
    expect(visit.visitDate, DateTime(2024, 4, 10));
    expect(visit.nextVisitDate, DateTime(2025, 4, 10));
  });

  test('toInsertJson omits null optional fields', () {
    final visit = VetVisit(id: '', petId: 'p1', visitDate: DateTime(2024, 4, 10), reason: 'Contrôle annuel');
    final json = visit.toInsertJson();
    expect(json.containsKey('notes'), isFalse);
    expect(json.containsKey('next_visit_date'), isFalse);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/models/vet_visit_test.dart
```

Expected: FAIL — `lib/models/vet_visit.dart` doesn't exist.

- [ ] **Step 3: Create `lib/models/vet_visit.dart`**

```dart
import '../date_only.dart';

class VetVisit {
  const VetVisit({
    required this.id,
    required this.petId,
    required this.visitDate,
    required this.reason,
    this.notes,
    this.nextVisitDate,
  });

  final String id;
  final String petId;
  final DateTime visitDate;
  final String reason;
  final String? notes;
  final DateTime? nextVisitDate;

  factory VetVisit.fromJson(Map<String, dynamic> json) => VetVisit(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        visitDate: DateTime.parse(json['visit_date'] as String),
        reason: json['reason'] as String,
        notes: json['notes'] as String?,
        nextVisitDate:
            json['next_visit_date'] == null ? null : DateTime.parse(json['next_visit_date'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'visit_date': dateOnly(visitDate),
        'reason': reason,
        if (notes != null) 'notes': notes,
        if (nextVisitDate != null) 'next_visit_date': dateOnly(nextVisitDate!),
      };
}
```

- [ ] **Step 4: Run the model test again**

```bash
flutter test test/models/vet_visit_test.dart
```

Expected: PASS.

- [ ] **Step 5: Create `lib/repositories/vet_visits_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vet_visit.dart';

class VetVisitsRepository {
  VetVisitsRepository(this._client);

  final SupabaseClient _client;

  Future<List<VetVisit>> fetchForPet(String petId) async {
    final rows = await _client
        .from('vet_visits')
        .select()
        .eq('pet_id', petId)
        .order('visit_date', ascending: false);
    return rows.map((row) => VetVisit.fromJson(row)).toList();
  }

  Future<void> create(VetVisit visit) async {
    await _client.from('vet_visits').insert(visit.toInsertJson());
  }
}
```

- [ ] **Step 6: Create `lib/providers/vet_visits_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vet_visit.dart';
import '../repositories/vet_visits_repository.dart';

final vetVisitsRepositoryProvider =
    Provider((ref) => VetVisitsRepository(Supabase.instance.client));

final vetVisitsProvider = FutureProvider.family<List<VetVisit>, String>((ref, petId) {
  return ref.watch(vetVisitsRepositoryProvider).fetchForPet(petId);
});
```

- [ ] **Step 7: Write the failing widget test**

Create `test/screens/vet_visits_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vet_visit.dart';
import 'package:pawfolio/providers/vet_visits_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/vet_visits_tab.dart';

void main() {
  testWidgets('shows vet visits for the given pet', (tester) async {
    final visits = [
      VetVisit(id: 'vv1', petId: 'p1', visitDate: DateTime(2024, 4, 10), reason: 'Contrôle annuel'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetVisitsProvider('p1').overrideWith((ref) async => visits)],
        child: const MaterialApp(home: VetVisitsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contrôle annuel'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no visits', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetVisitsProvider('p1').overrideWith((ref) async => <VetVisit>[])],
        child: const MaterialApp(home: VetVisitsTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun rendez-vous enregistré'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run it to confirm it fails**

```bash
flutter test test/screens/vet_visits_tab_test.dart
```

Expected: FAIL — `VetVisitsTab` is still the Task 5 placeholder.

- [ ] **Step 9: Replace `lib/screens/pet_detail/widgets/vet_visits_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../date_only.dart';
import '../../../models/vet_visit.dart';
import '../../../providers/vet_visits_provider.dart';

class VetVisitsTab extends ConsumerWidget {
  const VetVisitsTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(vetVisitsProvider(petId));

    return Scaffold(
      body: visitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(vetVisitsProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (visits) => visits.isEmpty
            ? const Center(child: Text('Aucun rendez-vous enregistré'))
            : ListView.builder(
                itemCount: visits.length,
                itemBuilder: (context, index) {
                  final visit = visits[index];
                  final nextVisit = visit.nextVisitDate;
                  return ListTile(
                    title: Text(visit.reason),
                    subtitle: Text(
                      'Le ${dateOnly(visit.visitDate)}'
                      '${nextVisit != null ? ' · prochain RDV le ${dateOnly(nextVisit)}' : ''}',
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVisitSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddVisitSheet(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    DateTime visitDate = DateTime.now();
    DateTime? nextVisitDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Motif'),
              ),
              ListTile(
                title: Text('Le ${dateOnly(visitDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: visitDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => visitDate = picked);
                },
              ),
              ListTile(
                title: Text(
                  nextVisitDate == null ? 'Pas de prochain RDV' : 'Prochain RDV le ${dateOnly(nextVisitDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: nextVisitDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => nextVisitDate = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) return;
                  try {
                    await ref.read(vetVisitsRepositoryProvider).create(VetVisit(
                          id: '',
                          petId: petId,
                          visitDate: visitDate,
                          reason: reasonController.text.trim(),
                          nextVisitDate: nextVisitDate,
                        ));
                    ref.invalidate(vetVisitsProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run the full suite and commit**

```bash
flutter test
git add -A
git commit -m "feat: add vet visit tracking"
```

---

## Task 10: Upcoming reminders and local notifications

**Files:**
- Create: `supabase/migrations/20260817000100_upcoming_reminders_view.sql`, `lib/reminders.dart`, `lib/repositories/reminders_repository.dart`, `lib/providers/reminders_provider.dart`, `lib/notifications/reminder_scheduler.dart`, `test/reminders_test.dart`
- Modify: `lib/screens/home/home_screen.dart` (add upcoming banner + notification scheduling), `lib/main.dart` (init the scheduler)

**Interfaces:**
- Consumes: `petsProvider` (Task 5).
- Produces: `DueItem` (in `lib/reminders.dart`), `sortUpcoming(List<DueItem>, {DateTime? now}) -> List<DueItem>` (pure function), `upcomingRemindersProvider` (`FutureProvider<List<DueItem>>`), `ReminderScheduler` with `Future<void> init()` and `Future<void> scheduleAll(List<DueItem>)`.

- [ ] **Step 1: Write the failing unit test for the pure reminder logic**

Create `test/reminders_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/reminders.dart';

void main() {
  final now = DateTime(2024, 6, 15);

  test('filters out due dates strictly before today', () {
    final items = [
      DueItem(petId: 'p1', petName: 'Rex', label: 'Rage', dueDate: DateTime(2024, 6, 14)),
      DueItem(petId: 'p1', petName: 'Rex', label: 'Vermifuge', dueDate: DateTime(2024, 6, 15)),
    ];
    final result = sortUpcoming(items, now: now);
    expect(result.map((item) => item.label), ['Vermifuge']);
  });

  test('sorts remaining items by due date ascending', () {
    final items = [
      DueItem(petId: 'p1', petName: 'Rex', label: 'B', dueDate: DateTime(2024, 7, 1)),
      DueItem(petId: 'p1', petName: 'Rex', label: 'A', dueDate: DateTime(2024, 6, 20)),
    ];
    final result = sortUpcoming(items, now: now);
    expect(result.map((item) => item.label), ['A', 'B']);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/reminders_test.dart
```

Expected: FAIL — `lib/reminders.dart` doesn't exist.

- [ ] **Step 3: Create `lib/reminders.dart`**

```dart
class DueItem {
  const DueItem({
    required this.petId,
    required this.petName,
    required this.label,
    required this.dueDate,
  });

  final String petId;
  final String petName;
  final String label;
  final DateTime dueDate;
}

List<DueItem> sortUpcoming(List<DueItem> items, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final upcoming = items.where((item) => !item.dueDate.isBefore(startOfToday)).toList();
  upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return upcoming;
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/reminders_test.dart
```

Expected: PASS.

- [ ] **Step 5: Add the cross-table view migration**

Create `supabase/migrations/20260817000100_upcoming_reminders_view.sql`:

```sql
create view public.upcoming_reminders
  with (security_invoker = true) as
  select pet_id, name as label, next_due_date as due_date
  from public.vaccinations
  where next_due_date is not null
  union all
  select pet_id, name as label, next_due_date as due_date
  from public.treatments
  where next_due_date is not null
  union all
  select pet_id, reason as label, next_visit_date as due_date
  from public.vet_visits
  where next_visit_date is not null;
```

Apply it:

```bash
supabase migration up
PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -c "select * from public.upcoming_reminders limit 1;"
```

Expected: query runs without error (empty result is fine on a fresh database).

- [ ] **Step 6: Create `lib/repositories/reminders_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../reminders.dart';

class RemindersRepository {
  RemindersRepository(this._client);

  final SupabaseClient _client;

  Future<List<DueItem>> fetchUpcoming(Map<String, String> petNamesById) async {
    final rows = await _client.from('upcoming_reminders').select('pet_id, label, due_date');
    return rows.map((row) {
      final petId = row['pet_id'] as String;
      return DueItem(
        petId: petId,
        petName: petNamesById[petId] ?? '?',
        label: row['label'] as String,
        dueDate: DateTime.parse(row['due_date'] as String),
      );
    }).toList();
  }
}
```

- [ ] **Step 7: Create `lib/providers/reminders_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../reminders.dart';
import '../repositories/reminders_repository.dart';
import 'pets_provider.dart';

final remindersRepositoryProvider =
    Provider((ref) => RemindersRepository(Supabase.instance.client));

final upcomingRemindersProvider = FutureProvider<List<DueItem>>((ref) async {
  final pets = await ref.watch(petsProvider.future);
  final petNamesById = {for (final pet in pets) pet.id: pet.name};
  final items = await ref.watch(remindersRepositoryProvider).fetchUpcoming(petNamesById);
  return sortUpcoming(items);
});
```

- [ ] **Step 8: Add dependencies for local notifications**

```bash
flutter pub add flutter_local_notifications timezone
```

- [ ] **Step 9: Create `lib/notifications/reminder_scheduler.dart`**

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../reminders.dart';

final reminderSchedulerProvider =
    Provider((ref) => ReminderScheduler(FlutterLocalNotificationsPlugin()));

class ReminderScheduler {
  ReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
  }

  // ponytail: schedules against UTC wall-clock time instead of the device's
  // real timezone (that needs the flutter_timezone plugin to detect it).
  // A reminder may fire a few hours off from local midnight; acceptable for
  // a single-user MVP — revisit if multi-timezone usage makes this visible.
  Future<void> scheduleAll(List<DueItem> items) async {
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.UTC);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final scheduledDate = tz.TZDateTime(
        tz.UTC,
        item.dueDate.year,
        item.dueDate.month,
        item.dueDate.day,
        9,
      );
      if (scheduledDate.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        i,
        item.petName,
        item.label,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails('reminders', 'Rappels'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
```

- [ ] **Step 10: Initialize the scheduler in `lib/main.dart`**

Add these imports:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notifications/reminder_scheduler.dart';
```

In `main()`, after `Supabase.initialize(...)` and before `runApp(...)`, add:

```dart
final scheduler = ReminderScheduler(FlutterLocalNotificationsPlugin());
await scheduler.init();
```

(This direct instance in `main()` only runs the one-time `init()` before the app starts; widgets get their own `ReminderScheduler` from `reminderSchedulerProvider` — defined alongside the class in Step 9 — via Riverpod.)

- [ ] **Step 11: Add the upcoming banner and scheduling side-effect to `lib/screens/home/home_screen.dart`**

Add these imports:

```dart
import '../../notifications/reminder_scheduler.dart';
import '../../providers/reminders_provider.dart';
```

At the top of `HomeScreen.build`, before the `petsAsync` line, add:

```dart
ref.listen(upcomingRemindersProvider, (previous, next) {
  next.whenData((items) => ref.read(reminderSchedulerProvider).scheduleAll(items));
});
final upcomingAsync = ref.watch(upcomingRemindersProvider);
```

Insert an upcoming-reminders section above the pet list, replacing the `body: RefreshIndicator(...)` line with:

```dart
body: RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(petsProvider);
    ref.invalidate(upcomingRemindersProvider);
  },
  child: ListView(
    children: [
      upcomingAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) => items.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('À venir', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final item in items.take(3))
                      ListTile(
                        dense: true,
                        title: Text('${item.petName} · ${item.label}'),
                        subtitle: Text(dateOnly(item.dueDate)),
                      ),
                    const Divider(),
                  ],
                ),
              ),
      ),
      petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(onPressed: () => ref.invalidate(petsProvider), child: const Text('Réessayer')),
            ],
          ),
        ),
        data: (pets) => pets.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Aucun animal pour le moment')),
              )
            : Column(
                children: [
                  for (final pet in pets)
                    ListTile(
                      title: Text(pet.name),
                      subtitle: Text(pet.species),
                      onTap: () => context.push('/pets/${pet.id}'),
                    ),
                ],
              ),
      ),
    ],
  ),
),
```

Add the `dateOnly` import at the top of the file:

```dart
import '../../date_only.dart';
```

Note: `ListView.builder`'s per-item loading/error states inside a single outer `ListView` are collapsed into `Column`s here since each `when()` branch now renders a fixed-size chunk of a larger scrollable list rather than being the whole scrollable itself.

- [ ] **Step 12: Run the full suite and commit**

```bash
flutter test
git add -A
git commit -m "feat: add upcoming reminders and local notification scheduling"
```

---

## Task 11: End-to-end verification

**Files:**
- Test: `test/e2e/add_pet_and_vaccination_test.dart` (the `FakePetsRepository`/`FakeVaccinationsRepository` classes it defines are test-only, not part of `lib/`)

**Interfaces:**
- Consumes: `PetsRepository`, `VaccinationsRepository` interfaces (Tasks 5, 6), `HomeScreen`, `PetDetailScreen`, `upcomingRemindersProvider` (Task 10).

- [ ] **Step 1: Write the end-to-end widget test**

`HomeScreen` also watches `upcomingRemindersProvider` (Task 10), which builds a `RemindersRepository` from the real `Supabase.instance.client` unless overridden, and its listener calls `ReminderScheduler.scheduleAll`, which talks to the `flutter_local_notifications` platform channel — neither exists in a plain widget test. Override `upcomingRemindersProvider` directly (sidestepping Supabase entirely) and mock the notifications channel so `cancelAll()` doesn't throw `MissingPluginException`.

Create `test/e2e/add_pet_and_vaccination_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/models/vaccination.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/providers/vaccinations_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/repositories/pets_repository.dart';
import 'package:pawfolio/repositories/vaccinations_repository.dart';
import 'package:pawfolio/screens/home/home_screen.dart';
import 'package:pawfolio/screens/pet_detail/pet_detail_screen.dart';

const _localNotificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');

class FakePetsRepository implements PetsRepository {
  final List<Pet> pets = [];

  @override
  Future<List<Pet>> fetchAll() async => pets;

  @override
  Future<Pet> create(Pet pet) async {
    final created = Pet(id: 'p1', ownerId: 'u1', name: pet.name, species: pet.species);
    pets.add(created);
    return created;
  }
}

class FakeVaccinationsRepository implements VaccinationsRepository {
  final List<Vaccination> vaccinations = [];

  @override
  Future<List<Vaccination>> fetchForPet(String petId) async =>
      vaccinations.where((v) => v.petId == petId).toList();

  @override
  Future<void> create(Vaccination vaccination) async => vaccinations.add(vaccination);
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, null);
  });

  testWidgets('add a pet, then add a vaccination, and see it in the list', (tester) async {
    final petsRepo = FakePetsRepository();
    final vaccinationsRepo = FakeVaccinationsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsRepositoryProvider.overrideWithValue(petsRepo),
          vaccinationsRepositoryProvider.overrideWithValue(vaccinationsRepo),
          upcomingRemindersProvider.overrideWith((ref) async => <DueItem>[]),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Add a pet via the FAB bottom sheet.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rex');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsOneWidget);

    // Navigate to the pet's detail screen directly (go_router isn't in this
    // test's widget tree — HomeScreen's onTap calls context.push, which
    // needs a real router. Pumping PetDetailScreen directly keeps this test
    // focused on data flow rather than navigation.)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsRepositoryProvider.overrideWithValue(petsRepo),
          vaccinationsRepositoryProvider.overrideWithValue(vaccinationsRepo),
        ],
        child: const MaterialApp(home: PetDetailScreen(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    // Add a vaccination via the Vaccins tab's FAB.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rage');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Rage'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it**

```bash
flutter test test/e2e/add_pet_and_vaccination_test.dart
```

Expected: PASS. If the `DropdownButton` in the add-pet sheet intercepts the first `TextField` lookup, or a specific finder is ambiguous, adjust the finder to `find.widgetWithText(TextField, 'Nom')` style lookups — the fakes and flow are correct either way.

- [ ] **Step 3: Manual verification on the Android emulator**

```bash
cd /home/missia03/Projects/pawfolio
emulator -avd pawfolio -no-snapshot-load &
adb wait-for-device
# wait for full boot:
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
./scripts/run_local.sh &
sleep 60
adb shell screencap -p /sdcard/pawfolio.png
adb pull /sdcard/pawfolio.png /tmp/pawfolio.png
```

Read `/tmp/pawfolio.png` and confirm it shows either the login screen or the home screen (depending on how far `flutter run`'s hot-reload got booting). If it's the login screen, sign up with a test email/password via `adb shell input tap`/`input text`, then screenshot again to confirm the home screen and "add pet" flow work against the real local Supabase stack (not just the fakes from Step 1-2).

- [ ] **Step 4: Final commit**

```bash
cd /home/missia03/Projects/pawfolio
git add -A
git commit -m "test: add end-to-end add-pet-and-vaccination coverage"
```

---

## Post-plan follow-ups (not part of this plan's scope)

- iOS build/testing once a Mac or CI (Codemagic/Fastlane) is available.
- A real Supabase cloud project (the local Docker stack is dev-only) before any public release.
- Offline support, if real usage shows it's needed.
- Document/photo attachments, multi-user pet sharing — both explicitly deferred in the design spec.
