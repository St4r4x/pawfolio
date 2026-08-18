# Pawfolio Visual Design v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Pawfolio a bottom-navigation IA (Mes animaux / Rappels / Profil), a dark theme, illustrated empty states with two Lottie success moments, a weight-trend chart, and deliberate motion (list stagger + screen transitions) — all respecting reduced motion.

**Architecture:** Hybrid, targeted reuse — three shared pieces (`EmptyState`, `PetAvatar`, `lib/motion.dart` tokens) rather than a general component library; every other widget (`Card`, `FilledButton`, `TextField`, `ListTile`) keeps reading `ThemeData` directly as it does today. `go_router`'s `StatefulShellRoute.indexedStack` wraps the three tab roots; `/pets/:id` stays a top-level route pushed on top, same as its current behavior.

**Tech Stack:** Flutter/Dart, Riverpod, `go_router` ^17.5.0 (already present — `StatefulShellRoute` needs no new dependency). New packages: `flutter_svg`, `lottie`, `fl_chart`, `flutter_animate`, `animations` (Google Material Motion), plus `shared_preferences` moved from `dev_dependencies` to `dependencies`.

**Spec:** `docs/superpowers/specs/2026-08-18-pawfolio-visual-design-v2-design.md` — read it alongside this plan; task rationale (why hybrid reuse, why these specific packages, exact contrast calculations) lives there and isn't repeated in full here.

## Global Constraints

- Dark-mode color tokens (exact hex, from the spec): `background` #16100F, `surface` #221A18, `primary` #E2836A, `onPrimary` #3A140A, `accentPositive` #6FCDA0, `warningDueSoon` #E3A548, `error` #FFB4AB, `onError` #4A0E08, `ink` #F2E9E6, `muted` #B9ACA6, `border` #3A2E2B. Light tokens (existing, unchanged): see `lib/theme.dart`.
- No new dependency for the bottom nav — `StatefulShellRoute.indexedStack` is part of the `go_router` package already in `pubspec.yaml`.
- `/pets/:id` is a **top-level route outside the shell**, not a nested branch — pushing it must fully cover the bottom nav, matching today's behavior.
- Icons stay Flutter's built-in Material Symbols (`Icons.*`) everywhere except the six illustrated empty states and two Lottie moments explicitly scoped in Tasks 8 and 9.
- Motion durations/curves (from the spec): micro-interactions 180ms (`Curves.easeOutCubic`), screen transitions 300ms, list stagger 40ms per item, entrance curve `Curves.easeOutQuart`. Every animated call must route its duration through a single reduced-motion guard (`AppMotion.durationOrInstant`, added in Task 10) rather than using the raw constants directly.
- No golden-image testing for colors, illustrations, or motion — disproportionate for this app's size (same reasoning as the first design-polish plan). Manual verification on the Android emulator covers light theme, dark theme, and the emulator's reduced-motion accessibility setting (Task 11).
- No change to the data model, Supabase schema, or any bottom-sheet form's fields — this plan is entirely presentation-layer.
- Any step that downloads a file from an external source (Tasks 8 and 9) must first state the exact filename(s), source, and approximate size, and get explicit user confirmation before fetching — this is a hard rule for this session, not a suggestion the executor can skip.
- French UI strings only (matches the rest of the app) — don't introduce English copy.

---

## Task 1: Dark theme & theme-mode persistence

**Files:**
- Modify: `pubspec.yaml`, `lib/theme.dart`, `lib/main.dart`
- Create: `lib/providers/theme_mode_provider.dart`, `test/providers/theme_mode_provider_test.dart`

**Interfaces:**
- Produces: `pawfolioDarkTheme` (top-level `final ThemeData`, `lib/theme.dart`) and `themeModeProvider` (`NotifierProvider<ThemeModeNotifier, ThemeMode>`, `lib/providers/theme_mode_provider.dart`) with `ThemeModeNotifier.setThemeMode(ThemeMode mode) -> Future<void>`. Task 4's `ProfileScreen` reads `themeModeProvider` and calls `.notifier.setThemeMode(...)`.

- [ ] **Step 1: Move `shared_preferences` to `dependencies`**

Open `pubspec.yaml`. Remove this line from the `dev_dependencies:` section:

```yaml
  shared_preferences: ^2.5.5
```

Add it to the `dependencies:` section instead, right after `google_fonts`:

```yaml
  google_fonts: ^8.2.1
  shared_preferences: ^2.5.5
```

Run `flutter pub get` to confirm the lockfile resolves cleanly:

```bash
cd /home/missia03/Projects/pawfolio
flutter pub get
```

Expected: no errors — `shared_preferences` is already in `pubspec.lock` at a compatible version, only its dependency-section location changed.

- [ ] **Step 2: Write the failing test for `ThemeModeNotifier`**

Create `test/providers/theme_mode_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to ThemeMode.system with no stored preference', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('setThemeMode updates state and persists the choice', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('loads a previously persisted preference on the next build', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // The first read triggers build(), which returns ThemeMode.system
    // synchronously and kicks off the async _load() in the background.
    container.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
```

- [ ] **Step 3: Run it to confirm it fails**

```bash
flutter test test/providers/theme_mode_provider_test.dart
```

Expected: FAIL — `lib/providers/theme_mode_provider.dart` doesn't exist.

- [ ] **Step 4: Create `lib/providers/theme_mode_provider.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null) {
      state = ThemeMode.values.byName(stored);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
```

- [ ] **Step 5: Run the test again**

```bash
flutter test test/providers/theme_mode_provider_test.dart
```

Expected: PASS — all 3 tests.

- [ ] **Step 6: Add `pawfolioDarkTheme` to `lib/theme.dart`**

Append to the end of `lib/theme.dart` (after the existing `pawfolioTheme`, don't modify `AppColors` or `pawfolioTheme`):

```dart
/// Dark-mode tokens — lighter/desaturated tints of the light tokens, not
/// inversions. Contrast ratios computed in the design spec
/// (docs/superpowers/specs/2026-08-18-pawfolio-visual-design-v2-design.md);
/// every text/icon pairing clears WCAG AA with margin.
class AppColorsDark {
  const AppColorsDark._();

  static const background = Color(0xFF16100F);
  static const surface = Color(0xFF221A18);
  static const primary = Color(0xFFE2836A);
  static const onPrimary = Color(0xFF3A140A);
  static const accentPositive = Color(0xFF6FCDA0);
  static const warningDueSoon = Color(0xFFE3A548);
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF4A0E08);
  static const ink = Color(0xFFF2E9E6);
  static const muted = Color(0xFFB9ACA6);
  static const border = Color(0xFF3A2E2B);
}

final pawfolioDarkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColorsDark.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColorsDark.primary,
    brightness: Brightness.dark,
    primary: AppColorsDark.primary,
    onPrimary: AppColorsDark.onPrimary,
    surface: AppColorsDark.surface,
    error: AppColorsDark.error,
    onError: AppColorsDark.onError,
  ),
  textTheme: GoogleFonts.manropeTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
  cardColor: AppColorsDark.surface,
  dividerColor: AppColorsDark.border,
);
```

- [ ] **Step 7: Wire both themes and theme mode into `lib/main.dart`**

Add the import alongside the existing ones:

```dart
import 'providers/theme_mode_provider.dart';
```

Change `PawfolioApp.build` from:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Pawfolio',
      theme: pawfolioTheme,
      routerConfig: router,
    );
  }
