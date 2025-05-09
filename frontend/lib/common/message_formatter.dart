import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'text_sanitizer.dart';

/// 消息格式化工具类
/// 用于将不同类型的消息转换为适合在聊天列表预览中显示的格式
class MessageFormatter {
  /// 格式化消息内容用于预览显示
  /// [message] 消息对象
  /// 返回格式化后的消息内容
  static String formatMessagePreview(Map<String, dynamic> message) {
    final type = message['type'] ?? 'text';
    final content = message['content'] ?? '';
    
    switch (type) {
      case 'text':
        // 文本消息直接显示内容
        return TextSanitizer.sanitize(content);
      
      case 'image':
        // 图片消息显示[图片]
        return '[图片]';
      
      case 'video':
        // 视频消息显示[视频]
        return '[视频]';
      
      case 'file':
        // 文件消息显示[文件]
        String fileName = '';
        try {
          // 尝试从content中提取文件名
          if (content.contains('/')) {
            fileName = content.split('/').last;
          } else {
            fileName = content;
          }
          
          // 如果有额外信息，尝试从中获取文件名
          final extraStr = message['extra'] ?? '{}';
          final extra = jsonDecode(extraStr);
          if (extra.containsKey('file_name') && extra['file_name'] != null) {
            fileName = extra['file_name'];
          }
          
          return '[文件] $fileName';
        } catch (e) {
          return '[文件]';
        }
      
      case 'voice':
        // 语音消息显示[语音]
        final duration = _extractVoiceDuration(message);
        return '[语音] ${duration > 0 ? '${duration}秒' : ''}';
      
      case 'location':
        // 位置消息显示[位置]
        return '[位置]';
      
      case 'transfer':
        // 转账消息显示[转账]
        return '[转账]';
      
      case 'red_packet':
        // 红包消息显示[红包]
        return '[红包]';
      
      case 'sticker':
        // 贴纸消息显示[表情]
        return '[表情]';
      
      case 'emoji':
        // 表情消息直接显示内容
        return content;
      
      default:
        // 其他类型消息显示[未知消息]
        return '[未知消息]';
    }
  }
  
  /// 提取语音消息的时长
  /// [message] 消息对象
  /// 返回语音时长（秒）
  static int _extractVoiceDuration(Map<String, dynamic> message) {
    try {
      final extraStr = message['extra'] ?? '{}';
      final extra = jsonDecode(extraStr);
      return extra['duration'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// 检查消息是否包含表情
  /// [content] 消息内容
  /// 返回是否只包含表情
  static bool isEmojiOnly(String content) {
    // 简单判断：如果消息长度小于等于8且只包含表情符号
    if (content.length <= 8) {
      final emojiRegExp = RegExp(
        r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
      );
      
      final contentWithoutEmoji = content.replaceAll(emojiRegExp, '');
      return contentWithoutEmoji.trim().isEmpty;
    }
    return false;
  }
}
