import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/neu_theme.dart';

/// Bottom sheet that shows the last 10 recognition results stored locally.
/// Supports favorite toggling and filtering.
class HistoryPanel extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final VoidCallback onClear;
  final Set<int> favoriteIndices;
  final ValueChanged<int> onToggleFavorite;

  const HistoryPanel({
    super.key,
    required this.history,
    required this.onClear,
    required this.favoriteIndices,
    required this.onToggleFavorite,
  });

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  bool _showFavoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final filtered = _showFavoritesOnly
        ? widget.history
            .asMap()
            .entries
            .where((e) => widget.favoriteIndices.contains(e.key))
            .toList()
        : widget.history.asMap().entries.toList();

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
                    AppStrings.recognitionHistory,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: NeuColors.text,
                    ),
                  ),
                  const Spacer(),
                  if (widget.history.isNotEmpty)
                    GestureDetector(
                      onTap: widget.onClear,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: NeuColors.background,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: neuRaisedShadows(depth: 0.5),
                        ),
                        child: Text(
                          AppStrings.clearAll,
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

            // ── Filter tabs (All / Favorites) ────────────────────────
            if (widget.history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: AppStrings.all,
                      isSelected: !_showFavoritesOnly,
                      onTap: () => setState(() => _showFavoritesOnly = false),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '${AppStrings.favorites} (${widget.favoriteIndices.length})',
                      isSelected: _showFavoritesOnly,
                      onTap: () => setState(() => _showFavoritesOnly = true),
                      icon: Icons.star_rounded,
                    ),
                  ],
                ),
              ),

            // ── List / Empty ─────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final entry = filtered[i];
                        return _HistoryItem(
                          item: entry.value,
                          rank: entry.key + 1,
                          isFavorite: widget.favoriteIndices.contains(entry.key),
                          onToggleFavorite: () =>
                              widget.onToggleFavorite(entry.key),
                        );
                      },
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
          child: Icon(
            _showFavoritesOnly
                ? Icons.star_outline_rounded
                : Icons.history_toggle_off_rounded,
            size: 36,
            color: NeuColors.darkShadow,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _showFavoritesOnly
              ? (AppStrings.isBangla ? 'কোনো পছন্দের নেই' : 'No favorites yet')
              : AppStrings.noHistoryYet,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: NeuColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _showFavoritesOnly
              ? (AppStrings.isBangla ? 'আইটেমে তারকা চিহ্ন দিন' : 'Star items to save them here')
              : AppStrings.runToSeeResults,
          style: GoogleFonts.nunito(fontSize: 12, color: NeuColors.textMuted),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? NeuColors.accent : NeuColors.background,
          borderRadius: BorderRadius.circular(14),
          boxShadow:
              isSelected ? neuInsetShadows() : neuRaisedShadows(depth: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14,
                  color: isSelected ? Colors.white : NeuColors.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : NeuColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int rank;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _HistoryItem({
    required this.item,
    required this.rank,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

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
            width: 58,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(14),
              boxShadow: neuInsetShadows(),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item['bangla'] ?? '',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansBengali(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: NeuColors.accent,
                  ),
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
          // Favorite toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleFavorite();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: NeuColors.background,
                shape: BoxShape.circle,
                boxShadow: isFavorite
                    ? neuInsetShadows()
                    : neuRaisedShadows(depth: 0.4),
              ),
              child: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: isFavorite ? NeuColors.warning : NeuColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
