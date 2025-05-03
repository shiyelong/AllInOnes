import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleCleanChat {
  static Future<void> cleanChat(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取所有键
      final allKeys = prefs.getKeys().toList();
      
      // 计数器
      int count = 0;
      
      // 只删除聊天消息键
      for (var key in allKeys) {
        if (key.startsWith('chat_messages_')) {
          try {
            await prefs.remove(key);
            count++;
          } catch (e) {
            debugPrint('删除键 $key 失败: $e');
          }
        }
      }
      
      // 显示成功消息
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
