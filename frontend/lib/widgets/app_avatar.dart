import 'package:flutter/material.dart';
import 'dart:convert';
import '../common/theme.dart';
import '../common/text_sanitizer.dart';
import '../common/api.dart';

enum AvatarType { circle, rounded }

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final AvatarType type;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Widget? badge;
  final Alignment badgeAlignment;
  final String? base64Image;
  final bool isGroup;
  final bool isOnline;

  const AppAvatar({
    Key? key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.type = AvatarType.circle,
    this.backgroundColor,
    this.textColor,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
    this.base64Image,
    this.isGroup = false,
    this.isOnline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 确定形状
    final borderRadius = type == AvatarType.circle
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(size / 5);

    // 确定背景色
    final bgColor = backgroundColor ??
        (isGroup
            ? AppTheme.primaryColor.withOpacity(0.2)
            : (name != null && name!.isNotEmpty
                ? _getColorFromName(name!)
                : AppTheme.primaryColor));

    // 确定文本颜色
    final txtColor = textColor ?? Colors.white;

    // 构建头像内容
    Widget avatarContent;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // 确保图片URL是完整的URL
      String processedUrl = imageUrl!;

      // 处理不同类型的路径
      if (imageUrl!.startsWith('/api/') || imageUrl!.startsWith('/uploads/')) {
        // 相对路径，添加基础URL
        processedUrl = Api.getFullUrl(imageUrl!);
        debugPrint('[AppAvatar] 图片路径已转换为完整URL: $imageUrl -> $processedUrl');
      } else if (!imageUrl!.startsWith('http://') && !imageUrl!.startsWith('https://') &&
                !imageUrl!.startsWith('file://') && !imageUrl!.startsWith('/')) {
        // 可能是相对路径但没有前导斜杠，添加斜杠和基础URL
        processedUrl = Api.getFullUrl('/$imageUrl');
        debugPrint('[AppAvatar] 图片路径已转换为完整URL(添加斜杠): $imageUrl -> $processedUrl');
      }

      avatarContent = ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          processedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('[AppAvatar] 图片加载失败: $error, URL: $processedUrl');

            // 如果加载失败，尝试使用不同的路径格式
            if (processedUrl.contains('/api/static/')) {
              // 尝试将 /api/static/ 替换为 /uploads/
              final alternativeUrl = processedUrl.replaceFirst('/api/static/', '/uploads/');
              debugPrint('[AppAvatar] 尝试替代URL: $alternativeUrl');

              return Image.network(
                alternativeUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('[AppAvatar] 替代URL也加载失败: $error');
                  return _buildNameAvatar(bgColor, txtColor, borderRadius);
                },
              );
            }

            return _buildNameAvatar(bgColor, txtColor, borderRadius);
          },
        ),
      );
    } else if (base64Image != null && base64Image!.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Image!);
        avatarContent = ClipRRect(
          borderRadius: borderRadius,
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildNameAvatar(bgColor, txtColor, borderRadius);
            },
          ),
        );
      } catch (e) {
        avatarContent = _buildNameAvatar(bgColor, txtColor, borderRadius);
      }
    } else {
      avatarContent = _buildNameAvatar(bgColor, txtColor, borderRadius);
    }

    // 添加边框
    if (showBorder) {
      avatarContent = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: borderColor ?? AppTheme.primaryColor,
            width: borderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    // 添加徽章或在线状态或群组标识
    List<Widget> stackChildren = [avatarContent];

    // 添加在线状态指示器
    if (isOnline && !isGroup) {
      stackChildren.add(
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
          ),
        ),
      );
    }

    // 添加群组标识
    if (isGroup && (imageUrl != null || base64Image != null)) {
      stackChildren.add(
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.group,
              size: size * 0.25,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // 添加自定义徽章
    if (badge != null) {
      stackChildren.add(
        Positioned(
          right: badgeAlignment.x > 0 ? -4 : null,
          left: badgeAlignment.x < 0 ? -4 : null,
          top: badgeAlignment.y < 0 ? -4 : null,
          bottom: badgeAlignment.y > 0 ? -4 : null,
          child: badge!,
        ),
      );
    }

    // 如果有多个子元素，使用Stack
    if (stackChildren.length > 1) {
      avatarContent = Stack(
        clipBehavior: Clip.none,
        children: stackChildren,
      );
    }

    // 添加点击效果
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  // 构建基于名称的头像
  Widget _buildNameAvatar(Color bgColor, Color txtColor, BorderRadius borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: isGroup
            ? Icon(
                Icons.group,
                size: size * 0.5,
                color: AppTheme.primaryColor,
              )
            : Text(
                _getInitials(name ?? '?'),
                style: TextStyle(
                  color: txtColor,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                ),
              ),
      ),
    );
  }

  // 获取名称首字母
  String _getInitials(String name) {
    // 清理名称，确保它是有效的 UTF-16 字符串
    final sanitizedName = TextSanitizer.sanitize(name);
    if (sanitizedName.isEmpty) return '?';

    final parts = sanitizedName.trim().split(' ');
    if (parts.length > 1) {
      // 确保每个部分都有字符
      if (parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
    }

    // 确保名称有字符
    if (sanitizedName.isNotEmpty) {
      return sanitizedName[0].toUpperCase();
    }

    return '?';
  }

  // 从名称生成颜色
  Color _getColorFromName(String name) {
    final colors = [
      Color(0xFF1E88E5), // 蓝色
      Color(0xFF43A047), // 绿色
      Color(0xFFE53935), // 红色
      Color(0xFF5E35B1), // 紫色
      Color(0xFFFFB300), // 琥珀色
      Color(0xFF00ACC1), // 青色
      Color(0xFF3949AB), // 靛蓝色
      Color(0xFF8E24AA), // 紫色
      Color(0xFFD81B60), // 粉色
      Color(0xFF7CB342), // 浅绿色
    ];

    // 清理名称，确保它是有效的 UTF-16 字符串
    final sanitizedName = TextSanitizer.sanitize(name);
    if (sanitizedName.isEmpty) {
      return colors[0]; // 默认颜色
    }

    int hashCode = 0;
    for (int i = 0; i < sanitizedName.length; i++) {
      try {
        hashCode += sanitizedName.codeUnitAt(i);
      } catch (e) {
        // 如果出现错误，使用默认值
        continue;
      }
    }

    return colors[hashCode % colors.length];
  }
}
