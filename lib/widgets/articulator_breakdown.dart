import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/neu_theme.dart';

/// Displays a horizontal bar chart showing which anatomical region
/// (Face, Left Hand, Right Hand, Pose) drove the prediction.
///
/// Computed client-side from `focus_points` landmark data:
/// - Landmarks 0–51  → Face (52 points)
/// - Landmarks 52–72 → Left Hand (21 points)
/// - Landmarks 73–93 → Right Hand (21 points)
/// - Landmarks 94+   → Pose (remaining points)
class ArticulatorBreakdown extends StatelessWidget {
  /// Raw focus_points from a single frame — a flat list of per-landmark
  /// importance values in [0..1]. We compute the average across all frames
  /// that are passed in (typically the frame-level `focus_points` list).
  final List<dynamic>? allFramesFocus;

  const ArticulatorBreakdown({super.key, required this.allFramesFocus});

  @override
  Widget build(BuildContext context) {
    if (allFramesFocus == null || allFramesFocus!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Compute average importance per region across all frames
    final regions = _computeRegions(allFramesFocus!);
    if (regions.isEmpty) return const SizedBox.shrink();

    // Normalise to sum = 1.0
    final total = regions.values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return const SizedBox.shrink();

    final normalised = regions.map((k, v) => MapEntry(k, v / total));
    final sorted = normalised.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: neuRaisedShadows(depth: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: neuRaisedShadows(depth: 0.6),
                ),
                child: Icon(Icons.accessibility_new_rounded,
                    size: 18, color: NeuColors.accent),
              ),
              const SizedBox(width: 12),
              Text(
                AppStrings.articulatorBreakdown,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.text,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Bars ──────────────────────────────────────────────────
          ...sorted.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RegionBar(
                  label: entry.key,
                  value: entry.value,
                  icon: _iconForRegion(entry.key),
                ),
              )),
        ],
      ),
    );
  }

  /// Average focus for each anatomical region across all frames.
  Map<String, double> _computeRegions(List<dynamic> allFocus) {
    // allFocus is a List<List<dynamic>> — one list per frame.
    // Each inner list has per-landmark importance values.
    double faceSum = 0, lhSum = 0, rhSum = 0, poseSum = 0;
    int frameCount = 0;

    for (final frameFocus in allFocus) {
      if (frameFocus is! List) continue;
      frameCount++;
      final pts = frameFocus;
      for (int i = 0; i < pts.length; i++) {
        final v = (pts[i] as num).toDouble();
        if (i < 52) {
          faceSum += v;
        } else if (i < 73) {
          lhSum += v;
        } else if (i < 94) {
          rhSum += v;
        } else {
          poseSum += v;
        }
      }
    }

    if (frameCount == 0) return {};

    return {
      AppStrings.face: faceSum / frameCount,
      AppStrings.leftHand: lhSum / frameCount,
      AppStrings.rightHand: rhSum / frameCount,
      AppStrings.pose: poseSum / frameCount,
    };
  }

  IconData _iconForRegion(String label) {
    if (label == AppStrings.face) return Icons.face_outlined;
    if (label == AppStrings.leftHand) return Icons.back_hand_outlined;
    if (label == AppStrings.rightHand) return Icons.front_hand_outlined;
    return Icons.accessibility_new_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RegionBar extends StatelessWidget {
  final String label;
  final double value; // 0.0 – 1.0
  final IconData icon;

  const _RegionBar({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: NeuColors.background,
            borderRadius: BorderRadius.circular(9),
            boxShadow: neuRaisedShadows(depth: 0.5),
          ),
          child: Icon(icon, size: 16, color: NeuColors.accent),
        ),
        const SizedBox(width: 10),
        // Label
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NeuColors.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Bar
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: neuInsetShadows(),
                ),
              ),
              LayoutBuilder(
                builder: (ctx, constraints) => AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  height: 12,
                  width: constraints.maxWidth * value.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [
                        NeuColors.accent.withOpacity(0.5),
                        NeuColors.accent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Percentage
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NeuColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}