```

to:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Pawfolio',
      theme: pawfolioTheme,
      darkTheme: pawfolioDarkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
```

- [ ] **Step 8: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task1_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task1_test_output.txt
git add -A
git commit -m "feat: add dark theme and persisted theme-mode preference"
```

Expected: `flutter analyze` clean, `flutter test` exits 0.

---

## Task 2: Shared `PetAvatar` widget

**Files:**
- Create: `lib/widgets/pet_avatar.dart`, `test/widgets/pet_avatar_test.dart`

**Interfaces:**
- Produces: `PetAvatar({required String species, double radius = 20})`, a `StatelessWidget`. Task 5 uses it on Home's pet cards and the pet-detail app bar.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/pet_avatar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/theme.dart';
import 'package:pawfolio/widgets/pet_avatar.dart';

void main() {
  testWidgets('dog gets the primary-colored disc', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PetAvatar(species: 'dog')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.primary);
  });

  testWidgets('cat gets the accentPositive-colored disc', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PetAvatar(species: 'cat')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.accentPositive);
  });

  testWidgets('any other species gets the muted-colored disc', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PetAvatar(species: 'other')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.muted);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/widgets/pet_avatar_test.dart
```

Expected: FAIL — `lib/widgets/pet_avatar.dart` doesn't exist.

- [ ] **Step 3: Create `lib/widgets/pet_avatar.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({required this.species, this.radius = 20, super.key});

  final String species;
  final double radius;

  static const _backgroundBySpecies = {
    'dog': AppColors.primary,
    'cat': AppColors.accentPositive,
  };

  @override
  Widget build(BuildContext context) {
    final background = _backgroundBySpecies[species] ?? AppColors.muted;
    final onBackground = background == AppColors.muted ? AppColors.background : Colors.white;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Icon(Icons.pets, color: onBackground, size: radius),
    );
  }
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/widgets/pet_avatar_test.dart
```

Expected: PASS — all 3 tests.

- [ ] **Step 5: Commit**

```bash
cd /home/missia03/Projects/pawfolio
git add lib/widgets/pet_avatar.dart test/widgets/pet_avatar_test.dart
git commit -m "feat: add PetAvatar widget for species-colored discs"
```

---

## Task 3: Shared `EmptyState` widget

**Files:**
- Create: `lib/widgets/empty_state.dart`, `test/widgets/empty_state_test.dart`

**Interfaces:**
- Produces: `EmptyState({required Widget illustration, required String title, String? subtitle})`, a `StatelessWidget`. Tasks 4, 5, 6, and 7 use it for every empty-list state.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/empty_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/widgets/empty_state.dart';

