import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CleanChatMessagesTool {
  static Future<void> cleanAllChatMessages(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // 找到所有聊天消息相关的键
      final chatKeys = allKeys.where((key) => 
        key.startsWith('chat_messages_') || 
        key.startsWith('last_message_')
      ).toList();
      
      // 删除所有聊天消息
      for (var key in chatKeys) {
        await prefs.remove(key);
      }
      
      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 ${chatKeys.length} 个聊天记录')),
      );
    } catch (e) {
      debugPrint('清理聊天记录出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理聊天记录失败: $e')),
      );
    }
  }
}
