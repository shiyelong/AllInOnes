import 'package:flutter/material.dart';

/// 应用卡片组件
/// 提供统一的卡片样式
class AppCard extends StatelessWidget {
  /// 卡片内容
  final Widget child;
  
  /// 卡片标题
  final String? title;
  
  /// 卡片副标题
  final String? subtitle;
  
  /// 卡片右上角操作按钮
  final Widget? action;
  
  /// 卡片边距
  final EdgeInsetsGeometry? margin;
  
  /// 卡片内边距
  final EdgeInsetsGeometry? padding;
  
  /// 卡片阴影高度
  final double elevation;
  
  /// 卡片圆角
  final double borderRadius;
  
  /// 卡片背景色
  final Color? backgroundColor;
  
  /// 卡片边框颜色
  final Color? borderColor;
  
  /// 卡片边框宽度
  final double borderWidth;
  
  /// 卡片宽度
  final double? width;
  
  /// 卡片高度
  final double? height;
  
  /// 是否可点击
  final bool clickable;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 构造函数
  const AppCard({
    Key? key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.margin,
    this.padding,
    this.elevation = 1,
    this.borderRadius = 8,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.width,
    this.height,
    this.clickable = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 构建卡片内容
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null || action != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: action,
                  ),
              ],
            ),
          ),
        child,
      ],
    );
    
    // 构建卡片
    final card = Card(
      margin: margin ?? const EdgeInsets.all(0),
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: borderColor != null
            ? BorderSide(color: borderColor!, width: borderWidth)
            : BorderSide.none,
      ),
      color: backgroundColor,
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(16),
        child: content,
      ),
    );
    
    // 如果可点击，添加点击效果
    if (clickable) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }
    
    return card;
  }
}
