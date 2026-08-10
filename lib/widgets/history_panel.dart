import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/neu_theme.dart';

/// Bottom sheet that shows the last 10 recognition results stored locally.
class HistoryPanel extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final VoidCallback onClear;

  const HistoryPanel({
    super.key,
    required this.history,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.30,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: NeuColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: NeuColors.darkShadow.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────────
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: NeuColors.darkShadow.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // ── Header row ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NeuColors.background,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: neuRaisedShadows(depth: 0.6),
                    ),
                    child: Icon(Icons.history_rounded, size: 20, color: NeuColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Recognition History',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: NeuColors.text,
                    ),
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    GestureDetector(
                      onTap: onClear,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: NeuColors.background,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: neuRaisedShadows(depth: 0.5),
                        ),
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NeuColors.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── List / Empty ─────────────────────────────────────────
            Expanded(
              child: history.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: history.length,
                      itemBuilder: (_, i) =>
                          _HistoryItem(item: history[i], rank: i + 1),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: NeuColors.background,
            shape: BoxShape.circle,
            boxShadow: neuInsetShadows(),
          ),
          child: Icon(Icons.history_toggle_off_rounded,
              size: 36, color: NeuColors.darkShadow),
        ),
        const SizedBox(height: 16),
        Text(
          'No history yet',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: NeuColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Run a recognition to see results here',
          style: GoogleFonts.nunito(fontSize: 12, color: NeuColors.textMuted),
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int rank;
  const _HistoryItem({required this.item, required this.rank});

  double _parseConf(dynamic raw) {
    final str = raw?.toString().replaceAll('%', '') ?? '0';
    return (double.tryParse(str) ?? 0.0) / 100.0;
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final conf = _parseConf(item['confidence']);
    final confColor = conf >= 0.70
        ? NeuColors.success
        : conf >= 0.40
            ? NeuColors.warning
            : NeuColors.error;
    final ts = item['timestamp'] != null
        ? DateTime.tryParse(item['timestamp'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: neuRaisedShadows(depth: 0.7),
      ),
      child: Row(
        children: [
          // Bangla inset badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(14),
              boxShadow: neuInsetShadows(),
            ),
            child: Center(
              child: Text(
                item['bangla'] ?? '',
                style: GoogleFonts.notoSansBengali(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: NeuColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['english']?.toString().toUpperCase() ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: NeuColors.text,
                  ),
                ),
                if (ts != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(ts),
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: NeuColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          // Confidence + rank
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(conf * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: confColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '#$rank',
                style: GoogleFonts.nunito(
                    fontSize: 11, color: NeuColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
