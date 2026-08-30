import 'package:flutter/material.dart';

/// Clean LandmarkPainter for MediaPipe landmarks & Grad-CAM focus.
/// Draws heat-colored keypoints and hand attention bounding boxes without cluttering skeleton lines.
class LandmarkPainter extends CustomPainter {
  final List<dynamic> framePoints;
  final List<dynamic>? frameFocus;
  final double cam;

  LandmarkPainter(this.framePoints, {this.frameFocus, this.cam = 0.0});

  Color getHeat(double v) =>
      Color.lerp(const Color(0xFF2196F3), const Color(0xFFFF1744), v.clamp(0.0, 1.0))!;

  @override
  void paint(Canvas canvas, Size size) {
    if (framePoints.isEmpty) return;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    // ── 1. Temporal Video Border Focus (Grad-CAM CAM) ────────────────────────
    if (cam > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(24),
        ),
        Paint()
          ..color = getHeat(cam).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 + 8 * cam,
      );
    }

    const int faceCount = 52;
    const int handCount = 21;

    // Helper to get Offset for point index `p`
    Offset? getPoint(int p) {
      final idx = p * 3;
      if (idx + 1 >= framePoints.length) return null;
      final x = (framePoints[idx] as num).toDouble();
      final y = (framePoints[idx + 1] as num).toDouble();
      if (x <= 0 || y <= 0) return null;
      return Offset(x * size.width, y * size.height);
    }

    double getFocus(int p) {
      if (frameFocus != null && p < frameFocus!.length) {
        return (frameFocus![p] as num).toDouble();
      }
      return 0.15;
    }

    // ── 2. Draw Landmark Dots with Grad-CAM Heatmap Colors ───────────────────
    final totalPoints = framePoints.length ~/ 3;
    for (int p = 0; p < totalPoints; p++) {
      final pt = getPoint(p);
      if (pt == null) continue;

      final focus = getFocus(p);
      final radius = 2.0 + (6.0 * focus);
      final heatColor = getHeat(focus);

      dotPaint.color = heatColor.withValues(alpha: 0.85);
      canvas.drawCircle(pt, radius, dotPaint);
    }

    // ── 3. Hand Bounding Boxes with Attention Highlighting ───────────────────
    final lhStart = faceCount;
    final rhStart = faceCount + handCount;

    for (final startIdx in [lhStart, rhStart]) {
      double minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
      bool found = false;
      double avgFocus = 0.0;

      for (int i = 0; i < handCount; i++) {
        final pt = getPoint(startIdx + i);
        if (pt == null) continue;
        found = true;
        final nx = pt.dx / size.width;
        final ny = pt.dy / size.height;
        if (nx < minX) minX = nx;
        if (nx > maxX) maxX = nx;
        if (ny < minY) minY = ny;
        if (ny > maxY) maxY = ny;
        avgFocus += getFocus(startIdx + i);
      }

      if (found) {
        avgFocus /= handCount;
        final rect = Rect.fromLTRB(
          minX * size.width - 12,
          minY * size.height - 12,
          maxX * size.width + 12,
          maxY * size.height + 12,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 + (3.0 * avgFocus)
            ..color = getHeat(avgFocus).withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) => true;
}
