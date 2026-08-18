# Pawfolio — Visual Design v2 (Navigation, Motion, Dark Mode, Illustrations) — Design

## Purpose

The first design pass (`2026-08-17-pawfolio-design-polish-design.md`) gave Pawfolio a
brand theme (terracotta/Manrope) and polished the signup/login flow. Everything past
that first impression — the Home pet list, the four pet-detail tabs, and every empty
state — still renders as plain `ListTile`s and centered text with no illustration, no
motion, no chart, and no dark mode.

This spec covers a second, deeper pass, approved in brainstorming:

1. A bottom-navigation restructuring (Mes animaux / Rappels / Profil) replacing the
   single-screen Home + buried logout icon.
2. Illustrated, consistent empty states across all five list screens, plus Lottie
   moments for two success actions.
3. A weight-trend chart on the Poids tab.
4. Deliberate motion: staggered list entrances, screen transitions, and micro-
   interactions — all respecting reduced-motion.
5. A dark theme, system-driven by default with a manual override in the new Profil
   screen.

## Architecture approach

**Hybrid, targeted reuse — three small shared pieces, no general component library.**

The prior spec rejected a full `lib/design_system/` (wrapped Button/Card/TextField)
as over-engineering for an MVP; nothing about this pass changes that trade-off for
those widgets — `FilledButton`, `Card`, `TextField`, and `ListTile` keep reading
directly from `ThemeData` as they do today. What *has* changed is that five different
screens now need the same illustration+title+subtitle+action empty-state layout, two
screens need the same species-avatar treatment, and dark mode means motion/spacing
values that were previously inlined ad hoc need one shared source of truth to stay
consistent across both themes. Three additions cover exactly that:

- `lib/widgets/empty_state.dart` — `EmptyState` widget (illustration, title, subtitle,
  optional action button). Used on Home (no pets), Rappels (no reminders), and the
  Vaccins/Traitements/Visites vétérinaires tabs (currently plain centered `Text`).
- `lib/widgets/pet_avatar.dart` — `PetAvatar` widget (species icon in a colored disc).
  Used on Home's pet cards and the pet-detail app bar.
- `lib/motion.dart` — duration/curve/spacing constants (see Motion section). Extends
  the existing pattern of `lib/theme.dart` rather than introducing a new layer.

Rejected: a generic `AppCard`/`AppButton` wrapper layer — would touch every existing
screen for no behavioral gain, since `ThemeData` already themes those widgets
consistently; and a `lib/design_system/` package structure — three files don't
warrant a package boundary.

## Navigation

**`StatefulShellRoute.indexedStack`** (built into `go_router` ^17.5.0, no new
dependency) wraps three tab roots:

| Tab | Route | Replaces |
|---|---|---|
| Mes animaux | `/` | Current Home screen body (pet list + reminders preview) |
| Rappels | `/reminders` | New — full upcoming-reminders list |
| Profil | `/profile` | New — was the lone logout `IconButton` in Home's `AppBar` |

`/pets/:id` stays a **top-level route outside the shell** (pushed on top, hides the
bottom nav), matching how the detail screen already behaves today — this is a
deliberate choice, not an oversight: detail screens hiding chrome is standard mobile
navigation, and nesting it in the shell would require a fourth, hidden branch for no
benefit.

