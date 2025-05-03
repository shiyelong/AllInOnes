import 'package:flutter/material.dart';
import '../common/animations.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? shadowColor;
  final bool animate;
  final Duration animationDuration;
  final VoidCallback? onTap;
  final Border? border;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.borderRadius,
    this.backgroundColor,
    this.shadowColor,
    this.animate = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.onTap,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: backgroundColor ?? Theme.of(context).cardColor,
      elevation: elevation ?? 2,
      shadowColor: shadowColor ?? Colors.black.withOpacity(0.2),
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: Container(
          padding: padding ?? EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: border,
          ),
          child: child,
        ),
      ),
    );

    final cardWithMargin = Container(
      margin: margin ?? EdgeInsets.all(8),
      child: card,
    );

    if (animate) {
      return AppAnimations.fadeInScale(
        duration: animationDuration,
        child: cardWithMargin,
      );
    }

    return cardWithMargin;
  }
}
