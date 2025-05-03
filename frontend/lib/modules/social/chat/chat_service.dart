import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/common/text_sanitizer.dart';

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
        'unread_count': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'blocked': 0,
        'is_self': true,
      });

      // 添加好友聊天
      for (var friend in friends) {
        final friendId = friend['friend_id'];

        // 尝试从本地存储获取最后一条消息
        String lastMessage = '';
        int lastTime = 0;

        // 先从本地存储获取最后一条消息
        final lastLocalMessage = await LocalMessageStorage.getLastMessage(userId, friendId);
        if (lastLocalMessage != null) {
          lastMessage = lastLocalMessage['content'] ?? '';
          lastTime = lastLocalMessage['created_at'] ?? 0;
        }

        // 如果本地没有消息，尝试从服务器获取
        if (lastMessage.isEmpty) {
          try {
            final messagesResponse = await Api.getMessagesByUser(
              userId: userId.toString(),
              targetId: friendId.toString(),
              page: 1,
              pageSize: 1,
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

        chats.add({
          'id': friend['friend_id'],
          'type': 'single',
          'target_id': friend['friend_id'],
          'target_name': TextSanitizer.sanitize(friend['nickname'] ?? '好友${friend['friend_id']}'),
          'target_avatar': friend['avatar'] ?? '',
          'last_message': lastMessage.isNotEmpty ? TextSanitizer.sanitize(lastMessage) : '暂无消息',
          'unread': 0, // TODO: 实现未读消息计数
          'updated_at': lastTime > 0 ? lastTime : DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'blocked': friend['blocked'] ?? 0,
          'is_self': false,
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

      // 先尝试从本地存储获取消息
      final localMessages = await LocalMessageStorage.getMessages(userId, chatId);

      try {
        // 然后从服务器获取最新消息
        final response = await Api.getMessagesByUser(
          userId: userId.toString(),
          targetId: chatId.toString(),
        );

        if (response['success'] == true) {
          final serverMessages = List<Map<String, dynamic>>.from(response['data'] ?? []);

          // 如果服务器返回了消息，保存到本地
          if (serverMessages.isNotEmpty) {
            // 清理消息内容
            final sanitizedMessages = serverMessages.map((message) {
              return TextSanitizer.sanitizeMessage(message);
            }).toList();

            // 保存每条消息到本地存储
            for (var message in sanitizedMessages) {
              await LocalMessageStorage.saveMessage(userId, chatId, message);
            }

            // 返回清理后的服务器消息
            return sanitizedMessages;
          }
        }

        // 如果服务器请求失败但有本地消息，返回本地消息
        if (localMessages.isNotEmpty) {
          debugPrint('[ChatService] 使用本地缓存的消息: ${localMessages.length}条');
          // 清理本地消息内容
          final sanitizedLocalMessages = localMessages.map((message) {
            return TextSanitizer.sanitizeMessage(message);
          }).toList();
          return sanitizedLocalMessages;
        }

        return [];
      } catch (serverError) {
        debugPrint('[ChatService] 服务器请求失败: $serverError，使用本地缓存');

        // 如果服务器请求失败但有本地消息，返回本地消息
        if (localMessages.isNotEmpty) {
          // 清理本地消息内容
          final sanitizedLocalMessages = localMessages.map((message) {
            return TextSanitizer.sanitizeMessage(message);
          }).toList();
          return sanitizedLocalMessages;
        }

        return [];
      }
    } catch (e) {
      debugPrint('[ChatService] 获取消息失败: $e');
      return [];
    }
  }

  static Future<bool> sendMessage(int chatId, String text) async {
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
      };

      // 保存到本地存储
      await LocalMessageStorage.saveMessage(userId, chatId, localMessage);

      try {
        // 发送到服务器
        final response = await Api.sendMessage(
          fromId: userId.toString(),
          toId: chatId.toString(),
          content: TextSanitizer.sanitize(text),
          type: 'text',
        );

        if (response['success'] == true) {
          // 更新本地消息状态为已发送
          final updatedMessage = Map<String, dynamic>.from(localMessage);
          updatedMessage['status'] = 1; // 已发送
          updatedMessage['id'] = response['data']?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

          // 保存更新后的消息
          await LocalMessageStorage.saveMessage(userId, chatId, updatedMessage);

          return true;
        } else {
          // 更新本地消息状态为发送失败
          final updatedMessage = Map<String, dynamic>.from(localMessage);
          updatedMessage['status'] = 2; // 发送失败

          // 保存更新后的消息
          await LocalMessageStorage.saveMessage(userId, chatId, updatedMessage);

          return false;
        }
      } catch (e) {
        debugPrint('[ChatService] 发送消息到服务器失败: $e');

        // 更新本地消息状态为发送失败
        final updatedMessage = Map<String, dynamic>.from(localMessage);
        updatedMessage['status'] = 2; // 发送失败

        // 保存更新后的消息
        await LocalMessageStorage.saveMessage(userId, chatId, updatedMessage);

        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 发送消息失败: $e');
      return false;
    }
  }

  // 注意：不再需要单独的fetchSelfMessages和sendSelfMessage方法
  // 使用fetchMessages和sendMessage方法统一处理所有聊天，包括与自己的聊天
}