**Rappels screen** (`lib/screens/reminders/reminders_screen.dart`, new): reuses
`upcomingRemindersProvider` and `reminderUrgency` (`lib/reminders.dart`) already built
for Home's preview — no new data logic. Renders the full list grouped into three
sections (Aujourd'hui / Cette semaine / Plus tard) instead of Home's flat top-3 slice.
`EmptyState` when the list is empty.

**Profil screen** (`lib/screens/profile/profile_screen.dart`, new): shows the signed-
in user's email (`Supabase.instance.client.auth.currentUser?.email`), a theme-mode
selector (Système / Clair / Sombre — see Dark mode section), and the sign-out action
(moved here from Home's `AppBar`).

**Home screen changes:** drops the `AppBar` logout icon (now in Profil). Reminders
preview keeps its existing top-3-with-"Voir tout" pattern, where "Voir tout" now
navigates to `/reminders` instead of being static text.

## Screen-by-screen visual changes

- **Home pet list:** each `ListTile` becomes a `Card` containing `PetAvatar` (species
  icon in a colored disc, reusing existing tokens rather than introducing new colors:
  `dog` → `Icons.pets` on `AppColors.primary`, `cat` → `Icons.pets` on
  `AppColors.accentPositive`, `other` → `Icons.pets` on `AppColors.muted`; icon color
  is `Colors.white` on the two saturated discs and `AppColors.background` on the
  muted one, matching whichever meets 4.5:1), name, species/breed subtitle, and — if
  the pet has an upcoming reminder — a small urgency-colored chip showing the soonest
  one. Tapping still pushes `/pets/:id`; the edit `IconButton` stays.
- **Rappels:** see Navigation section above.
- **Pet detail app bar:** adds `PetAvatar` next to the pet's name (currently name-only
  `Text` in the `AppBar` — confirmed by reading `pet_detail_screen.dart`).
- **Pet detail `TabBar`:** switches from the Material default indicator to
  `indicatorColor: AppColors.primary` with `indicatorWeight: 3` and an animated
  transition already provided by `TabBar` itself — no custom code needed
  (`TabBarView`'s built-in `PageView` animation covers the swipe transition; adding a
  shared-axis wrapper here would fight the built-in one, not improve it).
- **Onglet Poids:** `fl_chart`'s `LineChart` rendered above the existing
  `ListView.builder`, plotting `weightKg` against `recordedAt` for all entries (X axis
  labeled with `dateOnly`, per the existing helper). Chart hidden (not just empty) when
  there are 0–1 entries — a line needs at least two points to show a trend; a single
  point renders as a lone dot with no informative slope, so the tab shows only the list
  in that case.
- **Vaccins / Traitements / Visites vétérinaires tabs:** the current plain
  `Text('Aucun(e) ... enregistré(e)')` empty states become `EmptyState` with a
  per-domain illustration (see Assets below) and the same "use the + button below"
  guidance Home already established.
- **Profil:** see Navigation section above.

## Assets

**Illustrations (SVG, static):** five illustrations, one per empty state, sourced
from unDraw (CC0, no attribution required) and recolored via `flutter_svg`'s
`colorFilter` to the existing `AppColors.primary` / `AppColors.muted` so they read as
on-brand line art rather than stock clip-art:

| Empty state | Illustration theme |
|---|---|
| Home — no pets | A pet silhouette / paw print scene |
| Rappels — no reminders | A calendar or checklist scene |
| Poids — no entries | A scale or trend-line scene |
| Vaccins — no entries | A syringe/shield scene |
| Traitements — no entries | A medicine/pill scene |
| Visites véto (tab label "RDV") — no entries | A stethoscope/clinic scene |

Six illustrations in total — one per empty state listed above.

Stored under `assets/illustrations/*.svg`, declared in `pubspec.yaml`'s `flutter:
assets:` section. **Actual download of these SVG files happens during implementation,
with an explicit ask for confirmation first** (downloading external files requires
that per this session's operating rules) — this spec fixes the *theme* and *sourcing*
per state, not the exact files.

**Lottie animations:** two, from LottieFiles' free/CC library, for the two moments
that currently end in a bare bottom-sheet dismiss with no feedback:

- Adding a pet (first one, i.e. going from the empty state to having a pet) — a short
  celebratory paw/confetti loop, played once over the `EmptyState` before it's
  replaced by the populated list.
- Adding a weight entry — a short checkmark/success loop, played inline where the
  bottom sheet closes.

Not used for every success action (e.g. editing an existing vaccination) — reserved
for the two "first meaningful action" moments per the brainstorming discussion, to
avoid the animation becoming background noise.

## Motion

`lib/motion.dart` — new file, constants only:

```dart
class AppMotion {
  const AppMotion._();
  static const microDuration = Duration(milliseconds: 180);   // press feedback, chips
  static const transitionDuration = Duration(milliseconds: 300); // screen transitions
  static const staggerStep = Duration(milliseconds: 40);     // per-item list delay
  static const entranceCurve = Curves.easeOutQuart;
  static const microCurve = Curves.easeOutCubic;
}
```

- **List entrances** (Home pet cards, Rappels items): `flutter_animate`'s
  `.animate().fadeIn().slideY(begin: 0.08, end: 0)` per item, staggered by
  `AppMotion.staggerStep` via `flutter_animate`'s built-in `interval` on
  `AnimateList`. Applies once per list build, not on every rebuild (guarded so
  scrolling/refresh doesn't replay it).
- **Screen transitions:** the `animations` package's `SharedAxisTransition` (type:
  `SharedAxisTransitionType.horizontal`) wired into each shell-tab route and the
  `/pets/:id` push via `go_router`'s `CustomTransitionPage`, using
  `AppMotion.transitionDuration`.
- **Micro-interactions:** a subtle press scale (0.97) on `PetAvatar`-bearing cards via
  `flutter_animate`'s `.animate(target: pressed ? 1 : 0).scale()`, `AppMotion.microDuration`.
- **Reduced motion:** every animation above is wrapped so that when
  `MediaQuery.of(context).disableAnimations` is true, durations collapse to `Duration.zero`
  (a single helper, `AppMotion.durationOrInstant(context, duration)`, used everywhere
  instead of the raw constants) — one guard, not a per-call check.

## Dark mode

`pawfolioTheme` (light, existing) is joined by a new `pawfolioDarkTheme` in
`lib/theme.dart`, built the same way (`ColorScheme.fromSeed(brightness: Brightness.dark,
...)` with explicit role overrides) rather than inverting the light tokens:

| Token | Light (existing) | Dark (new) | Contrast vs. its background |
|---|---|---|---|
| `background` | `#FFFFFF` | `#16100F` | — |
| `surface` | `#FBF8F7` | `#221A18` | — |
| `primary` | `#A13D26` | `#E2836A` (lighter/desaturated) | 6.89:1 (on dark bg) |
| `onPrimary` | `#FFFFFF` | `#3A140A` (dark ink on light primary) | 5.99:1 |
| `accentPositive` | `#1F7052` | `#6FCDA0` | 9.79:1 |
| `warningDueSoon` | `#8A5407` | `#E3A548` | 8.74:1 |
| `error` | `#D32F2F` | `#FFB4AB` | 11.09:1 |
| `onError` | `#FFFFFF` | `#4A0E08` | 9.11:1 |
| `ink` | `#1A1412` | `#F2E9E6` | 15.76:1 (on background) |
| `muted` | `#6E625D` | `#B9ACA6` | 8.53:1 (on background) |
| `border` | `#E8DED9` | `#3A2E2B` | — |

All ratios computed against WCAG relative luminance; every text/icon pairing clears
AA (4.5:1) with margin, most clear AAA (7:1). `error` (pink-red) and `warningDueSoon`
(amber) stay visually distinct in dark mode as they are in light mode.

`MaterialApp.router` gets `darkTheme: pawfolioDarkTheme` alongside the existing
`theme: pawfolioTheme`. `themeMode` is read from a new `themeModeProvider` (Riverpod,
`lib/providers/theme_mode_provider.dart`) backed by `shared_preferences` — persists
the user's Système/Clair/Sombre choice from the Profil screen across launches.
Default is `ThemeMode.system` (device setting) until the user picks otherwise.

`shared_preferences` moves from `dev_dependencies` to `dependencies` in
`pubspec.yaml` — it's currently a dev-only dependency used solely to mock Supabase's
own session storage in `test/app_smoke_test.dart`; this pass is its first real
runtime use.

## New dependencies

| Package | Purpose | Rejected alternative |
|---|---|---|
| `flutter_svg` | Render the empty-state illustrations | Bundling PNGs — blurry at scale, no theming via `colorFilter` |
| `lottie` | Two success-moment animations | Hand-rolled `AnimationController` sequences — far more code for a worse result |
| `fl_chart` | Weight-trend line chart | `charts_flutter` (unmaintained/discontinued) |
| `flutter_animate` | List stagger + micro-interactions | Hand-rolled `AnimationController`/`Tween` per widget — this is exactly the boilerplate the package removes |
| `animations` (Google) | Shared-axis screen transitions | Hand-rolled `PageRouteBuilder` with custom `Tween`s — reinventing a well-tested Material Motion spec |
| `shared_preferences` (moved to `dependencies`) | Persist theme-mode choice | — |

## Testing

- Widget tests: `EmptyState` renders illustration/title/subtitle/action; `PetAvatar`
  maps each species to its icon/color; theme-mode selector updates
  `themeModeProvider` and persists via a faked `SharedPreferences` (same
  `setMockInitialValues` pattern `test/app_smoke_test.dart` already uses).
- Weight chart: widget test asserts the chart is absent with 0–1 entries and present
  with 2+, without asserting exact pixel rendering (that's what `fl_chart`'s own test
  suite covers).
- Navigation: widget test confirms the bottom nav switches the visible branch and
  that `/pets/:id` still pushes over it (shell state preserved on return).
- No golden-image testing for the dark theme or illustrations — disproportionate for
  this app's size, per the same reasoning as the first design spec. Verified manually
  on the Android emulator in both light and dark system settings, per the existing
  manual-verification pattern (Task 11 / the design-polish spec).
- Reduced motion: manual verification with the emulator's "Remove animations"
  accessibility setting on, confirming lists/transitions render instantly rather than
  animating.

## Out of scope

- Real photo upload for pet avatars (stays icon-by-species) — no photo storage/upload
  feature exists today and adding one is a separate, unrelated project.
- Push notifications beyond the existing local reminder notifications.
- Any change to the data model or Supabase schema — this pass is entirely
  presentation-layer (screens, theme, navigation shell, assets).
- A settings screen beyond the Profil essentials above (no notification preferences,
  no account deletion, no language switch) — none were requested and the app is
  French-only today.
