import 'package:flutter/material.dart';
import 'package:frontend/common/persistence.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../common/theme_manager.dart';
import '../../../common/text_sanitizer.dart';

/// 专门为"我的设备"聊天设计的消息项组件
/// 移除了红包功能，并优化了媒体显示
class SelfChatMessageItem extends StatelessWidget {
  final Map<String, dynamic> message;
  const SelfChatMessageItem({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = Persistence.getUserInfo()?.id ?? 0;
    final isMe = message['from_id'] == currentUserId;
    final type = message['type'] ?? 'text';
    final rawContent = message['content'] ?? '';
    // 清理消息内容
    final content = TextSanitizer.sanitize(rawContent);
    final timestamp = message['created_at'] ?? 0;
    final status = message['status'] ?? 1; // 默认为已发送

    // 获取主题颜色
    final theme = ThemeManager.currentTheme;
    final bubbleColor = isMe ? theme.selfMessageBubbleColor : theme.otherMessageBubbleColor;
    final textColor = isMe ? theme.selfMessageTextColor : theme.otherMessageTextColor;

    Widget contentWidget;
    switch (type) {
      case 'image':
        contentWidget = GestureDetector(
          onTap: () {
            // 点击查看大图
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.all(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 4,
                      child: Image.network(
                        content,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[300],
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red, size: 40),
                                  SizedBox(height: 8),
                                  Text('图片加载失败', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              content,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 120,
                  color: Colors.grey[300],
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 24),
                        SizedBox(height: 4),
                        Text('图片加载失败', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
        break;
      case 'video':
        contentWidget = GestureDetector(
          onTap: () {
            // 点击查看视频
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.all(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 300,
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill, size: 60, color: Colors.white.withOpacity(0.8)),
                            SizedBox(height: 16),
                            Text(
                              '视频播放功能开发中',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message['thumbnail'] ?? 'https://via.placeholder.com/120x120?text=Video',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[800],
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, color: Colors.white, size: 24),
                            SizedBox(height: 4),
                            Text('视频缩略图', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow, size: 24, color: Colors.white),
              ),
            ],
          ),
        );
        break;
      case 'file':
        contentWidget = Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file, color: textColor),
              SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['filename'] ?? '文件',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      message['filesize'] ?? '',
                      style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        break;
      case 'emoji':
        contentWidget = Container(
          padding: EdgeInsets.all(8),
          child: Text(
            content,
            style: TextStyle(fontSize: 32),
          ),
        );
        break;
      default:
        contentWidget = Text(
          content,
          style: TextStyle(fontSize: 16, color: textColor),
        );
    }

    // 根据消息类型构建不同的气泡形状
    BorderRadius bubbleRadius;
    if (isMe) {
      bubbleRadius = BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    } else {
      bubbleRadius = BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.isDark ? Colors.grey[700] : theme.primaryColor.withOpacity(0.2),
                    child: Text(
                      TextSanitizer.sanitize(message['from_nickname'] ?? '?').isNotEmpty ?
                        TextSanitizer.sanitize(message['from_nickname'] ?? '?')[0] : '?',
                      style: TextStyle(
                        color: theme.isDark ? Colors.white : theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 发送时间
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                    child: Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ),
                  // 消息气泡
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                    padding: EdgeInsets.all(type == 'emoji' ? 0 : 12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: bubbleRadius,
                    ),
                    child: contentWidget,
                  ),
                  // 消息状态
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: _buildStatusIcon(status),
                    ),
                ],
              ),
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.primaryColor,
                    child: Text(
                      TextSanitizer.sanitize(Persistence.getUserInfo()?.nickname ?? '我').isNotEmpty ?
                        TextSanitizer.sanitize(Persistence.getUserInfo()?.nickname ?? '我')[0] : '我',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(int status) {
    final theme = ThemeManager.currentTheme;

    switch (status) {
      case 0: // 发送中
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.isDark ? Colors.grey[400]! : Colors.grey[600]!,
                ),
              ),
            ),
          ],
        );
      case 1: // 已发送
        return Icon(
          Icons.check,
          size: 16,
          color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
        );
      case 2: // 发送失败
        return Icon(
          Icons.error_outline,
          size: 16,
          color: Colors.red,
        );
      default:
        return SizedBox.shrink();
    }
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // 今天的消息只显示时间
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == yesterday) {
      // 昨天的消息显示"昨天 时间"
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (now.difference(dateTime).inDays < 7) {
      // 一周内的消息显示"星期几 时间"
      final weekday = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][dateTime.weekday % 7];
      return '$weekday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      // 更早的消息显示完整日期
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    }
  }
}
