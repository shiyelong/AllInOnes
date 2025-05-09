import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/common/text_sanitizer.dart';
import 'package:frontend/common/message_formatter.dart';

class ChatService {
  static Future<List> fetchRecentChats(int userId) async {
    try {
      // 获取好友列表
      final friendsResponse = await Api.getFriendList();
      if (friendsResponse['success'] != true) {
        return [];
      }

      final List<dynamic> friends = friendsResponse['data'] ?? [];

      // 转换为聊天列表格式
      List<Map<String, dynamic>> chats = [];

      // 添加"我的设备"聊天
      chats.add({
        'id': 'self_${userId}',
        'type': 'self',
        'target_id': userId,
        'target_name': '我的设备',
        'target_avatar': '',
        'last_message': '与自己的聊天',
        'formatted_preview': '与自己的聊天',
        'last_message_type': 'text',
        'unread': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'blocked': 0,
        'is_self': true,
        'is_pinned': false,
        'is_muted': false,
      });

      // 添加好友聊天
      for (var friend in friends) {
        final friendId = friend['friend_id'];

        // 尝试从本地存储获取最后一条消息
        String lastMessage = '';
        String formattedPreview = '';
        String lastMessageType = '';
        int lastTime = 0;

        // 先从本地存储获取最后一条消息，并格式化预览
        final lastLocalMessage = await LocalMessageStorage.getLastMessage(userId, friendId, formatPreview: true);
        if (lastLocalMessage != null) {
          lastMessage = lastLocalMessage['content'] ?? '';
          formattedPreview = lastLocalMessage['formatted_preview'] ?? '';
          lastMessageType = lastLocalMessage['type'] ?? 'text';
          lastTime = lastLocalMessage['created_at'] ?? 0;
        }

        // 如果本地没有消息，尝试从服务器获取
        if (lastMessage.isEmpty) {
          try {
            final messagesResponse = await Api.getMessagesByUser(
              userId: userId.toString(),
              targetId: friendId.toString(),
              limit: 1,
            );

            if (messagesResponse['success'] == true) {
              final messages = messagesResponse['data'] ?? [];
              if (messages.isNotEmpty) {
                lastMessage = messages[0]['content'] ?? '';
                lastTime = messages[0]['created_at'] ?? 0;

                // 保存到本地存储
                if (messages[0] is Map<String, dynamic>) {
                  await LocalMessageStorage.saveMessage(
                    userId,
                    friendId,
                    Map<String, dynamic>.from(messages[0])
                  );
                }
              }
            }
          } catch (e) {
            debugPrint('[ChatService] 获取好友 $friendId 的最后一条消息失败: $e');
          }
        }

        // 如果没有格式化预览，生成一个
        if (formattedPreview.isEmpty && lastMessage.isNotEmpty) {
          formattedPreview = MessageFormatter.formatMessagePreview({
            'content': lastMessage,
            'type': lastMessageType
          });
        }

        chats.add({
          'id': friend['friend_id'],
          'type': 'single',
          'target_id': friend['friend_id'],
          'target_name': TextSanitizer.sanitize(friend['nickname'] ?? '好友${friend['friend_id']}'),
          'target_avatar': friend['avatar'] ?? '',
          'last_message': lastMessage.isNotEmpty ? TextSanitizer.sanitize(lastMessage) : '暂无消息',
          'formatted_preview': formattedPreview.isNotEmpty ? formattedPreview : (lastMessage.isNotEmpty ? TextSanitizer.sanitize(lastMessage) : '暂无消息'),
          'last_message_type': lastMessageType,
          'unread': 0, // TODO: 实现未读消息计数
          'updated_at': lastTime > 0 ? lastTime : DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'blocked': friend['blocked'] ?? 0,
          'is_self': false,
          'is_pinned': false, // 默认不置顶
          'is_muted': false, // 默认不静音
        });
      }

      // 按最后消息时间排序
      chats.sort((a, b) => (b['updated_at'] ?? 0).compareTo(a['updated_at'] ?? 0));

      return chats;
    } catch (e) {
      print('获取聊天列表失败: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async {
    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        return [];
      }

      debugPrint('[ChatService] 获取聊天消息: userId=$userId, chatId=$chatId');

      // 先尝试从本地存储获取消息
      final localMessages = await LocalMessageStorage.getMessages(userId, chatId);
      debugPrint('[ChatService] 本地消息数量: ${localMessages.length}');

      // 创建一个Map用于去重，使用消息ID或创建时间+内容作为键
      final Map<String, Map<String, dynamic>> uniqueMessages = {};

      // 先添加本地消息到去重Map
      for (var message in localMessages) {
        // 确保消息属于当前聊天
        final fromId = message['from_id'] ?? 0;
        final toId = message['to_id'] ?? 0;

        // 只处理与当前聊天相关的消息
        if ((fromId == userId && toId == chatId) || (fromId == chatId && toId == userId)) {
          final key = _getMessageKey(message);
          uniqueMessages[key] = message;
        }
      }

      try {
        // 然后从服务器获取最新消息
        final response = await Api.getMessagesByUser(
          userId: userId.toString(),
          targetId: chatId.toString(),
          limit: 50, // 增加页面大小，确保获取足够的消息
        );

        if (response['success'] == true) {
          final serverMessages = List<Map<String, dynamic>>.from(response['data'] ?? []);
          debugPrint('[ChatService] 服务器消息数量: ${serverMessages.length}');

          // 如果服务器返回了消息，处理并保存到本地
          if (serverMessages.isNotEmpty) {
            // 清理消息内容
            final sanitizedMessages = serverMessages.map((message) {
              return TextSanitizer.sanitizeMessage(message);
            }).toList();

            // 添加服务器消息到去重Map，并保存到本地
            for (var message in sanitizedMessages) {
              final key = _getMessageKey(message);
              uniqueMessages[key] = message;

              // 保存到本地存储
              await LocalMessageStorage.saveMessage(userId, chatId, message);
            }
          }
        }
      } catch (serverError) {
        debugPrint('[ChatService] 服务器请求失败: $serverError，使用本地缓存');
      }

      // 将去重后的消息转换为列表
      final resultMessages = uniqueMessages.values.toList();

      // 按时间排序
      resultMessages.sort((a, b) {
        final aTime = a['created_at'] ?? 0;
        final bTime = b['created_at'] ?? 0;
        return aTime.compareTo(bTime);
      });

      debugPrint('[ChatService] 去重后的消息数量: ${resultMessages.length}');

      return resultMessages;
    } catch (e) {
      debugPrint('[ChatService] 获取消息失败: $e');
      return [];
    }
  }

