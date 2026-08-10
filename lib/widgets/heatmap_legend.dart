import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/neu_theme.dart';

/// Grad-CAM heatmap legend in neumorphic style.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: neuRaisedShadows(depth: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 14, color: NeuColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'GRAD-CAM ATTENTION MAP',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Gradient bar (inset style)
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              boxShadow: neuInsetShadows(),
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple, Colors.red],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Low Focus',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: Colors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'High Focus',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend description (inset info box)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(12),
              boxShadow: neuInsetShadows(),
            ),
            child: Text(
              '• Boxes / Points – Spatial focus (hand landmark importance)\n'
              '• Video border – Temporal focus (frame importance)',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: NeuColors.textMuted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
