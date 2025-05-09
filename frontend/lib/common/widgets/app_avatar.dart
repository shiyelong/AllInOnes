import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/common/enhanced_file_utils.dart';

/// 应用头像组件
/// 提供统一的头像样式
class AppAvatar extends StatelessWidget {
  /// 头像URL
  final String? url;
  
  /// 头像大小
  final double size;
  
  /// 头像边框颜色
  final Color? borderColor;
  
  /// 头像边框宽度
  final double borderWidth;
  
  /// 头像背景色
  final Color? backgroundColor;
  
  /// 头像占位符文本
  final String? placeholderText;
  
  /// 头像占位符图标
  final IconData? placeholderIcon;
  
  /// 头像占位符图标大小
  final double? placeholderIconSize;
  
  /// 头像占位符图标颜色
  final Color? placeholderIconColor;
  
  /// 头像占位符文本样式
  final TextStyle? placeholderTextStyle;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 构造函数
  const AppAvatar({
    Key? key,
    this.url,
    this.size = 40,
    this.borderColor,
    this.borderWidth = 0,
    this.backgroundColor,
    this.placeholderText,
    this.placeholderIcon = Icons.person,
    this.placeholderIconSize,
    this.placeholderIconColor,
    this.placeholderTextStyle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 构建头像容器
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? theme.colorScheme.primary.withOpacity(0.1),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: _buildAvatarContent(theme),
    );
    
    // 如果有点击回调，添加点击效果
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: avatar,
      );
    }
    
    return avatar;
  }
  
  /// 构建头像内容
  Widget _buildAvatarContent(ThemeData theme) {
    // 如果URL为空，显示占位符
    if (url == null || url!.isEmpty) {
      return _buildPlaceholder(theme);
    }
    
    // 如果URL是本地文件路径，显示本地图片
    if (url!.startsWith('file://') || url!.startsWith('/')) {
      final filePath = EnhancedFileUtils.getValidFilePath(url!);
      if (filePath.isNotEmpty) {
        return ClipOval(
          child: Image.file(
            File(filePath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder(theme);
            },
          ),
        );
      }
      return _buildPlaceholder(theme);
    }
    
    // 如果URL是网络路径，显示网络图片
    if (url!.startsWith('http://') || url!.startsWith('https://')) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildLoading(),
          errorWidget: (context, url, error) => _buildPlaceholder(theme),
        ),
      );
    }
    
    // 其他情况显示占位符
    return _buildPlaceholder(theme);
  }
  
  /// 构建加载中状态
  Widget _buildLoading() {
    return Center(
      child: SizedBox(
        width: size / 2,
        height: size / 2,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
        ),
      ),
    );
  }
  
  /// 构建占位符
  Widget _buildPlaceholder(ThemeData theme) {
    // 如果有占位符文本，显示文本
    if (placeholderText != null && placeholderText!.isNotEmpty) {
      return Center(
        child: Text(
          placeholderText!.length > 2 ? placeholderText!.substring(0, 2) : placeholderText!,
          style: placeholderTextStyle ?? TextStyle(
            color: theme.colorScheme.primary,
            fontSize: size / 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    // 否则显示占位符图标
    return Center(
      child: Icon(
        placeholderIcon,
        size: placeholderIconSize ?? size / 2,
        color: placeholderIconColor ?? theme.colorScheme.primary,
      ),
    );
  }
}
