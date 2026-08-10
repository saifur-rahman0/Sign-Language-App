import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/neu_theme.dart';

/// A reusable neumorphic button that animates between raised and pressed states.
class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final double borderRadius;

  const NeuButton({
    super.key,
    required this.child,
    this.onTap,
    this.height = 60,
    this.borderRadius = 20,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  void _onDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    setState(() => _pressed = true);
  }

  void _onUp(TapUpDetails _) {
    if (widget.onTap == null) return;
    setState(() => _pressed = false);
    widget.onTap!();
  }

  void _onCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: _onDown,
      onTapUp: _onUp,
      onTapCancel: _onCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: widget.height,
        decoration: BoxDecoration(
          color: NeuColors.background,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow:
              (_pressed || disabled) ? neuInsetShadows() : neuRaisedShadows(depth: 0.9),
        ),
        child: Opacity(
          opacity: disabled ? 0.45 : 1.0,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
