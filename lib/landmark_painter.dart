import 'package:flutter/material.dart';

class LandmarkPainter extends CustomPainter {
  final List<dynamic> framePoints;
  final List<dynamic>? frameFocus;
  final double cam;

  LandmarkPainter(this.framePoints, {this.frameFocus, this.cam = 0.0});

  Color getHeat(double v) => Color.lerp(Colors.blue, Colors.red, v.clamp(0.0, 1.0))!;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    
    // Temporal Border Focus
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = getHeat(cam).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + 10 * cam,
    );

    const int facePoints = 52;
    // Draw landmarks with spatial focus (Grad-CAM)
    for (int i = 0, p = 0; i < framePoints.length; i += 3, p++) {
      final x = (framePoints[i] as num).toDouble() * size.width;
      final y = (framePoints[i + 1] as num).toDouble() * size.height;
      if (x <= 0 || y <= 0) continue;

      double focus = (frameFocus != null && p < frameFocus!.length) 
          ? (frameFocus![p] as num).toDouble() 
          : 0.0;
      
      canvas.drawCircle(
        Offset(x, y), 
        2.0 + (8.0 * focus), 
        paint..color = getHeat(focus).withOpacity(0.8),
      );
    }

    // Hand Bounding Boxes with attention highlighting
    for (var startIdx in [facePoints, facePoints + 21]) {
      double minX = 1, minY = 1, maxX = 0, maxY = 0;
      bool found = false;
      double avgFocus = 0;
      for (int i = 0; i < 21; i++) {
        int idx = (startIdx + i) * 3;
        if (idx + 1 >= framePoints.length) continue;
        double x = (framePoints[idx] as num).toDouble();
        double y = (framePoints[idx + 1] as num).toDouble();
        if (x <= 0 || y <= 0) continue;
        found = true;
        minX = x < minX ? x : minX; minY = y < minY ? y : minY;
        maxX = x > maxX ? x : maxX; maxY = y > maxY ? y : maxY;
        if (frameFocus != null) avgFocus += (frameFocus![startIdx + i] as num).toDouble();
      }
      if (found) {
        avgFocus /= 21;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(minX * size.width - 15, minY * size.height - 15, maxX * size.width + 15, maxY * size.height + 15), 
            const Radius.circular(12),
          ),
          paint..style = PaintingStyle.stroke..strokeWidth = 2 + 4 * avgFocus..color = getHeat(avgFocus),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) => true;
}
