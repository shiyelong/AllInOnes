import 'package:flutter/material.dart';
import '../../../common/theme_manager.dart';
import '../../../common/text_sanitizer.dart';
import '../../../common/file_utils.dart';
import 'chat_message_item.dart';

class ChatMessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final ScrollController? controller;
  const ChatMessageList({Key? key, required this.messages, this.controller}) : super(key: key);

  // 预处理媒体消息
  void _preprocessMediaMessage(Map<String, dynamic> message) {
    try {
      final type = message['type'] ?? 'text';
      final content = message['content'] ?? '';

      // 如果不是媒体类型或内容为空，直接返回
      if (type == 'text' || type == 'emoji' || content.isEmpty) {
        return;
      }

      // 检查本地文件路径是否有效
      if (content.startsWith('file://') || content.startsWith('/')) {
        // 验证文件路径
        FileUtils.getValidFilePath(content);
      }

      // 处理视频缩略图
      if (type == 'video') {
        final thumbnail = message['thumbnail'] ?? '';
        if (thumbnail.isNotEmpty && (thumbnail.startsWith('file://') || thumbnail.startsWith('/'))) {
          // 验证缩略图路径
          FileUtils.getValidFilePath(thumbnail);
        }
      }
    } catch (e) {
      debugPrint('预处理媒体消息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: theme.isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              '暂无消息',
              style: TextStyle(
                color: theme.isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '发送一条消息开始聊天吧',
              style: TextStyle(
                color: theme.isDark ? Colors.grey[600] : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // 检查是否需要显示日期分隔线
    List<Widget> messageWidgets = [];
    DateTime? lastDate;

    for (int i = 0; i < messages.length; i++) {
      // 清理消息内容，确保它是有效的 UTF-16 字符串
      final msg = TextSanitizer.sanitizeMessage(messages[i]);

      // 预处理媒体消息
      _preprocessMediaMessage(msg);

      final timestamp = msg['created_at'] ?? 0;
      final currentDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

      // 如果日期不同，添加日期分隔线
      if (lastDate == null ||
          lastDate.year != currentDate.year ||
          lastDate.month != currentDate.month ||
          lastDate.day != currentDate.day) {
        messageWidgets.add(_buildDateHeader(currentDate));
      }

      messageWidgets.add(ChatMessageItem(message: msg));
      lastDate = currentDate;
    }

    return ListView(
      controller: controller,
      reverse: false, // 最新消息在底部
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      children: messageWidgets,
    );
  }

  // 构建日期分隔线
  Widget _buildDateHeader(DateTime date) {
    final theme = ThemeManager.currentTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = '今天';
    } else if (messageDate == yesterday) {
      dateText = '昨天';
    } else if (date.year == now.year) {
      dateText = '${date.month}月${date.day}日';
    } else {
      dateText = '${date.year}年${date.month}月${date.day}日';
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.isDark ? Colors.grey[800] : Colors.grey[300])),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: theme.isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.isDark ? Colors.grey[800] : Colors.grey[300])),
        ],
      ),
    );
  }
}
