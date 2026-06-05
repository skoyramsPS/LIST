// lib/ui/tokens/app_tokens.dart
//
// The single source of truth for every colour, spacing, radius, elevation, and
// text style in TheLIST (design_system.md §2). The UI layer routes ALL visual
// values through here — the grep gates forbid raw hex / spacing literals in
// lib/features, so "calm pastel" can be tuned globally in this one file.
//
// This is an intentional starter scaffold: the full pastel palette, light/dark
// schemes, and the restricted-weight Plus Jakarta Sans text theme land here as
// the design system is built. Keep everything token-shaped from day one.

import 'package:flutter/widgets.dart';

/// Root accessor for all design tokens.
abstract final class AppTokens {
  static const AppSpacing spacing = AppSpacing();
  static const AppRadius radius = AppRadius();
  static const AppColors color = AppColors();
}

/// Spacing scale (generous = calm). Use `AppTokens.spacing.md`, never raw numbers.
class AppSpacing {
  const AppSpacing();
  final double xs = 4;
  final double sm = 8;
  final double md = 16;
  final double lg = 24;
  final double xl = 32;
}

/// Corner radii (generous = calm). Use `AppTokens.radius.xl`, never raw numbers.
class AppRadius {
  const AppRadius();
  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 24;
}

/// Semantic colours. Pastel palette + per-category accents land here.
/// Placeholder values; replace with the real pastel system. Use
/// `AppTokens.color.surface`, never a raw hex literal.
class AppColors {
  const AppColors();
  final Color surface = const Color(0xFFFFFFFF);
  final Color surfaceMuted = const Color(0xFFF4F4F6);
  final Color accent = const Color(0xFFB8C7F0);
  final Color accentMuted = const Color(0xFFD9E1F7);
  final Color success = const Color(0xFFBFE3C9);
  final Color warning = const Color(0xFFF7E3B0);
  final Color danger = const Color(0xFFE9B0B0);
  final Color borderSoft = const Color(0x1A1A1A1A); // ~10% of text colour
}
