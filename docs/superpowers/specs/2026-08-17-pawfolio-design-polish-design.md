# Pawfolio — Visual Design & Signup Flow Polish — Design

## Purpose

The MVP (v1) is functionally complete and verified end-to-end (see
`2026-08-17-pawfolio-design.md` and the implementation plan/ledger under
`docs/superpowers/plans/` and `.superpowers/sdd/`). It currently has **no
custom visual identity** — every screen renders Flutter's stock Material
purple defaults — and the signup/login flow is a bare, unstyled form with
no inline validation, no password visibility toggle, and raw (often
English) Supabase error messages surfaced directly to the user.

This spec covers two related improvements:
1. A cohesive, professional visual identity applied app-wide via a single
   Flutter theme.
2. A polished signup/login flow: friendlier errors, inline validation, a
   password visibility toggle, and a first branding moment.

Both are scoped together because the signup screens are themselves the
first thing a new user sees and should carry the new visual identity from
day one.

## Design approach

**Centralized `ThemeData` (`lib/theme.dart`), applied once via
`MaterialApp.router(theme: ...)`.** Every Material widget already reads
`Theme.of(context)` by default, so a single theme file propagates color and
typography consistency to every existing screen with no per-screen edits
required beyond the signup flow's own UX changes.

Rejected alternatives: hand-styling each screen individually (breaks
cross-screen consistency — the exact failure mode a "product register" app
like this must avoid) and building a full custom component library
(`lib/design_system/` with wrapped Button/TextField/Card widgets) — over-
engineering for an ~10-screen MVP; Flutter's built-in theme inheritance
already gets most of the benefit without a parallel abstraction layer.

## Visual identity

**Color strategy:** restrained — the background carries no brand color;
warmth and identity live in the primary/accent colors and typography only
(avoids the generic warm-cream/beige "AI-app" background look).

| Token | Hex | Role | Contrast vs. white |
|---|---|---|---|
| `background` | `#FFFFFF` | Screen background | — |
| `surface` | `#FBF8F7` | Cards, list tiles (barely tinted, for separation from background) | — |
| `primary` | `#A13D26` | Primary actions, FAB, active nav/tab indicator | 6.54:1 (white text) |
| `accentPositive` | `#1F7052` | "Up to date" / healthy-state indicators | 6.00:1 (white text) |
| `warningDueSoon` | `#8A5407` | Reminder due within the next 7 days | 6.27:1 (white text) |
| `error` | `#D32F2F` | Reminder due today, destructive actions, form errors | 4.98:1 (white text) |
| `ink` | `#1A1412` | Primary body text | 18.22:1 |
| `muted` | `#6E625D` | Secondary text, hints | 5.89:1 |
| `border` | `#E8DED9` | Dividers, input borders | — |

All pairings meet or exceed WCAG AA (4.5:1 body text); `ink` exceeds AAA
(7:1). `error` is deliberately a distinct, more saturated red than
`primary`'s muted terracotta so the two are never visually confused.

**Semantic color usage is functional, not decorative:** the "upcoming
reminders" list (Task 10) already sorts by due date — this design adds a
color cue per item (neutral/`warningDueSoon`/`error`) based on how close
the due date is, turning color into a second, glanceable signal rather
than a purely aesthetic choice.

**Typography:** a single font family — Manrope, via the `google_fonts`
package (`flutter pub add google_fonts`; simplest standard integration,
resolves at first render, accepted for this MVP rather than bundling font
assets manually) — across all Material 3 type roles (display/headline/
title/body/label), weights 400/500/600/700. Product UI doesn't need a
display/body font pairing; one well-chosen family carries the whole
hierarchy, per the "product register" guidance this design follows
(app UI, not a marketing surface).

**Icons:** Flutter's built-in Material Symbols (`Icons.*`, already
available with no new dependency) exclusively — no emoji, no mixed icon
libraries. Concrete choices: `Icons.pets` (app mark on auth screens, Home
app bar), `Icons.vaccines` (vaccinations), `Icons.monitor_weight`
(weight), `Icons.medication` (treatments), `Icons.local_hospital` (vet
visits).

## Signup / login flow

| Today | This design |
|---|---|
| Raw Supabase error text (often English, e.g. "Invalid login credentials") | A pure `mapAuthError(String) -> String` function (mirroring `authRedirect`'s pattern from Task 4) translates known Supabase Auth error messages to plain French; unknown errors fall back to a generic "Une erreur est survenue, réessaie." |
| No validation before the network round-trip | Inline validation on blur (not per-keystroke): malformed email, password under 6 characters — shown under the relevant field, not just after a failed request |
| Password field has no visibility toggle | An eye icon toggles `obscureText`, standard `IconButton` inside the `TextField`'s `suffixIcon` |
| Bare form, no branding | `Icons.pets` mark + "Pawfolio" wordmark above the form, in the new theme |
| No autofill hints | `autofillHints: [AutofillHints.email]` / `[AutofillHints.password]` so the device's password manager can offer to fill/save |

**Deliberately not added (YAGNI):** a password-confirmation field (the
show/hide toggle already covers the typo risk it exists to prevent), social
sign-in, and multi-step signup — it stays a single-screen form, in keeping
with getting a new user to their first real action as fast as possible.

**Home screen empty state:** "Aucun animal pour le moment" becomes a real
prompt — an icon, a one-line explanation of what will appear there, and
visual emphasis pointing at the existing add-pet FAB — rather than static
centered text.

## Testing

- Unit test `mapAuthError` against the known Supabase error strings and the
  unknown-error fallback (pure function, same pattern as
  `test/auth_redirect_test.dart`).
- Widget tests for the login/signup screens: the password-visibility
  toggle actually flips `obscureText`; invalid input shows the inline error
  and does **not** trigger a network call (verified via a fake/no-op auth
  client, not a real Supabase round-trip).
- No automated test for the exact colors/typography — that would require
  golden-image testing, disproportionate for this MVP. Verified manually
  instead.
- Manual verification on the Android emulator (same approach as Task 11):
  confirm the theme renders consistently across every screen and the
  signup flow behaves as designed end-to-end.

## Out of scope

- A custom-generated logo/mark (using a vector icon from Material Symbols
  instead, per explicit decision during brainstorming).
- Dark mode (not requested; the app has no dark theme today and this spec
  doesn't add one).
- Any change to the data model, screens' functional behavior, or the
  bottom-sheet-based add/edit forms established in the MVP design — this
  is a visual and signup-UX pass only.
