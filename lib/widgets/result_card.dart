import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/neu_theme.dart';

/// Clean single-word helper: converts 'বাবা/আব্বা' -> 'বাবা'
String cleanBangla(String word) {
  if (word.contains('/')) {
    return word.split('/').first.trim();
  }
  return word.trim();
}

/// Minimalist Neumorphic Result Card with Collapsible Dropdowns
/// for Top Predictions and Articulator Importance.
class ResultCard extends StatefulWidget {
  final Map<String, dynamic> prediction;
  final List<dynamic>? topPredictions;
  final List<dynamic>? allFramesFocus;
  final VoidCallback? onSpeak;
  final VoidCallback? onShare;

  const ResultCard({
    super.key,
    required this.prediction,
    this.topPredictions,
    this.allFramesFocus,
    this.onSpeak,
    this.onShare,
  });

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  bool _showTopPredictions = false;
  bool _showArticulator = false;

  double _parseConf(dynamic raw) {
    final str = raw?.toString().replaceAll('%', '') ?? '0';
    return (double.tryParse(str) ?? 0.0) / 100.0;
  }

  Color _confColor(double c) {
    if (c >= 0.70) return NeuColors.success;
    if (c >= 0.40) return NeuColors.warning;
    return NeuColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final conf = _parseConf(widget.prediction['confidence']);
    final rawBangla = widget.prediction['bangla']?.toString() ?? '';
    final bangla = cleanBangla(rawBangla);
    final english = widget.prediction['english']?.toString().toUpperCase() ?? '';
    final model = widget.prediction['model_used']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(26),
        boxShadow: neuRaisedShadows(depth: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header Strip (No Overflow) ─────────────────────────────
          _Header(model: model),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              children: [
                // ── Bangla Word (Clean, Single Word, No Wrapping) ────
                _BanglaDisplay(bangla: bangla),
                const SizedBox(height: 12),

                // ── English Label ────────────────────────────────────
                Text(
                  english,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: NeuColors.text,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Minimal Confidence Bar ──────────────────────────
                _ConfidenceBar(conf: conf, color: _confColor(conf)),
                const SizedBox(height: 8),

                // ── Inline: Percentage + Action Buttons ─────────────
                _InlineConfActions(
                  conf: conf,
                  confColor: _confColor(conf),
                  bangla: bangla,
                  english: english,
                  onSpeak: widget.onSpeak,
                  onShare: widget.onShare,
                ),

                // ── Collapsible Top Predictions Dropdown ──────────────
                if (widget.topPredictions != null &&
                    widget.topPredictions!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _CollapsibleSection(
                    title: AppStrings.topPredictions,
                    icon: Icons.bar_chart_rounded,
                    isExpanded: _showTopPredictions,
                    onToggle: () => setState(
                        () => _showTopPredictions = !_showTopPredictions),
                    child: _Top5Chart(
                      tops: widget.topPredictions!,
                      parseConf: _parseConf,
                    ),
                  ),
                ],

                // ── Collapsible Articulator Importance Dropdown ───────
                if (widget.allFramesFocus != null &&
                    widget.allFramesFocus!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _CollapsibleSection(
                    title: AppStrings.articulatorBreakdown,
                    icon: Icons.accessibility_new_rounded,
                    isExpanded: _showArticulator,
                    onToggle: () => setState(
                        () => _showArticulator = !_showArticulator),
                    child: _ArticulatorBars(allFocus: widget.allFramesFocus!),
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
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Header strip with zero overflow and compact model pill
class _Header extends StatelessWidget {
  final String? model;
  const _Header({this.model});

  String _cleanModel(String m) {
    var s = m.replaceAll('(Offline Engine)', '· Offline');
    s = s.replaceAll('transformer_', 'TR-');
    s = s.replaceAll('cnn_', 'CNN-');
    s = s.replaceAll('interpolated_', 'Int-');
    s = s.replaceAll('_frontview', '-Front');
    s = s.replaceAll('_multiview', '-Multi');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NeuColors.accent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Row(
        children: [
          Icon(Icons.sign_language_rounded,
              size: 16, color: Colors.white.withOpacity(0.95)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppStrings.predictedGesture,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
          if (model != null) ...[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 130),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _cleanModel(model!),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.nunito(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bangla display container with auto-scaling to prevent multiline breaks
class _BanglaDisplay extends StatelessWidget {
  final String bangla;
  const _BanglaDisplay({required this.bangla});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: neuInsetShadows(),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            bangla,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansBengali(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: NeuColors.accent,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Confidence progress bar
class _ConfidenceBar extends StatelessWidget {
  final double conf;
  final Color color;
  const _ConfidenceBar({required this.conf, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.confidence,
              style: GoogleFonts.nunito(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: NeuColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
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
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                height: 12,
                width: constraints.maxWidth * conf.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
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
      ],
    );
  }
}

/// Inline row: Confidence % on the left, compact icon buttons on the right
class _InlineConfActions extends StatelessWidget {
  final double conf;
  final Color confColor;
  final String bangla;
  final String english;
  final VoidCallback? onSpeak;
  final VoidCallback? onShare;

  const _InlineConfActions({
    required this.conf,
    required this.confColor,
    required this.bangla,
    required this.english,
    this.onSpeak,
    this.onShare,
  });

  void _copy(BuildContext context) {
    final text = '$bangla — $english (${(conf * 100).toStringAsFixed(1)}%)';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.copied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        backgroundColor: NeuColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Confidence Percentage ──
        Text(
          '${(conf * 100).toStringAsFixed(1)}%',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: confColor,
          ),
        ),
        const Spacer(),
        // ── Compact Icon Buttons ──
        _MiniAction(
          icon: Icons.volume_up_rounded,
          tooltip: AppStrings.speak,
          onTap: onSpeak,
        ),
        const SizedBox(width: 10),
        _MiniAction(
          icon: Icons.copy_rounded,
          tooltip: AppStrings.copy,
          onTap: () => _copy(context),
        ),
        const SizedBox(width: 10),
        _MiniAction(
          icon: Icons.share_rounded,
          tooltip: AppStrings.share,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _MiniAction({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap!();
          }
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: NeuColors.background,
            shape: BoxShape.circle,
            boxShadow: neuRaisedShadows(depth: 0.45),
          ),
          child: Icon(icon, size: 15, color: NeuColors.accent),
        ),
      ),
    );
  }
}

/// Collapsible accordion container for Top Predictions & Articulator
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isExpanded ? neuInsetShadows() : neuRaisedShadows(depth: 0.4),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: NeuColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: NeuColors.text,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: NeuColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 0.8),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

/// Top-5 chart inside collapsible dropdown
class _Top5Chart extends StatelessWidget {
  final List<dynamic> tops;
  final double Function(dynamic) parseConf;

  const _Top5Chart({required this.tops, required this.parseConf});

  @override
  Widget build(BuildContext context) {
    final items = tops.take(5).toList();
    return Column(
      children: items.map((item) {
        final map = item as Map<String, dynamic>;
        final c = parseConf(map['confidence']);
        final label = map['english']?.toString() ?? '—';
        final rawBangla = map['bangla']?.toString() ?? '';
        final bangla = cleanBangla(rawBangla);

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: neuInsetShadows(),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        bangla,
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.notoSansBengali(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: NeuColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: NeuColors.background,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: neuInsetShadows(),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: c.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: NeuColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '${(c * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NeuColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Articulator breakdown inside collapsible dropdown
class _ArticulatorBars extends StatelessWidget {
  final List<dynamic> allFocus;
  const _ArticulatorBars({required this.allFocus});

  @override
  Widget build(BuildContext context) {
    double faceSum = 0, lhSum = 0, rhSum = 0, poseSum = 0;
    int frameCount = 0;

    for (final frame in allFocus) {
      if (frame is! List) continue;
      frameCount++;
      for (int i = 0; i < frame.length; i++) {
        final v = (frame[i] as num).toDouble();
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

    if (frameCount == 0) return const SizedBox.shrink();

    final raw = {
      AppStrings.face: faceSum / frameCount,
      AppStrings.leftHand: lhSum / frameCount,
      AppStrings.rightHand: rhSum / frameCount,
      AppStrings.pose: poseSum / frameCount,
    };

    final total = raw.values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return const SizedBox.shrink();

    final norm = raw.map((k, v) => MapEntry(k, v / total));
    final sorted = norm.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 65,
                child: Text(
                  e.key,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.text,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: NeuColors.background,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: neuInsetShadows(),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: e.value.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: NeuColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '${(e.value * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NeuColors.accent,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
