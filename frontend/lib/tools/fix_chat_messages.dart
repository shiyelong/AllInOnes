import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FixChatMessages {
  /// 清理所有聊天消息
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
      int count = 0;
      for (var key in chatKeys) {
        try {
          await prefs.remove(key);
          count++;
        } catch (e) {
          debugPrint('删除聊天记录 $key 失败: $e');
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

  /// 修复聊天消息中的 UTF-16 错误
  static Future<void> fixChatMessages(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // 找到所有聊天消息相关的键
      final chatKeys = allKeys.where((key) => 
        key.startsWith('chat_messages_')
      ).toList();
      
      int fixedCount = 0;
      
      // 修复每个聊天记录
      for (var key in chatKeys) {
        try {
          final messagesJson = prefs.getString(key);
          if (messagesJson == null) continue;
          
          try {
            // 尝试解析消息
            final List<dynamic> messages = jsonDecode(messagesJson);
            
            // 修复每条消息
            List<Map<String, dynamic>> fixedMessages = [];
            for (var msg in messages) {
              try {
                final Map<String, dynamic> message = Map<String, dynamic>.from(msg);
                
                // 修复内容
                if (message.containsKey('content')) {
                  message['content'] = _sanitizeText(message['content']);
                }
                
                // 修复昵称
                if (message.containsKey('from_nickname')) {
                  message['from_nickname'] = _sanitizeText(message['from_nickname']);
                }
                
                fixedMessages.add(message);
              } catch (e) {
                debugPrint('修复消息失败: $e');
              }
            }
            
            // 保存修复后的消息
            await prefs.setString(key, jsonEncode(fixedMessages));
            fixedCount++;
          } catch (e) {
            debugPrint('解析消息失败: $e');
            // 如果解析失败，直接删除这个键
            await prefs.remove(key);
          }
        } catch (e) {
          debugPrint('修复聊天记录 $key 失败: $e');
        }
      }
      
      // 修复最后一条消息
      final lastMessageKeys = allKeys.where((key) => 
        key.startsWith('last_message_')
      ).toList();
      
      for (var key in lastMessageKeys) {
        try {
          final messageJson = prefs.getString(key);
          if (messageJson == null) continue;
          
          try {
            // 尝试解析消息
            final Map<String, dynamic> message = jsonDecode(messageJson);
            
            // 修复内容
            if (message.containsKey('content')) {
              message['content'] = _sanitizeText(message['content']);
            }
            
            // 修复昵称
            if (message.containsKey('from_nickname')) {
              message['from_nickname'] = _sanitizeText(message['from_nickname']);
            }
            
            // 保存修复后的消息
            await prefs.setString(key, jsonEncode(message));
          } catch (e) {
            debugPrint('解析最后一条消息失败: $e');
            // 如果解析失败，直接删除这个键
            await prefs.remove(key);
          }
        } catch (e) {
          debugPrint('修复最后一条消息 $key 失败: $e');
        }
      }
      
      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已修复 $fixedCount 个聊天记录')),
      );
    } catch (e) {
      debugPrint('修复聊天记录出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修复聊天记录失败: $e')),
      );
    }
  }
  
  /// 清理文本，确保是有效的 UTF-16 字符串
  static String _sanitizeText(dynamic text) {
    if (text == null) return '';
    
    String strText = text.toString();
    if (strText.isEmpty) return '';
    
    try {
      // 尝试检测无效的 UTF-16 字符
      strText.runes.toList();
      return strText;
    } catch (e) {
      debugPrint('检测到无效的 UTF-16 字符: $e');
      
      // 尝试清理文本
      try {
        // 移除可能导致问题的字符
        return strText
            .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '') // 控制字符
            .replaceAll(RegExp(r'[\uD800-\uDFFF]'), ''); // 代理对字符
      } catch (e) {
        debugPrint('清理文本失败: $e');
        return '无法显示的文本';
      }
    }
  }
}
