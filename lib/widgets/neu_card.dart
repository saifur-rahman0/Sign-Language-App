import 'package:flutter/material.dart';
import '../theme/neu_theme.dart';

/// Generic neumorphic container card.
class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool isInset;
  final double depth;

  const NeuCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.isInset = false,
    this.depth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            isInset ? neuInsetShadows() : neuRaisedShadows(depth: depth),
      ),
      child: child,
    );
  }
}
