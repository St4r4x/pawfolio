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
