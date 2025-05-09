import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'enhanced_file_utils.dart';
import 'thumbnail_manager.dart';
import 'text_sanitizer.dart';

/// 消息清理工具类
/// 用于清理脏聊天记录和修复媒体文件引用
class MessageCleaner {
  static const String _messageKeyPrefix = 'chat_messages_';
  static const String _lastMessageKeyPrefix = 'last_message_';

  /// 清理所有聊天记录
  /// 检查并修复所有聊天记录中的媒体文件引用
  static Future<Map<String, dynamic>> cleanAllMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取所有键
      final allKeys = prefs.getKeys();

      // 筛选出聊天记录键
      final chatKeys = allKeys.where((key) => key.startsWith(_messageKeyPrefix)).toList();

      int totalMessages = 0;
      int cleanedMessages = 0;
      int fixedMediaFiles = 0;

      // 处理每个聊天记录
      for (final chatKey in chatKeys) {
        final result = await _cleanChatMessages(prefs, chatKey);
        totalMessages += result['totalMessages'] as int;
        cleanedMessages += result['cleanedMessages'] as int;
        fixedMediaFiles += result['fixedMediaFiles'] as int;
      }

      return {
        'success': true,
        'totalChats': chatKeys.length,
        'totalMessages': totalMessages,
        'cleanedMessages': cleanedMessages,
        'fixedMediaFiles': fixedMediaFiles,
      };
    } catch (e) {
      debugPrint('[MessageCleaner] 清理所有聊天记录失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 清理指定用户的聊天记录
  static Future<Map<String, dynamic>> cleanUserMessages(int userId, int targetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 构建聊天键
      final chatKey = '${_messageKeyPrefix}${userId}_$targetId';

      // 清理聊天记录
      final result = await _cleanChatMessages(prefs, chatKey);

      // 更新最后一条消息
      await _updateLastMessage(prefs, userId, targetId);

      return {
        'success': true,
        'chatKey': chatKey,
        'totalMessages': result['totalMessages'],
        'cleanedMessages': result['cleanedMessages'],
        'fixedMediaFiles': result['fixedMediaFiles'],
      };
    } catch (e) {
      debugPrint('[MessageCleaner] 清理用户聊天记录失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 清理指定聊天记录
  static Future<Map<String, dynamic>> _cleanChatMessages(SharedPreferences prefs, String chatKey) async {
    try {
      // 获取聊天记录
      final messagesJson = prefs.getStringList(chatKey) ?? [];

      int totalMessages = messagesJson.length;
      int cleanedMessages = 0;
      int fixedMediaFiles = 0;

      // 处理每条消息
      List<String> validMessagesJson = [];

      for (final json in messagesJson) {
        try {
          // 解析消息
          final message = jsonDecode(json);

          // 检查消息格式是否有效
          if (message == null || !(message is Map<String, dynamic>)) {
            debugPrint('[MessageCleaner] 无效的消息格式: $json');
            cleanedMessages++;
            continue;
          }

          // 清理消息内容，确保它是有效的 UTF-16 字符串
          final sanitizedMessage = TextSanitizer.sanitizeMessage(message);

          // 修复媒体文件引用
          final fixedMessage = await _fixMediaContent(sanitizedMessage);

          // 如果消息被修复，增加计数
          if (fixedMessage['_fixed'] == true) {
            fixedMediaFiles++;
          }

          // 移除临时标记
          fixedMessage.remove('_fixed');

          // 保存有效消息
          validMessagesJson.add(jsonEncode(fixedMessage));
        } catch (e) {
          debugPrint('[MessageCleaner] 处理消息失败: $e');
          cleanedMessages++;
        }
      }

      // 保存清理后的消息
      await prefs.setStringList(chatKey, validMessagesJson);

      return {
        'totalMessages': totalMessages,
        'cleanedMessages': cleanedMessages,
        'fixedMediaFiles': fixedMediaFiles,
      };
    } catch (e) {
      debugPrint('[MessageCleaner] 清理聊天记录失败: $e');
      return {
        'totalMessages': 0,
        'cleanedMessages': 0,
        'fixedMediaFiles': 0,
      };
    }
  }

  /// 修复消息中的媒体内容
  static Future<Map<String, dynamic>> _fixMediaContent(Map<String, dynamic> message) async {
    try {
      final type = message['type'] ?? 'text';
      final content = message['content'] ?? '';

      // 如果不是媒体类型或内容为空，直接返回
      if (type == 'text' || type == 'emoji' || content.isEmpty) {
        return message;
      }

      bool fixed = false;

      // 根据消息类型处理
      switch (type) {
        case 'image':
          fixed = await _fixImageContent(message);
          break;

        case 'video':
          fixed = await _fixVideoContent(message);
          break;

        case 'file':
          fixed = await _fixFileContent(message);
          break;

        case 'voice':
          fixed = await _fixVoiceContent(message);
          break;
      }

      // 标记是否被修复
      message['_fixed'] = fixed;

      return message;
    } catch (e) {
      debugPrint('[MessageCleaner] 修复媒体内容失败: $e');
      return message;
    }
  }

  /// 修复图片消息内容
  static Future<bool> _fixImageContent(Map<String, dynamic> message) async {
    try {
      final content = message['content'] ?? '';
      final thumbnail = message['thumbnail'] ?? '';

      bool fixed = false;

      // 检查图片内容
      if (content.isNotEmpty) {
        // 检查本地文件是否存在
        if ((content.startsWith('file://') || content.startsWith('/')) &&
            !await EnhancedFileUtils.fileExists(EnhancedFileUtils.getValidFilePath(content))) {
          // 文件不存在，尝试从原始URL重新下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty) {
            debugPrint('[MessageCleaner] 图片文件不存在，标记为需要修复: $content');
            // 不在这里下载，只标记为需要修复
            fixed = true;
          }
        }
      }

      // 检查缩略图
      if (thumbnail.isNotEmpty) {
        // 检查本地文件是否存在
        if ((thumbnail.startsWith('file://') || thumbnail.startsWith('/')) &&
            !await EnhancedFileUtils.fileExists(EnhancedFileUtils.getValidFilePath(thumbnail))) {
          debugPrint('[MessageCleaner] 缩略图文件不存在，将重新生成: $thumbnail');

          // 如果原图存在，重新生成缩略图
          if (content.isNotEmpty &&
              ((content.startsWith('file://') || content.startsWith('/')) &&
               await EnhancedFileUtils.fileExists(EnhancedFileUtils.getValidFilePath(content)))) {

            // 使用ThumbnailManager生成新的缩略图
            final newThumbnail = await ThumbnailManager.getThumbnail(
              content,
              width: 200,
              height: 200,
              quality: 80,
            );

            if (newThumbnail.isNotEmpty) {
              message['thumbnail'] = newThumbnail;

              // 更新extra字段
              if (message['extra'] != null && message['extra'] is String) {
                try {
                  final extraData = jsonDecode(message['extra']);
                  extraData['thumbnail'] = newThumbnail;
                  message['extra'] = jsonEncode(extraData);
                } catch (e) {
                  debugPrint('[MessageCleaner] 更新extra中的缩略图失败: $e');
                }
              }

              fixed = true;
              debugPrint('[MessageCleaner] 已重新生成缩略图: $newThumbnail');
            }
          } else {
            // 原图不存在，清除无效的缩略图引用
            message['thumbnail'] = '';

            // 更新extra字段
            if (message['extra'] != null && message['extra'] is String) {
              try {
                final extraData = jsonDecode(message['extra']);
                extraData.remove('thumbnail');
                message['extra'] = jsonEncode(extraData);
              } catch (e) {
                debugPrint('[MessageCleaner] 更新extra中的缩略图失败: $e');
              }
            }

            fixed = true;
            debugPrint('[MessageCleaner] 已清除无效的缩略图引用');
          }
        }
      }

      return fixed;
    } catch (e) {
      debugPrint('[MessageCleaner] 修复图片内容失败: $e');
      return false;
    }
  }

  /// 修复视频消息内容
  static Future<bool> _fixVideoContent(Map<String, dynamic> message) async {
    try {
      final content = message['content'] ?? '';
      final thumbnail = message['thumbnail'] ?? '';

      bool fixed = false;

      // 检查视频内容
      if (content.isNotEmpty) {
        // 检查本地文件是否存在
        if ((content.startsWith('file://') || content.startsWith('/')) &&
            !await EnhancedFileUtils.fileExists(EnhancedFileUtils.getValidFilePath(content))) {
          // 文件不存在，尝试从原始URL重新下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty) {
            debugPrint('[MessageCleaner] 视频文件不存在，标记为需要修复: $content');
            // 不在这里下载，只标记为需要修复
            fixed = true;
          }
        }
      }

      // 检查缩略图
      if (thumbnail.isNotEmpty) {
        // 检查本地文件是否存在
        if ((thumbnail.startsWith('file://') || thumbnail.startsWith('/')) &&
            !await EnhancedFileUtils.fileExists(EnhancedFileUtils.getValidFilePath(thumbnail))) {
          debugPrint('[MessageCleaner] 视频缩略图文件不存在，将清除引用: $thumbnail');

          // 清除无效的缩略图引用
          message['thumbnail'] = '';

          // 更新extra字段
          if (message['extra'] != null && message['extra'] is String) {
            try {
              final extraData = jsonDecode(message['extra']);
              extraData.remove('thumbnail');
              message['extra'] = jsonEncode(extraData);
            } catch (e) {
              debugPrint('[MessageCleaner] 更新extra中的缩略图失败: $e');
            }
          }

          fixed = true;
        }
      }

      return fixed;
    } catch (e) {
      debugPrint('[MessageCleaner] 修复视频内容失败: $e');
      return false;
    }
  }

  /// 修复文件消息内容
  static Future<bool> _fixFileContent(Map<String, dynamic> message) async {
    try {
      final content = message['content'] ?? '';

      // 检查文件内容
      if (content.isNotEmpty) {
        // 检查本地文件是否存在
        if ((content.startsWith('file://') || content.startsWith('/')) &&
            !await EnhancedFileUtils.fileExists(EnhancedFileUtils.getValidFilePath(content))) {
          // 文件不存在，尝试从原始URL重新下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty) {
            debugPrint('[MessageCleaner] 文件不存在，标记为需要修复: $content');
            // 不在这里下载，只标记为需要修复
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('[MessageCleaner] 修复文件内容失败: $e');
      return false;
    }
  }

  /// 修复语音消息内容
  static Future<bool> _fixVoiceContent(Map<String, dynamic> message) async {
    try {
      final content = message['content'] ?? '';

      // 检查语音内容
      if (content.isNotEmpty) {
        // 检查本地文件是否存在
        if ((content.startsWith('file://') || content.startsWith('/')) &&
            !await EnhancedFileUtils.fileExists(EnhancedFileUtils.getValidFilePath(content))) {
          // 文件不存在，尝试从原始URL重新下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty) {
            debugPrint('[MessageCleaner] 语音文件不存在，标记为需要修复: $content');
            // 不在这里下载，只标记为需要修复
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('[MessageCleaner] 修复语音内容失败: $e');
      return false;
    }
  }

  /// 更新最后一条消息
  static Future<void> _updateLastMessage(SharedPreferences prefs, int userId, int targetId) async {
    try {
      // 获取聊天记录
      final chatKey = '${_messageKeyPrefix}${userId}_$targetId';
      final messagesJson = prefs.getStringList(chatKey) ?? [];

      if (messagesJson.isEmpty) {
        // 如果没有消息，删除最后一条消息记录
        final lastMessageKey = '${_lastMessageKeyPrefix}${userId}_$targetId';
        await prefs.remove(lastMessageKey);
        return;
      }

      // 获取最后一条消息
      final lastMessageJson = messagesJson.last;
      final lastMessage = jsonDecode(lastMessageJson);

      // 保存最后一条消息
      final lastMessageKey = '${_lastMessageKeyPrefix}${userId}_$targetId';
      await prefs.setString(lastMessageKey, lastMessageJson);

      debugPrint('[MessageCleaner] 已更新最后一条消息: $lastMessageKey');
    } catch (e) {
      debugPrint('[MessageCleaner] 更新最后一条消息失败: $e');
    }
  }
}
