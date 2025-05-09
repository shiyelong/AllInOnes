import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/common/local_message_storage_extension.dart';

/// 简单的聊天清理工具
/// 用于清理聊天记录
class SimpleCleanChat {
  /// 清理聊天记录
  static Future<void> cleanChat(BuildContext context) async {
    try {
      // 显示确认对话框
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('清理聊天记录'),
          content: const Text('确定要清理所有聊天记录吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // 清理本地消息存储
        await LocalMessageStorageExtension.clearAllMessages();

        // 清理SharedPreferences中的聊天相关数据
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('chat_') ||
              key.startsWith('message_') ||
              key.startsWith('conversation_')) {
            await prefs.remove(key);
          }
        }

        // 显示成功提示
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('聊天记录已清理'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // 显示错误提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清理聊天记录失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
