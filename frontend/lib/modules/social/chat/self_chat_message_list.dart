import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'self_chat_message_item.dart';
import '../../../common/text_sanitizer.dart';

/// 专门为"我的设备"聊天设计的消息列表组件
class SelfChatMessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final ScrollController? controller;

  const SelfChatMessageList({
    Key? key,
    required this.messages,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text('暂无消息'),
      );
    }

    // 检查是否需要显示日期分隔线
    List<Widget> messageWidgets = [];
    DateTime? lastDate;

    for (int i = 0; i < messages.length; i++) {
      // 清理消息内容，确保它是有效的 UTF-16 字符串
      final msg = TextSanitizer.sanitizeMessage(messages[i]);
      final timestamp = msg['created_at'] ?? 0;
      final currentDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

      // 如果日期不同，添加日期分隔线
      if (lastDate == null ||
          lastDate.year != currentDate.year ||
          lastDate.month != currentDate.month ||
          lastDate.day != currentDate.day) {
        messageWidgets.add(_buildDateHeader(currentDate));
      }

      messageWidgets.add(SelfChatMessageItem(message: msg));
      lastDate = currentDate;
    }

    return ListView(
      controller: controller,
      reverse: false, // 最新消息在底部
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      children: messageWidgets,
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = '今天';
    } else if (messageDate == yesterday) {
      dateText = '昨天';
    } else if (now.difference(date).inDays < 7) {
      final weekday = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][date.weekday % 7];
      dateText = weekday;
    } else {
      dateText = DateFormat('yyyy年MM月dd日').format(date);
    }

    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
