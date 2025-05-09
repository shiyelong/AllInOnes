import 'package:flutter/material.dart';

/// 应用按钮组件
/// 提供统一的按钮样式
class AppButton extends StatelessWidget {
  /// 按钮文本
  final String text;

  /// 按钮点击回调
  final VoidCallback? onPressed;

  /// 按钮类型
  final AppButtonType type;

  /// 按钮大小
  final AppButtonSize size;

  /// 按钮宽度
  final double? width;

  /// 按钮高度
  final double? height;

  /// 按钮图标
  final IconData? icon;

  /// 是否显示加载状态
  final bool isLoading;

  /// 自定义子组件
  final Widget? child;

  /// 按钮颜色
  final Color? color;

  /// 构造函数
  const AppButton({
    Key? key,
    this.text = '',
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.width,
    this.height,
    this.icon,
    this.isLoading = false,
    this.child,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 根据按钮类型获取颜色
    final colors = _getButtonColors(context);

    // 根据按钮大小获取尺寸
    final sizes = _getButtonSizes();

    // 构建按钮内容
    Widget content = child ?? Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null && !isLoading) ...[
          Icon(icon, size: sizes.iconSize, color: colors.foregroundColor),
          SizedBox(width: 8),
        ],
        if (isLoading) ...[
          SizedBox(
            width: sizes.iconSize,
            height: sizes.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.foregroundColor),
            ),
          ),
          SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: sizes.fontSize,
            fontWeight: FontWeight.w500,
            color: colors.foregroundColor,
          ),
        ),
      ],
    );

    // 构建按钮
    return SizedBox(
      width: width,
      height: height ?? sizes.height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.backgroundColor,
          foregroundColor: colors.foregroundColor,
          disabledBackgroundColor: colors.disabledBackgroundColor,
          disabledForegroundColor: colors.disabledForegroundColor,
          elevation: type == AppButtonType.flat ? 0 : 2,
          padding: EdgeInsets.symmetric(
            horizontal: sizes.horizontalPadding,
            vertical: sizes.verticalPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizes.borderRadius),
            side: type == AppButtonType.outline
                ? BorderSide(color: colors.borderColor)
                : BorderSide.none,
          ),
        ),
        child: content,
      ),
    );
  }

  /// 获取按钮颜色
  _ButtonColors _getButtonColors(BuildContext context) {
    final theme = Theme.of(context);

    // 如果提供了自定义颜色，优先使用自定义颜色
    if (color != null) {
      return _ButtonColors(
        backgroundColor: color!,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color!.withOpacity(0.5),
        disabledForegroundColor: Colors.white.withOpacity(0.7),
        borderColor: color!,
      );
    }

    switch (type) {
      case AppButtonType.primary:
        return _ButtonColors(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.primaryColor.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.7),
          borderColor: theme.primaryColor,
        );
      case AppButtonType.secondary:
        return _ButtonColors(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.colorScheme.secondary.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.7),
          borderColor: theme.colorScheme.secondary,
        );
      case AppButtonType.outline:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          foregroundColor: theme.primaryColor,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: theme.primaryColor.withOpacity(0.5),
          borderColor: theme.primaryColor,
        );
      case AppButtonType.flat:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          foregroundColor: theme.primaryColor,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: theme.primaryColor.withOpacity(0.5),
          borderColor: Colors.transparent,
        );
      case AppButtonType.danger:
        return _ButtonColors(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.red.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.7),
          borderColor: Colors.red,
        );
    }
  }

  /// 获取按钮尺寸
  _ButtonSizes _getButtonSizes() {
    switch (size) {
      case AppButtonSize.small:
        return _ButtonSizes(
          height: 32,
          horizontalPadding: 12,
          verticalPadding: 6,
          fontSize: 12,
          iconSize: 16,
          borderRadius: 4,
        );
      case AppButtonSize.medium:
        return _ButtonSizes(
          height: 40,
          horizontalPadding: 16,
          verticalPadding: 8,
          fontSize: 14,
          iconSize: 18,
          borderRadius: 6,
        );
      case AppButtonSize.large:
        return _ButtonSizes(
          height: 48,
          horizontalPadding: 20,
          verticalPadding: 10,
          fontSize: 16,
          iconSize: 20,
          borderRadius: 8,
        );
    }
  }
}

/// 按钮类型
enum AppButtonType {
  /// 主要按钮
  primary,

  /// 次要按钮
  secondary,

  /// 轮廓按钮
  outline,

  /// 扁平按钮
  flat,

  /// 危险按钮
  danger,
}

/// 按钮大小
enum AppButtonSize {
  /// 小按钮
  small,

  /// 中按钮
  medium,

  /// 大按钮
  large,
}

/// 按钮颜色
class _ButtonColors {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color disabledBackgroundColor;
  final Color disabledForegroundColor;
  final Color borderColor;

  _ButtonColors({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.disabledBackgroundColor,
    required this.disabledForegroundColor,
    required this.borderColor,
  });
}

/// 按钮尺寸
class _ButtonSizes {
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double iconSize;
  final double borderRadius;

  _ButtonSizes({
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontSize,
    required this.iconSize,
    required this.borderRadius,
  });
}