void main() {
  testWidgets('renders the illustration, title, and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyState(
          illustration: Icon(Icons.pets),
          title: 'Aucun animal pour le moment',
          subtitle: 'Ajoute ton premier animal avec le bouton + ci-dessous.',
        ),
      ),
    );

    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.text('Aucun animal pour le moment'), findsOneWidget);
    expect(find.text('Ajoute ton premier animal avec le bouton + ci-dessous.'), findsOneWidget);
  });

  testWidgets('renders with no subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyState(illustration: Icon(Icons.pets), title: 'Titre seul'),
      ),
    );

    expect(find.text('Titre seul'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/widgets/empty_state_test.dart
```

Expected: FAIL — `lib/widgets/empty_state.dart` doesn't exist.

- [ ] **Step 3: Create `lib/widgets/empty_state.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({required this.illustration, required this.title, this.subtitle, super.key});

  final Widget illustration;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 96, width: 96, child: illustration),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/widgets/empty_state_test.dart
```

Expected: PASS — both tests.

- [ ] **Step 5: Commit**

```bash
cd /home/missia03/Projects/pawfolio
git add lib/widgets/empty_state.dart test/widgets/empty_state_test.dart
git commit -m "feat: add EmptyState widget for illustrated empty lists"
```

---

## Task 4: Bottom navigation — Reminders & Profile screens, shell wiring

**Files:**
- Create: `lib/app_shell.dart`, `lib/screens/reminders/reminders_screen.dart`, `lib/screens/profile/profile_screen.dart`, `test/app_shell_test.dart`, `test/screens/reminders_screen_test.dart`, `test/screens/profile_screen_test.dart`
- Modify: `lib/reminders.dart`, `test/reminders_test.dart`, `lib/app_router.dart`

**Interfaces:**
- Consumes: `EmptyState` (Task 3), `themeModeProvider` (Task 1), `upcomingRemindersProvider`/`DueItem`/`ReminderUrgency`/`reminderUrgency` (pre-existing, `lib/reminders.dart` and `lib/providers/reminders_provider.dart`).
- Produces: `urgencyColor(ReminderUrgency urgency) -> Color` (added to `lib/reminders.dart`, replacing the private copy Task 5 removes from `home_screen.dart`); `AppShell({required StatefulNavigationShell navigationShell})`, a `StatelessWidget` (`lib/app_shell.dart`); `RemindersScreen`, `ProfileScreen` (no-argument constructors, wired into `app_router.dart`).

- [ ] **Step 1: Write the failing test for `urgencyColor`**

Append to `test/reminders_test.dart` (inside the existing `main()`, it already imports `package:pawfolio/reminders.dart` and has `final now = DateTime(2024, 6, 15);` — reuse it, don't redeclare):

```dart
  test('urgencyColor maps each urgency to its token', () {
    expect(urgencyColor(ReminderUrgency.today), AppColors.error);
    expect(urgencyColor(ReminderUrgency.soon), AppColors.warningDueSoon);
    expect(urgencyColor(ReminderUrgency.later), AppColors.muted);
  });
```

Add the import this new test needs at the top of the file:

```dart
import 'package:pawfolio/theme.dart';
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/reminders_test.dart
```

Expected: FAIL — `urgencyColor` doesn't exist yet.

- [ ] **Step 3: Add `urgencyColor` to `lib/reminders.dart`**

Add these two imports at the top of `lib/reminders.dart` (it currently has none):

```dart
import 'package:flutter/material.dart';

import 'theme.dart';
```

Append to the end of the file (after the existing `reminderUrgency` function):

```dart
Color urgencyColor(ReminderUrgency urgency) {
  switch (urgency) {
    case ReminderUrgency.today:
      return AppColors.error;
    case ReminderUrgency.soon:
      return AppColors.warningDueSoon;
    case ReminderUrgency.later:
      return AppColors.muted;
  }
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/reminders_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/missia03/Projects/pawfolio
git add lib/reminders.dart test/reminders_test.dart
git commit -m "feat: add urgencyColor to lib/reminders.dart"
```

- [ ] **Step 6: Write the failing `RemindersScreen` test**

Create `test/screens/reminders_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/screens/reminders/reminders_screen.dart';

void main() {
  testWidgets('groups reminders into Aujourd\'hui / Cette semaine / Plus tard', (tester) async {
    final now = DateTime.now();
    final items = [
      DueItem(petId: 'p1', petName: 'Rex', label: 'Vaccin', dueDate: now),
      DueItem(petId: 'p2', petName: 'Mia', label: 'Poids', dueDate: now.add(const Duration(days: 3))),
      DueItem(petId: 'p1', petName: 'Rex', label: 'RDV', dueDate: now.add(const Duration(days: 30))),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [upcomingRemindersProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    expect(find.text('Rex · Vaccin'), findsOneWidget);
    expect(find.text('Mia · Poids'), findsOneWidget);
    expect(find.text('Rex · RDV'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no reminders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [upcomingRemindersProvider.overrideWith((ref) async => <DueItem>[])],
        child: const MaterialApp(home: RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun rappel à venir'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run it to confirm it fails**

```bash
flutter test test/screens/reminders_screen_test.dart
```

Expected: FAIL — `lib/screens/reminders/reminders_screen.dart` doesn't exist.

- [ ] **Step 8: Create `lib/screens/reminders/reminders_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../date_only.dart';
import '../../providers/reminders_provider.dart';
import '../../reminders.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rappels')),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(upcomingRemindersProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                illustration: Icon(Icons.notifications_none, size: 64, color: AppColors.muted),
                title: 'Aucun rappel à venir',
                subtitle: 'Les vaccins, traitements et visites à venir apparaîtront ici.',
              )
            : ListView(children: _sections(items).expand((s) => s).toList()),
      ),
    );
  }
}

List<List<Widget>> _sections(List<DueItem> items) {
  final byUrgency = <ReminderUrgency, List<DueItem>>{
    ReminderUrgency.today: [],
    ReminderUrgency.soon: [],
    ReminderUrgency.later: [],
  };
  for (final item in items) {
    byUrgency[reminderUrgency(item.dueDate)]!.add(item);
  }

  const labels = {
    ReminderUrgency.today: "Aujourd'hui",
    ReminderUrgency.soon: 'Cette semaine',
    ReminderUrgency.later: 'Plus tard',
  };

  return [
    for (final urgency in ReminderUrgency.values)
      if (byUrgency[urgency]!.isNotEmpty)
        [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(labels[urgency]!, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final item in byUrgency[urgency]!)
            ListTile(
              leading: Icon(Icons.circle, size: 12, color: urgencyColor(urgency)),
              title: Text('${item.petName} · ${item.label}'),
              subtitle: Text(dateOnly(item.dueDate)),
            ),
        ],
  ];
}
```

- [ ] **Step 9: Run the test again**

```bash
flutter test test/screens/reminders_screen_test.dart
```

Expected: PASS — both tests.

- [ ] **Step 10: Commit**

```bash
cd /home/missia03/Projects/pawfolio
git add lib/screens/reminders/reminders_screen.dart test/screens/reminders_screen_test.dart
git commit -m "feat: add Rappels screen with urgency-grouped reminders"
```

- [ ] **Step 11: Write the failing `ProfileScreen` test**

Create `test/screens/profile_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/providers/theme_mode_provider.dart';
import 'package:pawfolio/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('selecting Sombre updates themeModeProvider', (tester) async {
    late ProviderContainer container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(),
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
```

- [ ] **Step 12: Run it to confirm it fails**

```bash
flutter test test/screens/profile_screen_test.dart
```

Expected: FAIL — `lib/screens/profile/profile_screen.dart` doesn't exist.

- [ ] **Step 13: Create `lib/screens/profile/profile_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/theme_mode_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.email), title: Text(email)),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Thème', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Système'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Clair'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Sombre'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 14: Run the test again**

```bash
flutter test test/screens/profile_screen_test.dart
```

Expected: PASS.

- [ ] **Step 15: Commit**

```bash
cd /home/missia03/Projects/pawfolio
git add lib/screens/profile/profile_screen.dart test/screens/profile_screen_test.dart
git commit -m "feat: add Profil screen with theme-mode selector and sign-out"
```

- [ ] **Step 16: Write the failing `AppShell` test**

Create `test/app_shell_test.dart`. This builds a standalone `GoRouter` with the same `StatefulShellRoute` shape production code will use, but with placeholder leaf screens — it tests the shell's navigation mechanics in isolation from Supabase auth (which the real `appRouterProvider` requires and which `test/app_smoke_test.dart` already covers separately):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawfolio/app_shell.dart';

void main() {
  GoRouter buildTestRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [GoRoute(path: '/', builder: (context, state) => const Text('Home body'))],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/reminders', builder: (context, state) => const Text('Reminders body')),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/profile', builder: (context, state) => const Text('Profile body')),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/pets/:id',
            builder: (context, state) => Text('Detail: ${state.pathParameters['id']}'),
          ),
        ],
      );

  testWidgets('switches branches when tapping nav destinations', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildTestRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Home body'), findsOneWidget);

    await tester.tap(find.text('Rappels'));
    await tester.pumpAndSettle();
    expect(find.text('Reminders body'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profile body'), findsOneWidget);
  });

  testWidgets('pushing a pet detail route covers the bottom nav', (tester) async {
    final router = buildTestRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/pets/1');
    await tester.pumpAndSettle();

    expect(find.text('Detail: 1'), findsOneWidget);
    expect(find.text('Rappels'), findsNothing);
  });
}
```

- [ ] **Step 17: Run it to confirm it fails**

```bash
flutter test test/app_shell_test.dart
```

Expected: FAIL — `lib/app_shell.dart` doesn't exist.

- [ ] **Step 18: Create `lib/app_shell.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets), label: 'Mes animaux'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Rappels'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 19: Run the test again**

```bash
flutter test test/app_shell_test.dart
```

Expected: PASS — both tests.

- [ ] **Step 20: Wire the shell into `lib/app_router.dart`**

Replace `lib/app_router.dart` in full:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'auth_redirect.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/pet_detail/pet_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reminders/reminders_screen.dart';

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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(
            routes: [GoRoute(path: '/reminders', builder: (context, state) => const RemindersScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/pets/:id',
        builder: (context, state) => PetDetailScreen(petId: state.pathParameters['id']!),
      ),
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

- [ ] **Step 21: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task4_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task4_test_output.txt
git add -A
git commit -m "feat: wire bottom-navigation shell into app_router"
```

Expected: `flutter analyze` clean; `flutter test` exits 0 — `test/app_smoke_test.dart` (checks the login screen with no session) is unaffected since redirect-to-login happens before the shell is ever reached.

---

## Task 5: Home screen & pet-detail header redesign

**Files:**
- Modify: `lib/screens/home/home_screen.dart`, `test/screens/home_screen_test.dart`, `lib/screens/pet_detail/pet_detail_screen.dart`, `test/screens/pet_detail_screen_test.dart`

**Interfaces:**
- Consumes: `PetAvatar` (Task 2), `EmptyState` (Task 3), `urgencyColor`/`reminderUrgency`/`DueItem` (Task 4 / pre-existing `lib/reminders.dart`).
- Produces: no new interfaces — `HomeScreen`/`PetDetailScreen` keep their existing constructors.

- [ ] **Step 1: Update `test/screens/home_screen_test.dart`**

Replace the file in full — the two existing assertions stay, with two new ones added (`PetAvatar` on populated rows, `EmptyState` on the empty case) and a third test for the reminder badge. The third test overrides `upcomingRemindersProvider` with a real (non-error) value, which means `HomeScreen`'s `ref.listen(upcomingRemindersProvider, ...)` will call `reminderSchedulerProvider.scheduleAll(...)` — exactly like `test/screens/home_screen_edit_test.dart` already handles, so this file needs the same local-notifications channel mock:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/pet.dart';
import 'package:pawfolio/providers/pets_provider.dart';
import 'package:pawfolio/providers/reminders_provider.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/screens/home/home_screen.dart';
import 'package:pawfolio/widgets/empty_state.dart';
import 'package:pawfolio/widgets/pet_avatar.dart';

const _localNotificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, null);
  });

  testWidgets('shows pets returned by petsProvider with an avatar each', (tester) async {
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
    expect(find.byType(PetAvatar), findsNWidgets(2));
  });

  testWidgets('shows an illustrated empty state when there are no pets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petsProvider.overrideWith((ref) async => <Pet>[])],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun animal pour le moment'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('shows the soonest reminder as a badge on the matching pet card', (tester) async {
    final pets = [const Pet(id: '1', ownerId: 'u1', name: 'Rex', species: 'dog')];
    final reminders = [
      DueItem(petId: '1', petName: 'Rex', label: 'Vaccin', dueDate: DateTime.now()),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petsProvider.overrideWith((ref) async => pets),
          upcomingRemindersProvider.overrideWith((ref) async => reminders),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaccin'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/screens/home_screen_test.dart
```

Expected: FAIL — `PetAvatar`/`EmptyState` aren't used in `HomeScreen` yet, and there's no per-pet reminder badge.

- [ ] **Step 3: Rewrite `lib/screens/home/home_screen.dart`**

Replace the file in full:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../date_only.dart';
import '../../models/pet.dart';
import '../../notifications/reminder_scheduler.dart';
import '../../providers/pets_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../reminders.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pet_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(upcomingRemindersProvider, (previous, next) {
      next.whenData((items) => ref.read(reminderSchedulerProvider).scheduleAll(items));
    });
    final upcomingAsync = ref.watch(upcomingRemindersProvider);
    final petsAsync = ref.watch(petsProvider);

    final earliestReminderByPet = <String, DueItem>{};
    upcomingAsync.whenData((items) {
      for (final item in items) {
        earliestReminderByPet.putIfAbsent(item.petId, () => item);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [Icon(Icons.pets), SizedBox(width: 8), Text('Pawfolio')],
        ),
      ),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('À venir', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextButton(
                                  onPressed: () => context.push('/reminders'),
                                  child: const Text('Voir tout'),
                                ),
                              ],
                            ),
                          ),
                          for (final item in items.take(3))
                            ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.circle,
                                size: 12,
                                color: urgencyColor(reminderUrgency(item.dueDate)),
                              ),
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
                  ? const EmptyState(
                      illustration: Icon(Icons.pets, size: 64, color: AppColors.muted),
                      title: 'Aucun animal pour le moment',
                      subtitle: 'Ajoute ton premier animal avec le bouton + ci-dessous.',
                    )
                  : Column(
                      children: [
                        for (final pet in pets)
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: PetAvatar(species: pet.species),
                              title: Text(pet.name),
                              subtitle: Text(pet.species),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (earliestReminderByPet[pet.id] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Chip(
                                        label: Text(earliestReminderByPet[pet.id]!.label),
                                        backgroundColor: urgencyColor(
                                          reminderUrgency(earliestReminderByPet[pet.id]!.dueDate),
                                        ),
                                        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showAddPetSheet(context, ref, existing: pet),
                                  ),
                                ],
                              ),
                              onTap: () => context.push('/pets/${pet.id}'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPetSheet(BuildContext context, WidgetRef ref, {Pet? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String species = existing?.species ?? 'dog';
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
                    if (existing == null) {
                      await ref.read(petsRepositoryProvider).create(
                            Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                          );
                    } else {
                      await ref.read(petsRepositoryProvider).update(
                            Pet(
                              id: existing.id,
                              ownerId: existing.ownerId,
                              name: nameController.text.trim(),
                              species: species,
                              breed: existing.breed,
                              birthDate: existing.birthDate,
                            ),
                          );
                    }
                    ref.invalidate(petsProvider);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Notes on this rewrite versus the current file: the AppBar's logout `IconButton` is gone (moved to `ProfileScreen`, Task 4); the private `Color _urgencyColor(...)` at the bottom of the old file is gone, replaced by the shared `urgencyColor` import (Task 4); the "À venir" header row now has a "Voir tout" button that pushes `/reminders`; each pet row is a `Card` wrapping the same `ListTile` shape (same `onTap`, same edit `IconButton`) plus a leading `PetAvatar` and a trailing urgency-colored `Chip` when that pet has an upcoming reminder.

- [ ] **Step 4: Run the test again**

```bash
flutter test test/screens/home_screen_test.dart
```

Expected: PASS — all 3 tests.

- [ ] **Step 5: Update `test/screens/pet_detail_screen_test.dart`**

Append one assertion and one import to the existing test (don't remove the existing one):

```dart
import 'package:pawfolio/widgets/pet_avatar.dart';
```

Add after the existing `expect(find.text('Labrador'), findsOneWidget);` line:

```dart
    expect(find.byType(PetAvatar), findsOneWidget);
```

- [ ] **Step 6: Run it to confirm it fails**

```bash
flutter test test/screens/pet_detail_screen_test.dart
```

Expected: FAIL — `PetDetailScreen`'s app bar doesn't have a `PetAvatar` yet.

- [ ] **Step 7: Update `lib/screens/pet_detail/pet_detail_screen.dart`**

Add the import:

```dart
import '../../widgets/pet_avatar.dart';
```

Change the `AppBar` from:

```dart
        appBar: AppBar(
          title: Text(pet?.name ?? 'Animal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vaccins'),
              Tab(text: 'Poids'),
              Tab(text: 'Traitements'),
              Tab(text: 'RDV'),
            ],
          ),
        ),
```

to:

```dart
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pet != null) ...[
                PetAvatar(species: pet.species, radius: 16),
                const SizedBox(width: 8),
              ],
              Text(pet?.name ?? 'Animal'),
            ],
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Vaccins'),
              Tab(text: 'Poids'),
              Tab(text: 'Traitements'),
              Tab(text: 'RDV'),
            ],
          ),
        ),
```

Add the `theme.dart` import alongside the others (needed for `AppColors.primary`):

```dart
import '../../theme.dart';
```

- [ ] **Step 8: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task5_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task5_test_output.txt
git add -A
git commit -m "feat: redesign Home pet cards and pet-detail header"
```

Expected: `flutter analyze` clean; `flutter test` exits 0 — `test/screens/home_screen_edit_test.dart` and `test/e2e/add_pet_and_vaccination_test.dart` still pass unchanged (they find `Icons.edit`/`Icons.add` and pet-name text, none of which moved).

---

## Task 6: Weight tab — trend chart & illustrated empty state

**Files:**
- Modify: `pubspec.yaml`, `lib/screens/pet_detail/widgets/weight_tab.dart`, `test/screens/weight_tab_test.dart`

**Interfaces:**
- Consumes: `EmptyState` (Task 3).
- Produces: no new interfaces — `WeightTab` keeps its existing `{required String petId}` constructor.

- [ ] **Step 1: Add the `fl_chart` dependency**

```bash
cd /home/missia03/Projects/pawfolio
flutter pub add fl_chart
```

- [ ] **Step 2: Update `test/screens/weight_tab_test.dart`**

Replace the file in full:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/weight_entry.dart';
import 'package:pawfolio/providers/weight_entries_provider.dart';
import 'package:pawfolio/screens/pet_detail/widgets/weight_tab.dart';
import 'package:pawfolio/widgets/empty_state.dart';

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

  testWidgets('hides the chart with a single entry', (tester) async {
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

    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('shows the chart with two or more entries', (tester) async {
    final entries = [
      WeightEntry(id: 'w1', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 3, 1)),
      WeightEntry(id: 'w2', petId: 'p1', weightKg: 13.0, recordedAt: DateTime(2024, 4, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [weightEntriesProvider('p1').overrideWith((ref) async => entries)],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('shows an illustrated empty state when there are no entries', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [weightEntriesProvider('p1').overrideWith((ref) async => <WeightEntry>[])],
        child: const MaterialApp(home: WeightTab(petId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune pesée enregistrée'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it to confirm it fails**

```bash
flutter test test/screens/weight_tab_test.dart
```

Expected: FAIL — no chart, no `EmptyState`, yet.

- [ ] **Step 4: Update `lib/screens/pet_detail/widgets/weight_tab.dart`**

Add these imports alongside the existing ones:

```dart
import 'package:fl_chart/fl_chart.dart';

import '../../../theme.dart';
import '../../../widgets/empty_state.dart';
```

Change the `data:` branch of `entriesAsync.when` from:

```dart
        data: (entries) => entries.isEmpty
            ? const Center(child: Text('Aucune pesée enregistrée'))
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text('${entry.weightKg} kg'),
                    subtitle: Text(dateOnly(entry.recordedAt)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddWeightSheet(context, ref, existing: entry),
                    ),
                  );
                },
              ),
```

to:

```dart
        data: (entries) => entries.isEmpty
            ? const EmptyState(
                illustration: Icon(Icons.monitor_weight, size: 64, color: AppColors.muted),
                title: 'Aucune pesée enregistrée',
                subtitle: 'Ajoute la première pesée avec le bouton + ci-dessous.',
              )
            : Column(
                children: [
                  if (entries.length >= 2) _WeightChart(entries: entries),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text('${entry.weightKg} kg'),
                          subtitle: Text(dateOnly(entry.recordedAt)),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddWeightSheet(context, ref, existing: entry),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
```

Add this widget at the end of the file, after the `WeightTab` class (the tab's `fetchForPet` orders entries newest-first for the list — reverse to chronological order for the chart, which reads left-to-right as oldest-to-newest):

```dart
class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final chronological = entries.reversed.toList();
    // num.clamp returns num, not double — SideTitles.interval needs an explicit toDouble().
    final labelInterval = (chronological.length / 4).ceil().clamp(1, chronological.length).toDouble();

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: labelInterval,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= chronological.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dateOnly(chronological[index].recordedAt),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < chronological.length; i++)
                    FlSpot(i.toDouble(), chronological[i].weightKg),
                ],
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                dotData: const FlDotData(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test again**

```bash
flutter test test/screens/weight_tab_test.dart
```

Expected: PASS — all 4 tests.

- [ ] **Step 6: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task6_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task6_test_output.txt
git add -A
git commit -m "feat: add weight trend chart and illustrated empty state to Poids tab"
```

---

## Task 7: Illustrated empty states in Vaccins, Traitements, and RDV tabs

**Files:**
- Modify: `lib/screens/pet_detail/widgets/vaccinations_tab.dart`, `lib/screens/pet_detail/widgets/treatments_tab.dart`, `lib/screens/pet_detail/widgets/vet_visits_tab.dart`, `test/screens/vaccinations_tab_test.dart`, `test/screens/treatments_tab_test.dart`, `test/screens/vet_visits_tab_test.dart`

**Interfaces:**
- Consumes: `EmptyState` (Task 3).
- Produces: none — all three tabs keep their existing `{required String petId}` constructors.

- [ ] **Step 1: Append one assertion to each of the three existing test files**

In `test/screens/vaccinations_tab_test.dart`, add the import `import 'package:pawfolio/widgets/empty_state.dart';` and, right after `expect(find.text('Aucun vaccin enregistré'), findsOneWidget);`, add:

```dart
    expect(find.byType(EmptyState), findsOneWidget);
```

Do the same in `test/screens/treatments_tab_test.dart` (after `'Aucun traitement enregistré'`) and `test/screens/vet_visits_tab_test.dart` (after `'Aucun rendez-vous enregistré'`), each with the same `EmptyState` import.

- [ ] **Step 2: Run all three to confirm they fail**

```bash
flutter test test/screens/vaccinations_tab_test.dart test/screens/treatments_tab_test.dart test/screens/vet_visits_tab_test.dart
```

Expected: FAIL — none of the three tabs render an `EmptyState` yet.

- [ ] **Step 3: Update `lib/screens/pet_detail/widgets/vaccinations_tab.dart`**

Add these imports:

```dart
import '../../../theme.dart';
import '../../../widgets/empty_state.dart';
```

Change:

```dart
        data: (vaccinations) => vaccinations.isEmpty
            ? const Center(child: Text('Aucun vaccin enregistré'))
```

to:

```dart
        data: (vaccinations) => vaccinations.isEmpty
            ? const EmptyState(
                illustration: Icon(Icons.vaccines, size: 64, color: AppColors.muted),
                title: 'Aucun vaccin enregistré',
                subtitle: 'Ajoute le premier vaccin avec le bouton + ci-dessous.',
              )
```

- [ ] **Step 4: Update `lib/screens/pet_detail/widgets/treatments_tab.dart`**

Add the same two imports, then change:

```dart
        data: (treatments) => treatments.isEmpty
            ? const Center(child: Text('Aucun traitement enregistré'))
```

to:

```dart
        data: (treatments) => treatments.isEmpty
            ? const EmptyState(
                illustration: Icon(Icons.medication, size: 64, color: AppColors.muted),
                title: 'Aucun traitement enregistré',
                subtitle: 'Ajoute le premier traitement avec le bouton + ci-dessous.',
              )
```

- [ ] **Step 5: Update `lib/screens/pet_detail/widgets/vet_visits_tab.dart`**

Add the same two imports, then change:

```dart
        data: (visits) => visits.isEmpty
            ? const Center(child: Text('Aucun rendez-vous enregistré'))
```

to:

```dart
        data: (visits) => visits.isEmpty
            ? const EmptyState(
                illustration: Icon(Icons.local_hospital, size: 64, color: AppColors.muted),
                title: 'Aucun rendez-vous enregistré',
                subtitle: 'Ajoute le premier rendez-vous avec le bouton + ci-dessous.',
              )
```

- [ ] **Step 6: Run all three tests again**

```bash
flutter test test/screens/vaccinations_tab_test.dart test/screens/treatments_tab_test.dart test/screens/vet_visits_tab_test.dart
```

Expected: PASS — all 6 tests (2 per file).

- [ ] **Step 7: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task7_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task7_test_output.txt
git add -A
git commit -m "feat: use illustrated EmptyState in Vaccins, Traitements, and RDV tabs"
```

---

## Task 8: Illustration assets

**Files:**
- Modify: `pubspec.yaml`, `lib/screens/home/home_screen.dart`, `lib/screens/reminders/reminders_screen.dart`, `lib/screens/pet_detail/widgets/weight_tab.dart`, `lib/screens/pet_detail/widgets/vaccinations_tab.dart`, `lib/screens/pet_detail/widgets/treatments_tab.dart`, `lib/screens/pet_detail/widgets/vet_visits_tab.dart`
- Create: `assets/illustrations/no_pets.svg`, `assets/illustrations/no_reminders.svg`, `assets/illustrations/no_weight_entries.svg`, `assets/illustrations/no_vaccinations.svg`, `assets/illustrations/no_treatments.svg`, `assets/illustrations/no_vet_visits.svg`

**Interfaces:**
- Consumes: `EmptyState`'s `illustration` parameter (Task 3) — this task only swaps what's passed to it at each of the 6 call sites, no widget changes.

- [ ] **Step 1: Request download confirmation before fetching anything**

This step downloads six external SVG files. Per this session's operating rules, that requires explicit user confirmation first — do not skip this or fetch silently. Search https://undraw.co/search for each of these six terms, pick one result per term, and note its direct SVG download URL and approximate file size (unDraw SVGs are typically 5–30 KB):

| Target file | Search term |
|---|---|
| `assets/illustrations/no_pets.svg` | "pet" or "dog" |
| `assets/illustrations/no_reminders.svg` | "reminder" or "calendar" |
| `assets/illustrations/no_weight_entries.svg` | "progress" or "scale" |
| `assets/illustrations/no_vaccinations.svg` | "vaccine" |
| `assets/illustrations/no_treatments.svg` | "medicine" or "pills" |
| `assets/illustrations/no_vet_visits.svg` | "doctors" or "medical care" |

Then ask the user, verbatim or close to it: *"I'm about to download 6 SVG illustrations from unDraw (CC0, no attribution required) — [list the 6 chosen URLs and their sizes] — and save them to `assets/illustrations/`. Confirm?"* Wait for an explicit yes before Step 2.

**Fallback if the user declines, or this environment has no working internet/browser access:** skip straight to Step 4 using `Icon`s in place of `SvgPicture`s — the six call sites already pass an `Icon` today (Tasks 5, 6, and 7); leave every one of them exactly as it is and stop this task here. Illustrations are a visual enhancement, not a functional requirement — there's nothing broken by keeping the icon-based empty states.

- [ ] **Step 2: Download the confirmed files**

```bash
cd /home/missia03/Projects/pawfolio
mkdir -p assets/illustrations
curl -L '<confirmed URL 1>' -o assets/illustrations/no_pets.svg
curl -L '<confirmed URL 2>' -o assets/illustrations/no_reminders.svg
curl -L '<confirmed URL 3>' -o assets/illustrations/no_weight_entries.svg
curl -L '<confirmed URL 4>' -o assets/illustrations/no_vaccinations.svg
curl -L '<confirmed URL 5>' -o assets/illustrations/no_treatments.svg
curl -L '<confirmed URL 6>' -o assets/illustrations/no_vet_visits.svg
```

Verify each file is a real SVG, not an HTML error page:

```bash
for f in assets/illustrations/*.svg; do head -c 80 "$f"; echo " -- $f"; done
```

Expected: each starts with `<?xml` or `<svg`.

- [ ] **Step 3: Add the `flutter_svg` dependency and declare the assets**

```bash
flutter pub add flutter_svg
```

In `pubspec.yaml`, under the `flutter:` section, add:

```yaml
  assets:
    - assets/illustrations/
```

- [ ] **Step 4: Swap each `Icon` illustration for `SvgPicture.asset`**

In each of the six files below, add the import:

```dart
import 'package:flutter_svg/flutter_svg.dart';
```

Then replace the `illustration:` argument. In `lib/screens/home/home_screen.dart`:

```dart
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_pets.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
```

In `lib/screens/reminders/reminders_screen.dart`:

```dart
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_reminders.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
```

In `lib/screens/pet_detail/widgets/weight_tab.dart`:

```dart
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_weight_entries.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
```

In `lib/screens/pet_detail/widgets/vaccinations_tab.dart`:

```dart
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_vaccinations.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
```

In `lib/screens/pet_detail/widgets/treatments_tab.dart`:

```dart
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_treatments.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
```

In `lib/screens/pet_detail/widgets/vet_visits_tab.dart`:

```dart
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_vet_visits.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
```

Each replaces that file's existing `Icon(Icons.*, size: 64, color: AppColors.muted)` illustration argument one-for-one — every existing widget test that checks `find.byType(EmptyState)` or the title/subtitle text keeps passing, since `EmptyState`'s API and text are unchanged.

- [ ] **Step 5: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task8_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task8_test_output.txt
git add -A
git commit -m "feat: use unDraw SVG illustrations in all empty states"
```

If Step 1's fallback was taken (no download), skip this commit — nothing changed.

---

## Task 9: Lottie success moments

**Files:**
- Modify: `pubspec.yaml`, `lib/screens/home/home_screen.dart`, `lib/screens/pet_detail/widgets/weight_tab.dart`
- Create: `assets/lottie/pet_added.json`, `assets/lottie/entry_saved.json`

**Interfaces:**
- Consumes: none new.
- Produces: none — this is a purely additive visual moment inside each sheet's existing success path.

- [ ] **Step 1: Request download confirmation before fetching anything**

This step downloads two Lottie JSON files. Per this session's operating rules, that requires explicit user confirmation first. Search https://lottiefiles.com/free-animations for "confetti celebration" (for `pet_added.json`, played once when a user adds their very first pet) and "success checkmark" (for `entry_saved.json`, played when a weight entry is saved) among the free/CC-licensed results, and note each chosen file's direct JSON download URL and approximate size (typically 5–50 KB).

Ask the user, verbatim or close to it: *"I'm about to download 2 free Lottie animations from LottieFiles — [list the 2 chosen URLs, licenses, and sizes] — and save them to `assets/lottie/`. Confirm?"* Wait for an explicit yes before Step 2.

**Fallback if the user declines, or this environment has no working internet/browser access:** stop this task here — the app already gives feedback on these two actions today (the bottom sheet closes, `pumpAndSettle` shows the new item in the list), so there's nothing broken by skipping this task.

- [ ] **Step 2: Download the confirmed files**

```bash
cd /home/missia03/Projects/pawfolio
mkdir -p assets/lottie
curl -L '<confirmed URL 1>' -o assets/lottie/pet_added.json
curl -L '<confirmed URL 2>' -o assets/lottie/entry_saved.json
```

Verify both are JSON, not HTML:

```bash
for f in assets/lottie/*.json; do head -c 40 "$f"; echo " -- $f"; done
```

Expected: each starts with `{`.

- [ ] **Step 3: Add the `lottie` dependency and declare the assets**

```bash
flutter pub add lottie
```

In `pubspec.yaml`, under `flutter: assets:` (added in Task 8 Step 3), add a second entry:

```yaml
  assets:
    - assets/illustrations/
    - assets/lottie/
```

- [ ] **Step 4: Play `pet_added.json` when the user adds their very first pet**

In `lib/screens/home/home_screen.dart`, add the import:

```dart
import 'package:lottie/lottie.dart';
```

`HomeScreen` stays exactly the `ConsumerWidget` Task 5 left it — no state tracking needed. Instead, gate the celebration the same way Step 5 below gates the weight-entry one: check the condition right before the create call, and play the animation right after it succeeds. In `_showAddPetSheet`'s `FilledButton`, change the `onPressed` from:

```dart
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    if (existing == null) {
                      await ref.read(petsRepositoryProvider).create(
                            Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                          );
                    } else {
                      await ref.read(petsRepositoryProvider).update(
                            Pet(
                              id: existing.id,
                              ownerId: existing.ownerId,
                              name: nameController.text.trim(),
                              species: species,
                              breed: existing.breed,
                              birthDate: existing.birthDate,
                            ),
                          );
                    }
                    ref.invalidate(petsProvider);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
```

to:

```dart
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  final wasEmpty =
                      existing == null && (ref.read(petsProvider).valueOrNull?.isEmpty ?? false);
                  try {
                    if (existing == null) {
                      await ref.read(petsRepositoryProvider).create(
                            Pet(id: '', ownerId: '', name: nameController.text.trim(), species: species),
                          );
                    } else {
                      await ref.read(petsRepositoryProvider).update(
                            Pet(
                              id: existing.id,
                              ownerId: existing.ownerId,
                              name: nameController.text.trim(),
                              species: species,
                              breed: existing.breed,
                              birthDate: existing.birthDate,
                            ),
                          );
                    }
                    ref.invalidate(petsProvider);
                    if (wasEmpty && sheetContext.mounted) {
                      showDialog(
                        context: sheetContext,
                        barrierDismissible: false,
                        barrierColor: Colors.transparent,
                        builder: (dialogContext) {
                          // Fixed timer, not gated on onLoaded/composition.duration: if the
                          // Lottie asset ever fails to parse, onLoaded never fires and the
                          // dialog would never close, hanging pumpAndSettle() in tests.
                          Future.delayed(const Duration(milliseconds: 1200), () {
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                          });
                          return IgnorePointer(
                            child: Center(
                              child: Lottie.asset('assets/lottie/pet_added.json', repeat: false, width: 160, height: 160),
                            ),
                          );
                        },
                      );
                    }
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
```

`wasEmpty` reads `false` (not `true`) if `petsProvider` hasn't resolved yet (`valueOrNull` is `null`) — a defensive default, since this animation is a nice-to-have and should never fire on uncertain state.

- [ ] **Step 5: Play `entry_saved.json` when a weight entry is added**

In `lib/screens/pet_detail/widgets/weight_tab.dart`, add the import:

```dart
import 'package:lottie/lottie.dart';
```

In `_showAddWeightSheet`'s `FilledButton.onPressed`, after the successful `ref.invalidate(weightEntriesProvider(petId));` line and before `if (sheetContext.mounted) Navigator.of(sheetContext).pop();`, insert a brief non-blocking overlay only for the "add" path (not edits — the spec reserves this for the first-save moment per entry, matching how `existing == null` is already the branch used to decide the button's own label):

```dart
                    ref.invalidate(weightEntriesProvider(petId));
                    if (existing == null && sheetContext.mounted) {
                      showDialog(
                        context: sheetContext,
                        barrierDismissible: false,
                        barrierColor: Colors.transparent,
                        builder: (dialogContext) {
                          // Fixed timer, not gated on onLoaded/composition.duration — see the
                          // matching note in Task 9 Step 4 (home_screen.dart).
                          Future.delayed(const Duration(milliseconds: 1200), () {
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                          });
                          return IgnorePointer(
                            child: Center(
                              child: Lottie.asset('assets/lottie/entry_saved.json', repeat: false, width: 120, height: 120),
                            ),
                          );
                        },
                      );
                    }
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
```

- [ ] **Step 6: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task9_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task9_test_output.txt
git add -A
git commit -m "feat: add Lottie success moments for first pet and weight entry"
```

Expected: existing tests (`test/screens/home_screen_test.dart`, `test/e2e/add_pet_and_vaccination_test.dart`, `test/screens/weight_tab_test.dart`, `test/screens/weight_edit_test.dart`) still pass — the celebration overlay only appears on the empty→non-empty transition and doesn't block or replace any existing widget those tests look for. If Step 1's fallback was taken, skip this commit.

---

## Task 10: Motion — list stagger & screen transitions

**Files:**
- Modify: `pubspec.yaml`, `lib/app_router.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/reminders/reminders_screen.dart`
- Create: `lib/motion.dart`, `test/motion_test.dart`

**Interfaces:**
- Produces: `AppMotion` (`lib/motion.dart`): `microDuration`, `transitionDuration`, `staggerStep` (all `Duration`), `entranceCurve`, `microCurve` (both `Curve`), and `durationOrInstant(BuildContext context, Duration duration) -> Duration`.

- [ ] **Step 1: Add the motion dependencies**

```bash
cd /home/missia03/Projects/pawfolio
flutter pub add flutter_animate animations
```

- [ ] **Step 2: Write the failing test for the reduced-motion guard**

Create `test/motion_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/motion.dart';

void main() {
  testWidgets('returns the given duration when animations are enabled', (tester) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: Builder(
          builder: (context) {
            result = AppMotion.durationOrInstant(context, AppMotion.microDuration);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(result, AppMotion.microDuration);
  });

  testWidgets('collapses to zero when reduced motion is enabled', (tester) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            result = AppMotion.durationOrInstant(context, AppMotion.microDuration);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(result, Duration.zero);
  });
}
```

- [ ] **Step 3: Run it to confirm it fails**

```bash
flutter test test/motion_test.dart
```

Expected: FAIL — `lib/motion.dart` doesn't exist.

- [ ] **Step 4: Create `lib/motion.dart`**

```dart
import 'package:flutter/material.dart';

class AppMotion {
  const AppMotion._();

  static const microDuration = Duration(milliseconds: 180);
  static const transitionDuration = Duration(milliseconds: 300);
  static const staggerStep = Duration(milliseconds: 40);
  static const entranceCurve = Curves.easeOutQuart;
  static const microCurve = Curves.easeOutCubic;

  static Duration durationOrInstant(BuildContext context, Duration duration) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}
```

- [ ] **Step 5: Run the test again**

```bash
flutter test test/motion_test.dart
```

Expected: PASS — both tests.

- [ ] **Step 6: Commit**

```bash
cd /home/missia03/Projects/pawfolio
git add lib/motion.dart test/motion_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: add motion tokens with a reduced-motion guard"
```

- [ ] **Step 7: Stagger the Home pet-card list**

In `lib/screens/home/home_screen.dart`, add the imports:

```dart
import 'package:flutter_animate/flutter_animate.dart';

import '../../motion.dart';
```

Wrap the existing `for (final pet in pets) Card(...)` list in an `AnimateList` — change:

```dart
                    : Column(
                        children: [
                          for (final pet in pets)
                            Card(
```

to:

```dart
                    : Column(
                        children: AnimateList(
                          interval: AppMotion.durationOrInstant(context, AppMotion.staggerStep),
                          effects: [
                            FadeEffect(
                              duration: AppMotion.durationOrInstant(context, AppMotion.microDuration),
                              curve: AppMotion.entranceCurve,
                            ),
                            SlideEffect(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                              duration: AppMotion.durationOrInstant(context, AppMotion.microDuration),
                              curve: AppMotion.entranceCurve,
                            ),
                          ],
                          children: [
                            for (final pet in pets)
                              Card(
```

Close the two extra brackets this introduces (`AnimateList(...)` and its `children:` list) at the end of that `Column`'s children — where the file currently has:

```dart
                                onTap: () => context.push('/pets/${pet.id}'),
                              ),
                            ),
                        ],
                      ),
```

change the closing to:

```dart
                                onTap: () => context.push('/pets/${pet.id}'),
                              ),
                            ),
                          ],
                        ),
                      ),
```

- [ ] **Step 8: Apply the same stagger to the Rappels list**

In `lib/screens/reminders/reminders_screen.dart`, add the same two imports. Change:

```dart
            : ListView(children: _sections(items).expand((s) => s).toList()),
```

to:

```dart
            : ListView(
                children: AnimateList(
                  interval: AppMotion.durationOrInstant(context, AppMotion.staggerStep),
                  effects: [
                    FadeEffect(
                      duration: AppMotion.durationOrInstant(context, AppMotion.microDuration),
                      curve: AppMotion.entranceCurve,
                    ),
                  ],
                  children: _sections(items).expand((s) => s).toList(),
                ),
              ),
```

- [ ] **Step 9: Run the affected widget tests to confirm the lists still render correctly**

```bash
flutter test test/screens/home_screen_test.dart test/screens/reminders_screen_test.dart
```

Expected: PASS — `pumpAndSettle` waits out the (now brief, test-environment) animation before the assertions run, so every existing text/type assertion still finds its widget.

- [ ] **Step 10: Add shared-axis transitions to `lib/app_router.dart`**

This only applies to the `/pets/:id` push — the three shell branches (Mes animaux / Rappels / Profil) switch via `StatefulShellRoute`'s `IndexedStack`, which swaps the visible child instantly with no Navigator push/pop to attach a `pageBuilder` transition to; Step 7/8's list stagger is what gives those screens their motion instead. Don't add `pageBuilder` to the branch routes — it would have no visible effect and would just be unused code.

Add the import:

```dart
import 'package:animations/animations.dart';

import 'motion.dart';
```

Change the `/pets/:id` route from a `builder:` to a `pageBuilder:`:

```dart
      GoRoute(
        path: '/pets/:id',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: PetDetailScreen(petId: state.pathParameters['id']!),
          transitionDuration: AppMotion.durationOrInstant(context, AppMotion.transitionDuration),
          reverseTransitionDuration: AppMotion.durationOrInstant(context, AppMotion.transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          ),
        ),
      ),
```

- [ ] **Step 11: Run the full suite and commit**

```bash
cd /home/missia03/Projects/pawfolio
flutter analyze
flutter test > /tmp/task10_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task10_test_output.txt
git add -A
git commit -m "feat: add list-entrance stagger and shared-axis screen transitions"
```

---

## Task 11: Manual verification on the Android emulator

**Files:**
- None (verification task; only commit if this step surfaces something that needs fixing)

**Interfaces:**
- Consumes: everything from Tasks 1-10.

- [ ] **Step 1: Boot the emulator and run the app against the real local Supabase stack**

```bash
cd /home/missia03/Projects/pawfolio
supabase status || supabase start
emulator -avd pawfolio -no-snapshot-load &
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
./scripts/run_local.sh &
sleep 60
adb shell screencap -p /sdcard/pawfolio_home.png
adb pull /sdcard/pawfolio_home.png /tmp/pawfolio_home.png
```

Log in with an account from earlier verification passes (or sign up a new one). Read `/tmp/pawfolio_home.png`. Confirm: a bottom navigation bar with 3 destinations (Mes animaux / Rappels / Profil) is visible; pet rows render as cards with a colored species avatar; a pet with an upcoming reminder shows an urgency-colored chip.

- [ ] **Step 2: Verify the Rappels and Profil tabs**

```bash
adb shell input tap <x> <y>   # Rappels destination, coordinates read from the screenshot
adb shell screencap -p /sdcard/pawfolio_reminders.png
adb pull /sdcard/pawfolio_reminders.png /tmp/pawfolio_reminders.png
```

Confirm the full reminders list groups into "Aujourd'hui" / "Cette semaine" / "Plus tard" sections (or shows the illustrated empty state if there are none). Then tap the Profil destination and screenshot again; confirm the email, the three theme options, and the sign-out row all render, and that tapping "Sombre" immediately re-themes the whole app (screenshot once more after tapping it).

- [ ] **Step 3: Verify the Poids tab chart and the illustrated empty states**

Navigate to a pet with 2+ weight entries (add a second one via the FAB if needed) and screenshot the Poids tab — confirm a line chart renders above the list. Then check a tab with zero entries (e.g. a fresh pet's Vaccins tab) — confirm the SVG illustration renders (not a broken-image icon; if Task 8's fallback was taken, confirm the `Icons.vaccines` fallback icon renders instead) alongside the title and subtitle text.

- [ ] **Step 4: Verify dark mode independently**

With the theme still set to "Sombre" from Step 2 (or select it again), re-screenshot Home, Rappels, Poids (with chart), and an empty-state tab. Confirm every screen's text is clearly readable against the dark background (no light-gray-on-dark-gray), the chip/badge colors are still visually distinct from each other, and no light-theme white surfaces leak through.

- [ ] **Step 5: Verify reduced motion**

Enable "Remove animations" in the emulator's Settings → Accessibility, restart the app, and repeat a pet-card list load and a `/pets/:id` navigation. Confirm both render instantly with no fade/slide — if any lag or animation is still visible, that's `AppMotion.durationOrInstant` not being threaded through correctly somewhere in Task 10 and needs a fix there.

- [ ] **Step 6: Fix anything found, or confirm clean**

If any of the above didn't match, fix it in the relevant file from Tasks 1-10 and re-screenshot to confirm. If everything matches, no code changes are needed.

- [ ] **Step 7: Final commit (only if Step 6 required changes)**

```bash
cd /home/missia03/Projects/pawfolio
git add -A
git commit -m "fix: address visual issues found during v2 design verification"
```

If Step 6 required no changes, skip this commit.

---
