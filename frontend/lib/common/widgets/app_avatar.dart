import 'package:flutter/material.dart';
import '../theme.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final String? url; // Added for backward compatibility

  const AppAvatar({
    Key? key,
    this.imageUrl,
    this.name = '',
    this.size = 40,
    this.backgroundColor,
    this.textColor,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
    this.onTap,
    this.url, // Added for backward compatibility
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultBackgroundColor = backgroundColor ??
        AppTheme.primaryColor.withOpacity(0.8);
    final defaultTextColor = textColor ?? Colors.white;

    // 获取名称的首字母
    final nameToUse = name ?? '';
    final initials = nameToUse.isNotEmpty
        ? nameToUse.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase()
        : '?';

    // 限制显示的字符数量
    final displayInitials = initials.length > 2 ? initials.substring(0, 2) : initials;

    Widget avatar;

    // Use url parameter if imageUrl is null
    final effectiveImageUrl = imageUrl ?? url;

    if (effectiveImageUrl != null && effectiveImageUrl.isNotEmpty) {
      // 显示图片头像
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          effectiveImageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 图片加载失败时显示文字头像
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: defaultBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  displayInitials,
                  style: TextStyle(
                    color: defaultTextColor,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      // 显示文字头像
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: defaultBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            displayInitials,
            style: TextStyle(
              color: defaultTextColor,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // 添加边框
    if (showBorder) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? AppTheme.primaryColor,
            width: borderWidth,
          ),
        ),
        child: avatar,
      );
    }

    // 添加点击事件
    if (onTap != null) {
      avatar = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: avatar,
      );
    }

    return avatar;
  }
}
