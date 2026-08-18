# Changelog

All notable changes to Pawfolio are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- App-wide theme with brand colors and Manrope typography (`lib/theme.dart`).
- Friendly, French-translated messages for known Supabase auth errors.
- Inline email/password validation and a password-visibility toggle on the
  login and signup screens, plus first branding (paw icon + wordmark).
- Color-coded urgency (today / soon / later) for upcoming reminders, and a
  richer empty state on the Home screen.

## [1.0.0] - MVP baseline

### Added
- Email/password authentication (Supabase) with router redirect guard.
- Pet profiles with species/breed, and a pet detail screen.
- Vaccination, weight, treatment, and vet-visit tracking, including editing.
- Upcoming reminders with local notification scheduling.
