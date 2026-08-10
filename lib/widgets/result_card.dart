import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/neu_theme.dart';

/// Neumorphic result card.
/// Displays the predicted Bangla sign word, English translation,
/// an animated confidence bar, and an optional top-N predictions chart.
class ResultCard extends StatelessWidget {
  final Map<String, dynamic> prediction;
  final List<dynamic>? topPredictions;

  const ResultCard({
    super.key,
    required this.prediction,
    this.topPredictions,
  });

  // ── helpers ─────────────────────────────────────────────────────────────
  double _parseConf(dynamic raw) {
    final str = raw?.toString().replaceAll('%', '') ?? '0';
    return (double.tryParse(str) ?? 0.0) / 100.0;
  }

  Color _confColor(double c) {
    if (c >= 0.70) return NeuColors.success;
    if (c >= 0.40) return NeuColors.warning;
    return NeuColors.error;
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final conf    = _parseConf(prediction['confidence']);
    final bangla  = prediction['bangla']?.toString()  ?? '';
    final english = prediction['english']?.toString().toUpperCase() ?? '';
    final model   = prediction['model_used']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(28),
        boxShadow: neuRaisedShadows(depth: 1.2),
      ),
      child: Column(
        children: [
          // ── Header strip ────────────────────────────────────────────────
          _Header(model: model),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                // ── Bangla word ───────────────────────────────────────────
                _BanglaDisplay(bangla: bangla),
                const SizedBox(height: 16),

                // ── English label ─────────────────────────────────────────
                Text(
                  english,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    color: NeuColors.text,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Confidence ────────────────────────────────────────────
                _ConfidenceBar(conf: conf, color: _confColor(conf)),
                const SizedBox(height: 4),
                Text(
                  '${(conf * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _confColor(conf),
                  ),
                ),

                // ── Top-N predictions ─────────────────────────────────────
                if (topPredictions != null && topPredictions!.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _Top5Chart(
                    tops: topPredictions!,
                    parseConf: _parseConf,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets (private)
// ─────────────────────────────────────────────────────────────────────────────

/// Coloured top strip: "PREDICTED GESTURE" + optional model pill.
class _Header extends StatelessWidget {
  final String? model;
  const _Header({this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: NeuColors.accent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Icon(Icons.sign_language_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 10),
          Text(
            'PREDICTED GESTURE',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (model != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _shortModel(model!),
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortModel(String m) {
    if (m.startsWith('transformer')) return m.replaceFirst('transformer_', 'TR·');
    if (m.startsWith('cnn')) return m.replaceFirst('cnn_', 'CNN·');
    return m;
  }
}

/// Full-width inset container showing the Bangla sign word.
/// Uses [FittedBox] so the text never overflows regardless of word length.
class _BanglaDisplay extends StatelessWidget {
  final String bangla;
  const _BanglaDisplay({required this.bangla});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: neuInsetShadows(),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          bangla,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansBengali(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: NeuColors.accent,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

/// Animated neumorphic confidence progress bar.
class _ConfidenceBar extends StatelessWidget {
  final double conf;
  final Color color;
  const _ConfidenceBar({required this.conf, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONFIDENCE',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: NeuColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Inset track + animated fill
        Stack(
          children: [
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: NeuColors.background,
                borderRadius: BorderRadius.circular(8),
                boxShadow: neuInsetShadows(),
              ),
            ),
            LayoutBuilder(
              builder: (ctx, constraints) => AnimatedContainer(
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                height: 16,
                width: constraints.maxWidth * conf,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.65),
                      color,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Animated top-N horizontal bar chart.
class _Top5Chart extends StatelessWidget {
  final List<dynamic> tops;
  final double Function(dynamic) parseConf;

  const _Top5Chart({required this.tops, required this.parseConf});

  @override
  Widget build(BuildContext context) {
    final items = tops.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: NeuColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TOP PREDICTIONS',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: NeuColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...items.asMap().entries.map((e) {
          final item = e.value as Map<String, dynamic>;
          final c     = parseConf(item['confidence']);
          final label = item['english']?.toString() ?? '—';
          final bangla = item['bangla']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              children: [
                // Bangla in small inset badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: NeuColors.background,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: neuInsetShadows(),
                  ),
                  child: Center(
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          bangla,
                          style: GoogleFonts.notoSansBengali(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: NeuColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // English label
                SizedBox(
                  width: 72,
                  child: Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: NeuColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Animated bar
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: NeuColors.background,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: neuInsetShadows(),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (ctx, constraints) => AnimatedContainer(
                          duration: Duration(milliseconds: 500 + e.key * 100),
                          curve: Curves.easeOutCubic,
                          height: 10,
                          width: constraints.maxWidth * c,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: NeuColors.accent
                                .withOpacity(0.55 + 0.45 * c),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(c * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
