# Pawfolio Design Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Pawfolio a cohesive, professional visual identity (currently stock Material purple defaults) and polish the signup/login flow (inline validation, password visibility, friendly errors, first branding moment).

**Architecture:** A single centralized `ThemeData` (`lib/theme.dart`) applied once via `MaterialApp.router(theme: ...)`, since every Material widget already reads `Theme.of(context)`. Auth screens and the Home screen are the only screens that need direct edits beyond the theme itself (branding, validation, and a reminder-urgency color cue respectively).

**Tech Stack:** Flutter/Dart, `google_fonts` (new dependency, for the Manrope typeface). No new architectural patterns — same Riverpod + repository conventions as the rest of the app.

## Global Constraints

- Colors (exact hex, from the design spec): `background` #FFFFFF, `surface` #FBF8F7, `primary` #A13D26, `accentPositive` #1F7052, `warningDueSoon` #8A5407, `error` #D32F2F, `ink` #1A1412, `muted` #6E625D, `border` #E8DED9.
- Typography: a single font family, Manrope, via the `google_fonts` package — no display/body font pairing (product register: one family carries the whole hierarchy).
- Icons: Flutter's built-in Material Symbols (`Icons.*`) only — no emoji, no other icon library.
- No dark mode in this pass.
- No password-confirmation field, no social sign-in — signup stays a single-screen form (YAGNI, per spec).
- No functional or data-model changes — this is a visual and signup-UX pass only; bottom-sheet forms and screen structure from the MVP plan are unchanged except where a task below explicitly touches them.
- Reminder urgency (for the Home screen's "À venir" banner): due today (0 days from now) = `error`; due within the next 7 days = `warningDueSoon`; later = `muted`. (Nothing "overdue" ever appears here — `sortUpcoming` already excludes anything before today.)

---

## Task 1: Theme foundation

**Files:**
- Create: `lib/theme.dart`
- Modify: `lib/main.dart`, `pubspec.yaml`

**Interfaces:**
- Produces: `AppColors` (a class of `static const Color` tokens: `background`, `surface`, `primary`, `accentPositive`, `warningDueSoon`, `error`, `ink`, `muted`, `border`) and `pawfolioTheme` (a top-level `final ThemeData`), both in `lib/theme.dart`. Tasks 3 and 4 import `AppColors` from here; `main.dart` applies `pawfolioTheme`.

- [ ] **Step 1: Add the `google_fonts` dependency**

```bash
cd /home/missia03/Projects/pawfolio
flutter pub add google_fonts
```

- [ ] **Step 2: Create `lib/theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic color tokens — see
/// docs/superpowers/specs/2026-08-17-pawfolio-design-polish-design.md
class AppColors {
  const AppColors._();

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFBF8F7);
  static const primary = Color(0xFFA13D26);
  static const accentPositive = Color(0xFF1F7052);
  static const warningDueSoon = Color(0xFF8A5407);
  static const error = Color(0xFFD32F2F);
  static const ink = Color(0xFF1A1412);
  static const muted = Color(0xFF6E625D);
  static const border = Color(0xFFE8DED9);
}

// ponytail: ColorScheme.fromSeed generates a full Material 3 tonal palette
// (secondary, tertiary, outline, surface variants, etc.) from one seed
// color; only the roles the design spec pins down explicitly are
// overridden below. Hand-authoring every ColorScheme field would be
// over-engineering for an MVP with no dark theme.
final pawfolioTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    error: AppColors.error,
    onError: Colors.white,
  ),
  textTheme: GoogleFonts.manropeTextTheme(),
  cardColor: AppColors.surface,
  dividerColor: AppColors.border,
);
```

- [ ] **Step 3: Apply the theme in `lib/main.dart`**

Add the import alongside the existing ones:

```dart
import 'theme.dart';
```

In `PawfolioApp.build`, add `theme: pawfolioTheme` to the `MaterialApp.router` call:

```dart
    return MaterialApp.router(
      title: 'Pawfolio',
      theme: pawfolioTheme,
      routerConfig: router,
    );
```

- [ ] **Step 4: Verify nothing broke**

```bash
flutter analyze
flutter test > /tmp/task1_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task1_test_output.txt
```

Expected: `flutter analyze` shows no new issues beyond any pre-existing ones; `flutter test` exits 0, "All tests passed!" — applying a theme changes colors/fonts, not widget text, so every existing test (which finds widgets by text/type) should be unaffected.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add app theme with brand colors and typography"
```

---

## Task 2: Friendly auth error messages

**Files:**
- Create: `lib/auth_errors.dart`, `test/auth_errors_test.dart`

**Interfaces:**
- Produces: `mapAuthError(String message) -> String`, consumed by Task 3's login/signup screens in place of the raw `AuthException.message`.

- [ ] **Step 1: Write the failing test**

Create `test/auth_errors_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/auth_errors.dart';

void main() {
  test('maps known Supabase error messages to French', () {
    expect(mapAuthError('Invalid login credentials'), 'Email ou mot de passe incorrect.');
    expect(mapAuthError('User already registered'), 'Un compte existe déjà avec cet email.');
  });

  test('falls back to a generic message for unknown errors', () {
    expect(mapAuthError('Some new Supabase error string'), 'Une erreur est survenue, réessaie.');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/auth_errors_test.dart
```

Expected: FAIL — `lib/auth_errors.dart` doesn't exist.

- [ ] **Step 3: Create `lib/auth_errors.dart`**

```dart
String mapAuthError(String message) {
  const knownErrors = {
    'Invalid login credentials': 'Email ou mot de passe incorrect.',
    'User already registered': 'Un compte existe déjà avec cet email.',
    'Email not confirmed': "Confirme ton email avant de te connecter.",
    'Password should be at least 6 characters':
        'Le mot de passe doit contenir au moins 6 caractères.',
  };
  return knownErrors[message] ?? 'Une erreur est survenue, réessaie.';
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/auth_errors_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/auth_errors_test.dart lib/auth_errors.dart
git commit -m "feat: translate Supabase auth errors to French"
```

---

## Task 3: Signup & login screen polish

**Files:**
- Create: `test/screens/login_screen_test.dart`, `test/screens/signup_screen_test.dart`
- Modify: `lib/screens/auth/login_screen.dart` (full rewrite), `lib/screens/auth/signup_screen.dart` (full rewrite)

**Interfaces:**
- Consumes: `AppColors` (Task 1, `lib/theme.dart`), `mapAuthError` (Task 2, `lib/auth_errors.dart`).
- Produces: no new interfaces — `LoginScreen`/`SignupScreen` keep their existing no-argument constructors, used unchanged by `lib/app_router.dart`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/screens/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/screens/auth/login_screen.dart';

void main() {
  testWidgets('toggles password visibility', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    TextField passwordField() => tester.widget<TextField>(find.byType(TextField).at(1));

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('shows inline error and blocks submit on invalid email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Entre une adresse email valide.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

Create `test/screens/signup_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/screens/auth/signup_screen.dart';

void main() {
  testWidgets('toggles password visibility', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    TextField passwordField() => tester.widget<TextField>(find.byType(TextField).at(1));

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('shows inline error and blocks submit on short password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();
    await tester.tap(find.text("S'inscrire"));
    await tester.pump();

    expect(find.text('Le mot de passe doit contenir au moins 6 caractères.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

- [ ] **Step 2: Run both to confirm they fail**

```bash
flutter test test/screens/login_screen_test.dart test/screens/signup_screen_test.dart
```

Expected: FAIL — neither screen has a visibility-toggle icon or inline validation yet, so `find.byIcon(Icons.visibility)` finds nothing and no error text appears.

- [ ] **Step 3: Replace `lib/screens/auth/login_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth_errors.dart';
import '../../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _emailError;
  String? _passwordError;
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail();
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final email = _emailController.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    setState(() => _emailError = valid ? null : 'Entre une adresse email valide.');
    return valid;
  }

  bool _validatePassword() {
    final valid = _passwordController.text.length >= 6;
    setState(
      () => _passwordError = valid ? null : 'Le mot de passe doit contenir au moins 6 caractères.',
    );
    return valid;
  }

  Future<void> _submit() async {
    final emailValid = _validateEmail();
    final passwordValid = _validatePassword();
    if (!emailValid || !passwordValid) return;

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
      setState(() => _error = mapAuthError(e.message));
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
            const Icon(Icons.pets, size: 48, color: AppColors.primary),
            const SizedBox(height: 8),
            Text('Pawfolio', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              focusNode: _emailFocus,
              decoration: InputDecoration(labelText: 'Email', errorText: _emailError),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
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

- [ ] **Step 4: Run the login test to confirm it passes**

```bash
flutter test test/screens/login_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Replace `lib/screens/auth/signup_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth_errors.dart';
import '../../theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _emailError;
  String? _passwordError;
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail();
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final email = _emailController.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    setState(() => _emailError = valid ? null : 'Entre une adresse email valide.');
    return valid;
  }

  bool _validatePassword() {
    final valid = _passwordController.text.length >= 6;
    setState(
      () => _passwordError = valid ? null : 'Le mot de passe doit contenir au moins 6 caractères.',
    );
    return valid;
  }

  Future<void> _submit() async {
    final emailValid = _validateEmail();
    final passwordValid = _validatePassword();
    if (!emailValid || !passwordValid) return;

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
      setState(() => _error = mapAuthError(e.message));
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
            const Icon(Icons.pets, size: 48, color: AppColors.primary),
            const SizedBox(height: 8),
            Text('Pawfolio', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              focusNode: _emailFocus,
              decoration: InputDecoration(labelText: 'Email', errorText: _emailError),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
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

- [ ] **Step 6: Run the signup test to confirm it passes**

```bash
flutter test test/screens/signup_screen_test.dart
```

Expected: PASS.

- [ ] **Step 7: Run the full suite and commit**

```bash
flutter test > /tmp/task3_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task3_test_output.txt
git add -A
git commit -m "feat: polish signup and login screens with validation and branding"
```

---

## Task 4: Reminder urgency color-coding & Home screen refinement

**Files:**
- Modify: `lib/reminders.dart`, `test/reminders_test.dart`, `lib/screens/home/home_screen.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 1).
- Produces: `ReminderUrgency` (enum: `today`, `soon`, `later`) and `reminderUrgency(DateTime dueDate, {DateTime? now}) -> ReminderUrgency`, both added to `lib/reminders.dart` alongside the existing `DueItem`/`sortUpcoming`.

- [ ] **Step 1: Write the failing tests**

Append to `test/reminders_test.dart` (inside the existing `main()`, after the two `sortUpcoming` tests — the file already has `final now = DateTime(2024, 6, 15);` at the top of `main()`, reuse it):

```dart
  test('reminderUrgency classifies a due-today item', () {
    expect(reminderUrgency(DateTime(2024, 6, 15), now: now), ReminderUrgency.today);
  });

  test('reminderUrgency classifies an item due within 7 days as soon', () {
    expect(reminderUrgency(DateTime(2024, 6, 20), now: now), ReminderUrgency.soon);
  });

  test('reminderUrgency classifies an item due after 7 days as later', () {
    expect(reminderUrgency(DateTime(2024, 6, 25), now: now), ReminderUrgency.later);
  });
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
flutter test test/reminders_test.dart
```

Expected: FAIL — `reminderUrgency`/`ReminderUrgency` don't exist yet.

- [ ] **Step 3: Add `ReminderUrgency` and `reminderUrgency` to `lib/reminders.dart`**

Append to the end of `lib/reminders.dart` (after the existing `DueItem` class and `sortUpcoming` function — don't remove or modify either):

```dart
enum ReminderUrgency { today, soon, later }

ReminderUrgency reminderUrgency(DateTime dueDate, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final daysUntil = dueDate.difference(startOfToday).inDays;
  if (daysUntil <= 0) return ReminderUrgency.today;
  if (daysUntil <= 7) return ReminderUrgency.soon;
  return ReminderUrgency.later;
}
```

- [ ] **Step 4: Run the test again**

```bash
flutter test test/reminders_test.dart
```

Expected: PASS — all 5 tests in this file (2 original `sortUpcoming` + 3 new `reminderUrgency`).

- [ ] **Step 5: Update `lib/screens/home/home_screen.dart`**

Add these two imports alongside the existing ones:

```dart
import '../../reminders.dart';
import '../../theme.dart';
```

Add this private helper function at the bottom of the file, outside the `HomeScreen` class:

```dart
Color _urgencyColor(ReminderUrgency urgency) {
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

In `HomeScreen.build`, change the `AppBar`'s `title` from:

```dart
        title: const Text('Pawfolio'),
```

to:

```dart
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.pets),
            SizedBox(width: 8),
            Text('Pawfolio'),
          ],
        ),
```

Change the upcoming-reminders `ListTile` from:

```dart
                          for (final item in items.take(3))
                            ListTile(
                              dense: true,
                              title: Text('${item.petName} · ${item.label}'),
                              subtitle: Text(dateOnly(item.dueDate)),
                            ),
```

to:

```dart
                          for (final item in items.take(3))
                            ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.circle,
                                size: 12,
                                color: _urgencyColor(reminderUrgency(item.dueDate)),
                              ),
                              title: Text('${item.petName} · ${item.label}'),
                              subtitle: Text(dateOnly(item.dueDate)),
                            ),
```

Change the empty-pets-list state from:

```dart
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun animal pour le moment')),
                    )
```

to:

```dart
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.pets, size: 48, color: AppColors.muted),
                          const SizedBox(height: 12),
                          const Text(
                            'Aucun animal pour le moment',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ajoute ton premier animal avec le bouton + ci-dessous.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    )
```

- [ ] **Step 6: Run the full suite and commit**

```bash
flutter test > /tmp/task4_test_output.txt 2>&1
echo "exit code: $?"
cat /tmp/task4_test_output.txt
git add -A
git commit -m "feat: color-code upcoming reminders by urgency and improve empty state"
```

---

## Task 5: Manual verification on the Android emulator

**Files:**
- None (verification task; only commit if this step surfaces something that needs fixing)

**Interfaces:**
- Consumes: everything from Tasks 1-4.

- [ ] **Step 1: Boot the emulator and run the app against the real local Supabase stack**

```bash
cd /home/missia03/Projects/pawfolio
supabase status || supabase start
emulator -avd pawfolio -no-snapshot-load &
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
./scripts/run_local.sh &
sleep 60
adb shell screencap -p /sdcard/pawfolio_login.png
adb pull /sdcard/pawfolio_login.png /tmp/pawfolio_login.png
```

Read `/tmp/pawfolio_login.png`. Confirm: the paw icon + "Pawfolio" wordmark appear above the form, the "Se connecter" button is filled in the new terracotta primary color (not Material purple), and the font is visibly not the default Roboto (Manrope has noticeably different letterforms, especially in the headline).

- [ ] **Step 2: Verify inline validation and the password toggle**

Tap the "Se connecter" button without entering anything (`adb shell input tap <x> <y>` at the button's screen coordinates, read from the screenshot), then screenshot again:

```bash
adb shell screencap -p /sdcard/pawfolio_validation.png
adb pull /sdcard/pawfolio_validation.png /tmp/pawfolio_validation.png
```

Confirm the email field shows "Entre une adresse email valide." beneath it, in the error-red color, and no loading spinner appeared (submission was blocked). Then tap the password field's eye icon and screenshot once more to confirm the password text becomes visible (if any was entered) or that the icon itself visibly toggles between the two states.

- [ ] **Step 3: Sign up (or log in with an existing test account) and verify the Home screen**

If no account exists yet on this local stack, tap "Créer un compte", fill in a test email/password via `adb shell input tap`/`input text`, and submit. Otherwise log in with the account created during the MVP's Task 11 verification.

```bash
adb shell screencap -p /sdcard/pawfolio_home.png
adb pull /sdcard/pawfolio_home.png /tmp/pawfolio_home.png
```

Confirm: the app bar shows the paw icon + "Pawfolio", the FAB and any buttons use the new primary color, and — if any pets/reminders already exist from earlier testing — the "À venir" list shows a colored dot per item consistent with its urgency (red for due today, amber for due soon, muted gray for later). If the pet list is empty, confirm the new empty-state icon + two lines of text render correctly instead of the old bare centered text.

- [ ] **Step 4: Fix anything found, or confirm clean**

If any of the above didn't match (e.g., a color looks wrong, text overflows, the toggle doesn't visually update), fix it in the relevant file from Tasks 1-4 and re-screenshot to confirm. If everything matches, no code changes are needed.

- [ ] **Step 5: Final commit (only if Step 4 required changes)**

```bash
cd /home/missia03/Projects/pawfolio
git add -A
git commit -m "fix: address visual issues found during design polish verification"
```

If Step 4 required no changes, skip this commit — there's nothing new to record.

---
