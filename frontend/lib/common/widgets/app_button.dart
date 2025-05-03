import 'package:flutter/material.dart';
import '../theme.dart';

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.color,
    this.textColor,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height,
    this.borderRadius = 12.0,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppTheme.primaryColor;
    final buttonTextColor = textColor ?? (isOutlined ? buttonColor : Colors.white);
    
    final buttonStyle = isOutlined
        ? OutlinedButton.styleFrom(
            side: BorderSide(color: buttonColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: padding ?? EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: padding ?? EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          );

    final buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(buttonTextColor),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, color: buttonTextColor),
          SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: buttonTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    final button = isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: buttonContent,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: buttonContent,
          );

    if (width != null || height != null) {
      return SizedBox(
        width: width,
        height: height,
        child: button,
      );
    }

    return button;
  }
}
