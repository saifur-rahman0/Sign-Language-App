import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/neu_theme.dart';

/// Collapsible neumorphic card showing API endpoint, last inference latency,
/// and server connection status.
class ModelInfoCard extends StatefulWidget {
  final String baseUrl;
  final int latencyMs;
  final ServerStatus serverStatus;

  const ModelInfoCard({
    super.key,
    required this.baseUrl,
    required this.latencyMs,
    required this.serverStatus,
  });

  @override
  State<ModelInfoCard> createState() => _ModelInfoCardState();
}

class _ModelInfoCardState extends State<ModelInfoCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _expanded ? _animCtrl.forward() : _animCtrl.reverse();
    });
  }

  Color get _statusColor {
    switch (widget.serverStatus) {
      case ServerStatus.online:
        return NeuColors.success;
      case ServerStatus.offline:
        return NeuColors.error;
      case ServerStatus.checking:
        return NeuColors.warning;
    }
  }

  String get _statusLabel {
    switch (widget.serverStatus) {
      case ServerStatus.online:
        return 'Online';
      case ServerStatus.offline:
        return 'Offline';
      case ServerStatus.checking:
        return 'Checking…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: NeuColors.background,
          borderRadius: BorderRadius.circular(20),
          boxShadow: neuRaisedShadows(depth: 0.8),
        ),
        child: Column(
          children: [
            // ── Header row ───────────────────────────────────────────
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
                  child: Icon(Icons.model_training_rounded,
                      size: 18, color: NeuColors.accent),
                ),
                const SizedBox(width: 12),
                Text(
                  'MODEL INFO',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: NeuColors.text,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                // Server status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeuColors.background,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: neuInsetShadows(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _statusColor,
                          boxShadow: [
                            BoxShadow(
                                color: _statusColor.withOpacity(0.5),
                                blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: NeuColors.textMuted),
                ),
              ],
            ),

            // ── Expandable detail rows ────────────────────────────────
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  _infoRow(Icons.link_rounded, 'Endpoint', widget.baseUrl),
                  const SizedBox(height: 12),
                  _infoRow(Icons.route_rounded, 'API Path',
                      '/predict-landmarks-focus'),
                  const SizedBox(height: 12),
                  _infoRow(
                    Icons.timer_outlined,
                    'Last Latency',
                    widget.latencyMs > 0
                        ? '${widget.latencyMs} ms'
                        : '—',
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.psychology_rounded, 'Explainability',
                      'Grad-CAM · Spatial + Temporal'),
                  const SizedBox(height: 12),
                  _infoRow(Icons.dataset_outlined, 'Dataset', 'BdSLW401'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: NeuColors.background,
            borderRadius: BorderRadius.circular(10),
            boxShadow: neuInsetShadows(),
          ),
          child: Icon(icon, size: 15, color: NeuColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NeuColors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
