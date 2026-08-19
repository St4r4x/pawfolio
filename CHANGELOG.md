# Changelog

All notable changes to Pawfolio are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed
- Pets, vaccinations, treatments, vet visits, and weight entries no longer
  show stale data from a previously signed-in account after switching
  accounts within the same running session.

### Added
- Set-new-password screen, completing the forgot-password flow: clicking
  the reset-password email link now routes to a screen to actually type a
  new password, instead of silently logging in on Home with the old one
  still active.
- Breed and birth date fields in the add/edit pet sheet (both already
  existed in the data model and already displayed on the pet detail
  screen — only the input fields were missing).
- Centered card layout and a slogan on the login and signup screens.
- Forgot-password screen, wired to Supabase Auth's password reset email.
- Onboarding flow after signup: an optional first-name step, then a
  skippable first-pet creation step, replacing the empty Home landing.
- App-wide theme with brand colors and Manrope typography (`lib/theme.dart`).
- Friendly, French-translated messages for known Supabase auth errors.
- Inline email/password validation and a password-visibility toggle on the
  login and signup screens, plus first branding (paw icon + wordmark).
- Color-coded urgency (today / soon / later) for upcoming reminders, and a
  richer empty state on the Home screen.
- Illustrated empty states in Vaccins, Traitements, and RDV tabs with icons
  and helpful actionable subtitles.
- Real unDraw SVG illustrations (via `flutter_svg`) in all six empty states
  (pets, reminders, weight, vaccinations, treatments, vet visits), replacing
  the placeholder icons.

## [1.0.0] - MVP baseline

### Added
- Email/password authentication (Supabase) with router redirect guard.
- Pet profiles with species/breed, and a pet detail screen.
- Vaccination, weight, treatment, and vet-visit tracking, including editing.
- Upcoming reminders with local notification scheduling.
