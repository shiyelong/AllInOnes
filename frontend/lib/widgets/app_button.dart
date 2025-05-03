import 'package:flutter/material.dart';
import '../common/theme.dart';

enum AppButtonType { primary, secondary, outline, text, danger }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color; // 添加自定义颜色
  final double? minWidth; // 添加最小宽度

  const AppButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.color, // 添加自定义颜色参数
    this.minWidth, // 添加最小宽度参数
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 根据类型确定颜色
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    // 如果提供了自定义颜色，优先使用自定义颜色
    if (color != null) {
      backgroundColor = color!;
      textColor = Colors.white;
      borderColor = Colors.transparent;
    } else {
      // 否则根据类型确定颜色
      switch (type) {
        case AppButtonType.primary:
          backgroundColor = AppTheme.primaryColor;
          textColor = Colors.white;
          borderColor = Colors.transparent;
          break;
        case AppButtonType.secondary:
          backgroundColor = AppTheme.accentColor;
          textColor = Colors.white;
          borderColor = Colors.transparent;
          break;
        case AppButtonType.outline:
          backgroundColor = Colors.transparent;
          textColor = AppTheme.primaryColor;
          borderColor = AppTheme.primaryColor;
          break;
        case AppButtonType.text:
          backgroundColor = Colors.transparent;
          textColor = AppTheme.primaryColor;
          borderColor = Colors.transparent;
          break;
        case AppButtonType.danger:
          backgroundColor = AppTheme.errorColor;
          textColor = Colors.white;
          borderColor = Colors.transparent;
          break;
      }
    }

    // 根据尺寸确定大小
    double buttonHeight;
    double fontSize;
    EdgeInsetsGeometry buttonPadding;

    switch (size) {
      case AppButtonSize.small:
        buttonHeight = 32;
        fontSize = 12;
        buttonPadding = EdgeInsets.symmetric(horizontal: 12);
        break;
      case AppButtonSize.medium:
        buttonHeight = 44;
        fontSize = 14;
        buttonPadding = EdgeInsets.symmetric(horizontal: 16);
        break;
      case AppButtonSize.large:
        buttonHeight = 52;
        fontSize = 16;
        buttonPadding = EdgeInsets.symmetric(horizontal: 24);
        break;
    }

    // 构建按钮内容
    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
              width: fontSize,
              height: fontSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(icon, size: fontSize + 2, color: textColor),
          ),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );

    // 构建按钮
    return Container(
      width: fullWidth ? double.infinity : width,
      height: height ?? buttonHeight,
      constraints: minWidth != null ? BoxConstraints(minWidth: minWidth!) : null,
      child: Material(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: Container(
            padding: padding ?? buttonPadding,
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: type == AppButtonType.outline ? 1.5 : 0,
              ),
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            ),
            child: Center(child: buttonContent),
          ),
        ),
      ),
    );
  }
}
