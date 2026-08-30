import 'package:flutter/material.dart';

// ─── Server status ────────────────────────────────────────────────────────────
enum ServerStatus { checking, online, offline }

// ─── Color palette ───────────────────────────────────────────────────────────
class NeuColors {
  NeuColors._();

  /// High-contrast toggle. When `true`, switches to a dark neumorphic palette.
  static bool highContrast = false;

  /// The main background – soft cool grey / dark slate
  static Color get background =>
      highContrast ? const Color(0xFF1A1A2E) : const Color(0xFFE0E5EC);

  /// Light (top-left) shadow for raised surfaces
  static Color get lightShadow =>
      highContrast ? const Color(0xFF2D2D44) : const Color(0xFFFFFFFF);

  /// Dark (bottom-right) shadow for raised surfaces
  static Color get darkShadow =>
      highContrast ? const Color(0xFF0D0D1A) : const Color(0xFFA3B1C6);

  /// Primary accent – indigo-violet
  static const Color accent = Color(0xFF6C63FF);

  /// Lighter accent tint
  static const Color accentLight = Color(0xFF9B8FFF);

  /// Primary text
  static Color get text =>
      highContrast ? const Color(0xFFF0F0F5) : const Color(0xFF2D3142);

  /// Secondary / muted text
  static Color get textMuted =>
      highContrast ? const Color(0xFF8888AA) : const Color(0xFF7B8096);

  /// Semantic: success / high confidence
  static const Color success = Color(0xFF4CAF7D);

  /// Semantic: mid confidence / warning
  static const Color warning = Color(0xFFFF9F43);

  /// Semantic: error / low confidence / server offline
  static const Color error = Color(0xFFFF5252);
}

// ─── Shadow helpers ──────────────────────────────────────────────────────────

/// Raised (extruded) neumorphic shadows.
/// [depth] 0.0–1.0 controls shadow intensity / offset.
List<BoxShadow> neuRaisedShadows({double depth = 1.0}) {
  final d = depth.clamp(0.1, 1.0);
  return [
    BoxShadow(
      color: NeuColors.darkShadow.withOpacity(0.65 * d),
      offset: Offset(6 * d, 6 * d),
      blurRadius: 12 * d,
    ),
    BoxShadow(
      color: NeuColors.lightShadow.withOpacity(NeuColors.highContrast ? 0.3 : 0.9),
      offset: Offset(-5 * d, -5 * d),
      blurRadius: 10 * d,
    ),
  ];
}

/// Inset (recessed / pressed) neumorphic shadows.
List<BoxShadow> neuInsetShadows() => [
      BoxShadow(
        color: NeuColors.darkShadow.withOpacity(0.5),
        offset: const Offset(3, 3),
        blurRadius: 6,
      ),
      BoxShadow(
        color: NeuColors.lightShadow.withOpacity(NeuColors.highContrast ? 0.2 : 1.0),
        offset: const Offset(-3, -3),
        blurRadius: 6,
      ),
    ];

// ─── Decoration shortcuts ────────────────────────────────────────────────────

BoxDecoration neuRaisedDecoration({double radius = 16, double depth = 1.0}) =>
    BoxDecoration(
      color: NeuColors.background,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: neuRaisedShadows(depth: depth),
    );

BoxDecoration neuInsetDecoration({double radius = 16}) => BoxDecoration(
      color: NeuColors.background,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: neuInsetShadows(),
    );