  // 获取消息的唯一键，用于去重
  static String _getMessageKey(Map<String, dynamic> message) {
    // 如果有ID，优先使用ID
    if (message['id'] != null && message['id'].toString().isNotEmpty) {
      return 'id_${message['id']}';
    }

    // 否则使用发送者ID+接收者ID+创建时间+内容的组合
    final fromId = message['from_id'] ?? '';
    final toId = message['to_id'] ?? '';
    final createdAt = message['created_at'] ?? '';
    final content = message['content'] ?? '';
    final type = message['type'] ?? '';

    return 'msg_${fromId}_${toId}_${createdAt}_${type}_${content.hashCode}';
  }

  static Future<bool> sendMessage(int chatId, String text, {int retryCount = 0}) async {
    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        return false;
      }

      // 创建本地消息对象
      final localMessage = {
        "from_id": userId,
        "to_id": chatId,
        "content": TextSanitizer.sanitize(text),
        "type": "text",
        "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
        "status": 0, // 发送中
        "retry_count": retryCount, // 记录重试次数
      };

      // 生成临时ID，用于标识本地消息
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode}';
      localMessage['temp_id'] = tempId;

      // 保存到本地存储
      await LocalMessageStorage.saveMessage(userId, chatId, localMessage);

      try {
        // 发送到服务器
        final response = await Api.sendMessage(
          targetId: chatId.toString(),
          content: TextSanitizer.sanitize(text),
          type: 'text',
        );

        if (response['success'] == true) {
          // 更新本地消息状态为已发送
          final updatedMessage = Map<String, dynamic>.from(localMessage);
          updatedMessage['status'] = 1; // 已发送
          updatedMessage['id'] = response['data']?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          updatedMessage['server_time'] = response['data']?['created_at'] ?? updatedMessage['created_at'];

          // 保存更新后的消息
          await LocalMessageStorage.saveMessage(userId, chatId, updatedMessage);

          return true;
        } else {
          // 更新本地消息状态为发送失败
          final updatedMessage = Map<String, dynamic>.from(localMessage);
          updatedMessage['status'] = 2; // 发送失败
          updatedMessage['error'] = response['msg'] ?? '发送失败';

          // 保存更新后的消息
          await LocalMessageStorage.saveMessage(userId, chatId, updatedMessage);

          // 如果重试次数小于3，则自动重试
          if (retryCount < 3) {
            debugPrint('[ChatService] 消息发送失败，准备重试 (${retryCount + 1}/3): ${response['msg']}');
            // 延迟2秒后重试
            await Future.delayed(Duration(seconds: 2));
            return sendMessage(chatId, text, retryCount: retryCount + 1);
          }

          return false;
        }
      } catch (e) {
        debugPrint('[ChatService] 发送消息到服务器失败: $e');

        // 更新本地消息状态为发送失败
        final updatedMessage = Map<String, dynamic>.from(localMessage);
        updatedMessage['status'] = 2; // 发送失败
        updatedMessage['error'] = e.toString();

        // 保存更新后的消息
        await LocalMessageStorage.saveMessage(userId, chatId, updatedMessage);

        // 如果重试次数小于3，则自动重试
        if (retryCount < 3) {
          debugPrint('[ChatService] 消息发送失败，准备重试 (${retryCount + 1}/3): $e');
          // 延迟2秒后重试
          await Future.delayed(Duration(seconds: 2));
          return sendMessage(chatId, text, retryCount: retryCount + 1);
        }

        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 发送消息失败: $e');
      return false;
    }
  }

  // 重试发送失败的消息
  static Future<bool> retrySendMessage(int chatId, Map<String, dynamic> failedMessage) async {
    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        return false;
      }

      // 获取消息内容和类型
      final content = failedMessage['content'] ?? '';
      final type = failedMessage['type'] ?? 'text';

      // 更新消息状态为发送中
      final updatingMessage = Map<String, dynamic>.from(failedMessage);
      updatingMessage['status'] = 0; // 发送中
      updatingMessage['retry_count'] = (updatingMessage['retry_count'] ?? 0) + 1;

      // 保存更新后的消息
      await LocalMessageStorage.saveMessage(userId, chatId, updatingMessage);

      // 根据消息类型发送
      if (type == 'text') {
        return sendMessage(chatId, content, retryCount: updatingMessage['retry_count']);
      } else {
        // 处理其他类型的消息重试
        debugPrint('[ChatService] 暂不支持重试非文本消息');
        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 重试发送消息失败: $e');
      return false;
    }
  }

  // 注意：不再需要单独的fetchSelfMessages和sendSelfMessage方法
  // 使用fetchMessages和sendMessage方法统一处理所有聊天，包括与自己的聊天
}
