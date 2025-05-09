import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/text_sanitizer.dart';
import '../../../common/local_message_storage.dart';
import '../../../common/message_queue_manager.dart';

/// 聊天消息管理器
/// 负责消息的加载、发送、保存等操作
class ChatMessageManager {
  static final ChatMessageManager _instance = ChatMessageManager._internal();
  factory ChatMessageManager() => _instance;

  ChatMessageManager._internal();

  /// 加载消息
  /// 从本地存储和服务器加载消息
  Future<Map<String, dynamic>> loadMessages({
    required String userId,
    required String targetId,
  }) async {
    try {
      debugPrint('[ChatMessageManager] 加载消息: userId=$userId, targetId=$targetId');

      // 从多个来源加载消息
      List<Map<String, dynamic>> allMessages = [];

      // 1. 从Persistence加载消息
      final persistenceMessages = await Persistence.getChatMessages(userId, targetId);
      if (persistenceMessages.isNotEmpty) {
        debugPrint('[ChatMessageManager] 从Persistence加载了 ${persistenceMessages.length} 条消息');
        allMessages.addAll(persistenceMessages);
      }

      // 2. 从LocalMessageStorage加载消息
      try {
        final localStorageMessages = await LocalMessageStorage.getMessages(
          int.parse(userId),
          int.parse(targetId)
        );

        if (localStorageMessages.isNotEmpty) {
          debugPrint('[ChatMessageManager] 从LocalMessageStorage加载了 ${localStorageMessages.length} 条消息');
          allMessages.addAll(localStorageMessages);
        }
      } catch (e) {
        debugPrint('[ChatMessageManager] 从LocalMessageStorage加载消息失败: $e');
      }

      // 3. 去重处理
      List<Map<String, dynamic>> uniqueMessages = [];
      if (allMessages.isNotEmpty) {
        // 使用消息ID去重
        final Map<String, Map<String, dynamic>> uniqueMessagesMap = {};

        for (var msg in allMessages) {
          final msgId = msg['id']?.toString();
          if (msgId != null && msgId.isNotEmpty) {
            // 如果消息ID已存在，保留状态更新的消息（状态值更大的）
            if (uniqueMessagesMap.containsKey(msgId)) {
              final existingStatus = uniqueMessagesMap[msgId]!['status'] ?? 0;
              final newStatus = msg['status'] ?? 0;

              if (newStatus > existingStatus) {
                uniqueMessagesMap[msgId] = msg;
              }
            } else {
              uniqueMessagesMap[msgId] = msg;
            }
          } else {
            // 对于没有ID的消息，使用内容+时间戳作为键
            final content = msg['content']?.toString() ?? '';
            final timestamp = msg['created_at']?.toString() ?? '';
            final compositeKey = '${content}_${timestamp}';

            if (!uniqueMessagesMap.containsKey(compositeKey)) {
              uniqueMessagesMap[compositeKey] = msg;
            }
          }
        }

        // 转换回列表
        uniqueMessages = uniqueMessagesMap.values.toList();

        debugPrint('[ChatMessageManager] 去重后剩余 ${uniqueMessages.length} 条消息');

        // 按时间排序
        uniqueMessages.sort((a, b) {
          final aTime = a['created_at'] ?? 0;
          final bTime = b['created_at'] ?? 0;
          return aTime.compareTo(bTime);
        });
      }

      // 4. 从服务器加载最新消息
      final response = await Api.getMessagesByUser(
        userId: userId,
        targetId: targetId,
      );

      // 打印响应结果
      debugPrint('[ChatMessageManager] 消息加载响应: success=${response['success']}, msg=${response['msg']}');

      if (response['success'] == true) {
        // 确保消息按时间排序，最早的消息在前面
        final rawMessages = List<Map<String, dynamic>>.from(response['data'] ?? []);
        debugPrint('[ChatMessageManager] 从服务器获取到 ${rawMessages.length} 条消息');

        // 使用 TextSanitizer 清理消息内容
        final serverMessages = rawMessages.map((msg) => TextSanitizer.sanitizeMessage(msg)).toList();

        // 合并本地和服务器消息，并去重
        final Map<String, Map<String, dynamic>> mergedMessages = {};

        // 先添加本地消息
        for (var msg in uniqueMessages) {
          final msgId = msg['id']?.toString();
          if (msgId != null && msgId.isNotEmpty) {
            mergedMessages[msgId] = msg;
          } else {
            // 对于没有ID的消息，使用内容+时间戳作为键
            final content = msg['content']?.toString() ?? '';
            final timestamp = msg['created_at']?.toString() ?? '';
            final compositeKey = '${content}_${timestamp}';

            if (compositeKey != '_') {
              mergedMessages[compositeKey] = msg;
            }
          }
        }

        // 再添加服务器消息，覆盖同ID的本地消息
        for (var msg in serverMessages) {
          final msgId = msg['id']?.toString();
          if (msgId != null && msgId.isNotEmpty) {
            // 如果是服务器消息，状态设为已发送
            msg['status'] = 1;

            // 如果本地已有此消息，保留更高的状态值
            if (mergedMessages.containsKey(msgId)) {
              final existingStatus = mergedMessages[msgId]!['status'] ?? 0;
              final newStatus = msg['status'] ?? 0;

              if (newStatus > existingStatus) {
                mergedMessages[msgId] = msg;
              }
            } else {
              mergedMessages[msgId] = msg;
            }
          } else {
            // 对于没有ID的消息，使用内容+时间戳作为键
            final content = msg['content']?.toString() ?? '';
            final timestamp = msg['created_at']?.toString() ?? '';
            final compositeKey = '${content}_${timestamp}';

            if (compositeKey != '_') {
              mergedMessages[compositeKey] = msg;
            }
          }
        }

        debugPrint('[ChatMessageManager] 合并后消息数量: ${mergedMessages.length}');

        // 转换回列表并排序
        final List<Map<String, dynamic>> finalMessages = mergedMessages.values.toList();
        finalMessages.sort((a, b) {
          final aTime = a['created_at'] ?? 0;
          final bTime = b['created_at'] ?? 0;
          return aTime.compareTo(bTime);
        });

        // 保存到本地存储
        await Persistence.saveChatMessages(userId, targetId, finalMessages);

        // 同时保存到LocalMessageStorage
        try {
          for (var msg in finalMessages) {
            await LocalMessageStorage.saveMessage(
              int.parse(userId),
              int.parse(targetId),
              msg
            );
          }
        } catch (e) {
          debugPrint('[ChatMessageManager] 保存到LocalMessageStorage失败: $e');
        }

        return {
          'success': true,
          'messages': finalMessages,
          'error': '',
        };
      } else {
        // 如果服务器请求失败但本地有消息，返回本地消息
        if (uniqueMessages.isNotEmpty) {
          return {
            'success': true,
            'messages': uniqueMessages,
            'error': '',
          };
        } else {
          return {
            'success': false,
            'messages': [],
            'error': response['msg'] ?? '加载消息失败',
          };
        }
      }
    } catch (e) {
      debugPrint('[ChatMessageManager] 加载消息异常: $e');

      return {
        'success': false,
        'messages': [],
        'error': '加载消息出错: $e',
      };
    }
  }

