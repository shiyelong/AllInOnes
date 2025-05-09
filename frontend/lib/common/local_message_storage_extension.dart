import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/local_message_storage.dart';

/// LocalMessageStorage的扩展方法
/// 提供字符串参数版本的消息存储和获取方法
extension LocalMessageStorageExtension on LocalMessageStorage {
  /// 获取消息 (字符串版本)
  static Future<List<Map<String, dynamic>>> getMessagesStr(String targetId) async {
    final userInfo = Persistence.getUserInfo();
    if (userInfo == null) return [];

    try {
      final userId = userInfo.id;
      final targetIdInt = int.tryParse(targetId);
      if (targetIdInt == null) {
        debugPrint('[LocalMessageStorage] 无效的目标ID: $targetId');
        return [];
      }

      return await LocalMessageStorage.getMessages(userId, targetIdInt);
    } catch (e) {
      debugPrint('[LocalMessageStorage] 获取消息失败: $e');
      return [];
    }
  }

  /// 保存消息 (字符串版本)
  static Future<bool> saveMessagesStr(String targetId, List<Map<String, dynamic>> messages) async {
    final userInfo = Persistence.getUserInfo();
    if (userInfo == null) return false;

    try {
      final userId = userInfo.id;
      final targetIdInt = int.tryParse(targetId);
      if (targetIdInt == null) {
        debugPrint('[LocalMessageStorage] 无效的目标ID: $targetId');
        return false;
      }

      // 确保每条消息都有正确的时间戳
      final processedMessages = messages.map((msg) {
        if (msg['created_at'] == null) {
          msg['created_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        }
        return msg;
      }).toList();

      // 使用主存储类保存消息
      for (var message in processedMessages) {
        await LocalMessageStorage.saveMessage(userId, targetIdInt, message);
      }

      return true;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 保存消息失败: $e');
      return false;
    }
  }

  /// 清理所有消息
  static Future<void> clearAllMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 清理所有消息相关的键
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('chat_') ||
            key.startsWith('message_') ||
            key.startsWith('conversation_') ||
            key.startsWith('last_message_')) {
          await prefs.remove(key);
        }
      }

      debugPrint('[LocalMessageStorage] 所有消息已清理');
    } catch (e) {
      debugPrint('[LocalMessageStorage] 清理所有消息失败: $e');
    }
  }

  /// 获取API消息
  static Future<Map<String, dynamic>> getMessagesFromApi({
    required String fromId,
    required String toId,
    required int page,
    required int pageSize,
  }) async {
    try {
      // 这里应该调用API获取消息
      // 由于我们没有实际的API实现，返回一个空的结果
      return {
        'code': 0,
        'message': 'success',
        'data': [],
      };
    } catch (e) {
      debugPrint('[LocalMessageStorage] 从API获取消息失败: $e');
      return {
        'code': -1,
        'message': e.toString(),
        'data': [],
      };
    }
  }

  /// 发送消息到API
  static Future<Map<String, dynamic>> sendMessageToApi({
    required String fromId,
    required String toId,
    required String content,
    required String type,
  }) async {
    try {
      // 这里应该调用API发送消息
      // 由于我们没有实际的API实现，返回一个模拟的成功结果
      return {
        'code': 0,
        'message': 'success',
        'data': {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'from_id': fromId,
          'to_id': toId,
          'content': content,
          'type': type,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'status': 1,
        },
      };
    } catch (e) {
      debugPrint('[LocalMessageStorage] 发送消息到API失败: $e');
      return {
        'code': -1,
        'message': e.toString(),
        'data': null,
      };
    }
  }

  /// 获取自己的消息
  static Future<Map<String, dynamic>> getSelfMessagesFromApi({
    required String userId,
    required int page,
    required int pageSize,
  }) async {
    try {
      // 这里应该调用API获取自己的消息
      // 由于我们没有实际的API实现，返回一个空的结果
      return {
        'code': 0,
        'message': 'success',
        'data': [],
      };
    } catch (e) {
      debugPrint('[LocalMessageStorage] 从API获取自己的消息失败: $e');
      return {
        'code': -1,
        'message': e.toString(),
        'data': [],
      };
    }
  }

  /// 发送消息给自己
  static Future<Map<String, dynamic>> sendSelfMessageToApi({
    required String userId,
    required String content,
    required String type,
  }) async {
    try {
      // 这里应该调用API发送消息给自己
      // 由于我们没有实际的API实现，返回一个模拟的成功结果
      return {
        'code': 0,
        'message': 'success',
        'data': {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'from_id': userId,
          'to_id': userId,
          'content': content,
          'type': type,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'status': 1,
        },
      };
    } catch (e) {
      debugPrint('[LocalMessageStorage] 发送消息给自己失败: $e');
      return {
        'code': -1,
        'message': e.toString(),
        'data': null,
      };
    }
  }
}
