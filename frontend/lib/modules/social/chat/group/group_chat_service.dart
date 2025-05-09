import 'package:flutter/foundation.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/common/text_sanitizer.dart';
import 'package:frontend/common/message_formatter.dart';

class GroupChatService {
  // 获取用户的群组列表
  static Future<List<Map<String, dynamic>>> fetchGroupList() async {
    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        return [];
      }

      final response = await Api.getGroupList(userId: userInfo.id.toString());
      if (response['success'] == true) {
        final List<dynamic> groups = response['data'] ?? [];

        // 转换为标准格式
        final List<Map<String, dynamic>> formattedGroups = [];

        for (var group in groups) {
          // 获取最后一条消息
          String lastMessage = '';
          String formattedPreview = '';
          String lastMessageType = 'text';
          int lastTime = 0;

          try {
            // 尝试获取群组最后一条消息
            final messagesResponse = await Api.getGroupMessages(
              groupId: group['group_id'].toString(),
              limit: 1,
            );

            if (messagesResponse['success'] == true) {
              final messages = messagesResponse['data'] ?? [];
              if (messages.isNotEmpty) {
                lastMessage = messages[0]['content'] ?? '';
                lastMessageType = messages[0]['type'] ?? 'text';
                lastTime = messages[0]['created_at'] ?? 0;

                // 格式化消息预览
                formattedPreview = MessageFormatter.formatMessagePreview({
                  'content': lastMessage,
                  'type': lastMessageType
                });
              }
            }
          } catch (e) {
            debugPrint('[GroupChatService] 获取群组 ${group['group_id']} 的最后一条消息失败: $e');
          }

          formattedGroups.add({
            'id': 'group_${group['group_id']}',
            'type': 'group',
            'group_id': group['group_id'],
            'target_id': group['group_id'],
            'target_name': TextSanitizer.sanitize(group['name'] ?? '群聊${group['group_id']}'),
            'target_avatar': group['avatar'] ?? '',
            'owner_id': group['owner_id'],
            'notice': group['notice'] ?? '',
            'member_count': group['member_count'] ?? 0,
            'last_message': lastMessage.isNotEmpty ? TextSanitizer.sanitize(lastMessage) : '暂无消息',
            'formatted_preview': formattedPreview.isNotEmpty ? formattedPreview : (lastMessage.isNotEmpty ? TextSanitizer.sanitize(lastMessage) : '暂无消息'),
            'last_message_type': lastMessageType,
            'unread': 0, // TODO: 实现未读消息计数
            'updated_at': lastTime > 0 ? lastTime : DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'is_pinned': false,
            'is_muted': false,
          });
        }

        // 按最后消息时间排序
        formattedGroups.sort((a, b) => (b['updated_at'] ?? 0).compareTo(a['updated_at'] ?? 0));

        return formattedGroups;
      } else {
        debugPrint('[GroupChatService] 获取群组列表失败: ${response['msg']}');
        return [];
      }
    } catch (e) {
      debugPrint('[GroupChatService] 获取群组列表异常: $e');
      return [];
    }
  }

  // 获取群组消息
  static Future<List<Map<String, dynamic>>> fetchGroupMessages(int groupId) async {
    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        return [];
      }

      debugPrint('[GroupChatService] 获取群组消息: groupId=$groupId');

      // 从服务器获取群组消息
      final response = await Api.getGroupMessages(
        groupId: groupId.toString(),
        limit: 50,
      );

      if (response['success'] == true) {
        final List<dynamic> messages = response['data'] ?? [];

        // 清理消息内容
        final List<Map<String, dynamic>> sanitizedMessages = [];
        for (var message in messages) {
          if (message is Map<String, dynamic>) {
            sanitizedMessages.add(TextSanitizer.sanitizeMessage(message));
          }
        }

        // 按时间排序
        sanitizedMessages.sort((a, b) {
          final aTime = a['created_at'] ?? 0;
          final bTime = b['created_at'] ?? 0;
          return aTime.compareTo(bTime);
        });

        return sanitizedMessages;
      } else {
        debugPrint('[GroupChatService] 获取群组消息失败: ${response['msg']}');
        return [];
      }
    } catch (e) {
      debugPrint('[GroupChatService] 获取群组消息异常: $e');
      return [];
    }
  }

  // 发送群组消息
  static Future<bool> sendGroupMessage(int groupId, String text, {List<String>? mentionedUsers}) async {
    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        return false;
      }

      // 发送到服务器
      final response = await Api.sendGroupMessage(
        groupId: groupId.toString(),
        content: TextSanitizer.sanitize(text),
        type: 'text',
        mentionedUsers: mentionedUsers,
      );

      if (response['success'] == true) {
        return true;
      } else {
        debugPrint('[GroupChatService] 发送群组消息失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[GroupChatService] 发送群组消息异常: $e');
      return false;
    }
  }

  // 获取群组成员
  static Future<List<Map<String, dynamic>>> fetchGroupMembers(int groupId) async {
    try {
      final response = await Api.getGroupMembers(groupId: groupId.toString());

      if (response['success'] == true) {
        final List<dynamic> members = response['data'] ?? [];

        // 转换为标准格式
        final List<Map<String, dynamic>> formattedMembers = [];

        for (var member in members) {
          if (member is Map<String, dynamic>) {
            formattedMembers.add({
              'user_id': member['user_id'],
              'nickname': TextSanitizer.sanitize(member['nickname'] ?? ''),
              'avatar': member['avatar'] ?? '',
              'join_time': member['join_time'] ?? 0,
              'is_owner': member['is_owner'] == 1 || member['is_owner'] == true,
              'is_admin': member['is_admin'] == 1 || member['is_admin'] == true,
            });
          }
        }

        return formattedMembers;
      } else {
        debugPrint('[GroupChatService] 获取群组成员失败: ${response['msg']}');
        return [];
      }
    } catch (e) {
      debugPrint('[GroupChatService] 获取群组成员异常: $e');
      return [];
    }
  }
}