  /// 发送文本消息
  Future<Map<String, dynamic>> sendTextMessage({
    required String userId,
    required String targetId,
    required String content,
  }) async {
    try {
      // 生成唯一的消息ID
      final localMessageId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 创建本地消息对象
      final localMessage = {
        'id': localMessageId,
        'from_id': int.parse(userId),
        'to_id': int.parse(targetId),
        'content': content,
        'type': 'text',
        'created_at': timestamp,
        'status': 0, // 发送中
      };

      // 立即保存到本地存储，确保消息不会丢失
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      // 使用消息队列管理器发送消息，确保消息按顺序发送，并在网络恢复时自动重试
      await MessageQueueManager().addSingleChatMessage(
        int.parse(targetId),
        content,
        type: 'text',
      );

      debugPrint('[ChatMessageManager] 发送消息: $content');
      final response = await Api.sendMessage(
        targetId: targetId,
        content: content,
        type: 'text',
      );

      debugPrint('[ChatMessageManager] 发送消息响应: $response');

      if (response['success'] == true) {
        // 获取服务器返回的消息ID
        final serverId = response['data']?['id'];

        if (serverId != null) {
          // 更新本地消息对象
          localMessage['status'] = 1; // 已发送
          localMessage['id'] = serverId;

          // 保存更新后的消息
          await _saveMessageToLocalStorage(userId, targetId, localMessage);

          return {
            'success': true,
            'message': localMessage,
            'error': '',
          };
        }
      }

      // 如果发送失败，更新消息状态为发送失败
      localMessage['status'] = 2; // 发送失败
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      return {
        'success': false,
        'message': localMessage,
        'error': response['msg'] ?? '发送消息失败',
      };
    } catch (e) {
      debugPrint('[ChatMessageManager] 发送消息异常: $e');
      return {
        'success': false,
        'message': null,
        'error': '发送消息出错: $e',
      };
    }
  }

  /// 保存消息到本地存储
  Future<void> _saveMessageToLocalStorage(
    String userId,
    String targetId,
    Map<String, dynamic> message,
  ) async {
    try {
      // 获取当前消息列表
      final messages = await Persistence.getChatMessages(userId, targetId);

      // 查找是否已存在相同ID的消息
      final index = messages.indexWhere((msg) => msg['id'] == message['id']);
      if (index != -1) {
        // 更新现有消息
        messages[index] = message;
      } else {
        // 添加新消息
        messages.add(message);
      }

      // 保存到Persistence
      await Persistence.saveChatMessages(userId, targetId, messages);

      // 同时保存到LocalMessageStorage
      try {
        await LocalMessageStorage.saveMessage(
          int.parse(userId),
          int.parse(targetId),
          message
        );
      } catch (e) {
        debugPrint('[ChatMessageManager] 保存到LocalMessageStorage失败: $e');
      }
    } catch (e) {
      debugPrint('[ChatMessageManager] 保存消息到本地存储失败: $e');
    }
  }
}
