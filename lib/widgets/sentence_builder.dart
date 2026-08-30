import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/neu_theme.dart';

/// Neumorphic card that accumulates recognized words into a sentence.
///
/// Each word is shown as a removable chip. The action row allows
/// Copy, Share, Speak All, and Clear operations.
class SentenceBuilder extends StatelessWidget {
  final List<String> words;
  final VoidCallback onClear;
  final VoidCallback onSpeakAll;
  final VoidCallback onShare;
  final ValueChanged<int> onRemoveWord;

  const SentenceBuilder({
    super.key,
    required this.words,
    required this.onClear,
    required this.onSpeakAll,
    required this.onShare,
    required this.onRemoveWord,
  });

  void _copyToClipboard(BuildContext context) {
    final text = words.join(' ');
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
          // ── Header ──────────────────────────────────────────────────
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
                child: Icon(Icons.short_text_rounded,
                    size: 18, color: NeuColors.accent),
              ),
              const SizedBox(width: 12),
              Text(
                AppStrings.sentenceBuilder,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.text,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (words.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeuColors.background,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: neuInsetShadows(),
                  ),
                  child: Text(
                    '${words.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: NeuColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Words area ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: neuInsetShadows(),
            ),
            child: words.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        AppStrings.sentenceEmpty,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: NeuColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: words.asMap().entries.map((e) {
                      return _WordChip(
                        word: e.value,
                        onRemove: () => onRemoveWord(e.key),
                      );
                    }).toList(),
                  ),
          ),

          // ── Action row ─────────────────────────────────────────────
          if (words.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _ActionPill(
                  icon: Icons.volume_up_rounded,
                  label: AppStrings.speakAll,
                  onTap: onSpeakAll,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.copy_rounded,
                  label: AppStrings.copy,
                  onTap: () => _copyToClipboard(context),
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.share_rounded,
                  label: AppStrings.share,
                  onTap: onShare,
                ),
                const Spacer(),
                _ActionPill(
                  icon: Icons.delete_outline_rounded,
                  label: AppStrings.clearAll,
                  onTap: onClear,
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WordChip extends StatelessWidget {
  final String word;
  final VoidCallback onRemove;
  const _WordChip({required this.word, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: neuRaisedShadows(depth: 0.55),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: GoogleFonts.notoSansBengali(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: NeuColors.accent,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: NeuColors.background,
                shape: BoxShape.circle,
                boxShadow: neuInsetShadows(),
              ),
              child: Icon(Icons.close_rounded,
                  size: 11, color: NeuColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? NeuColors.error : NeuColors.accent;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: NeuColors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: neuRaisedShadows(depth: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
