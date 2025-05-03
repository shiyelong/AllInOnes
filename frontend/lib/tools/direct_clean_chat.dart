import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DirectCleanChat {
  static Future<void> cleanAllChatMessages(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 直接删除所有聊天相关的键
      final allKeys = prefs.getKeys().toList();
      int count = 0;
      
      for (var key in allKeys) {
        if (key.startsWith('chat_messages_') || key.startsWith('last_message_')) {
          try {
            await prefs.remove(key);
            count++;
          } catch (e) {
            debugPrint('删除键 $key 失败: $e');
          }
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 $count 个聊天记录')),
      );
    } catch (e) {
      debugPrint('清理聊天记录出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理聊天记录失败: $e')),
      );
    }
  }
}
