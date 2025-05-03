import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double elevation;
  final VoidCallback? onTap;
  final BoxBorder? border;

  const AppCard({
    Key? key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.borderRadius = 12.0,
    this.elevation = 1.0,
    this.onTap,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final card = Card(
      color: color ?? (isDarkMode ? Colors.grey.shade800 : Colors.white),
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: border != null 
            ? BorderSide.none 
            : BorderSide(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                width: 1,
              ),
      ),
      margin: margin ?? EdgeInsets.zero,
      child: Container(
        decoration: border != null
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: border,
              )
            : null,
        padding: padding ?? EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }

    return card;
  }
}
