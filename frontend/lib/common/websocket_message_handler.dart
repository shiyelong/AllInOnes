import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:frontend/common/websocket_manager.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/modules/social/chat/chat_service.dart';
import 'package:frontend/modules/social/chat/group/group_chat_service.dart';

/// WebSocket消息处理器
/// 用于处理WebSocket接收到的各种消息
class WebSocketMessageHandler {
  static final WebSocketMessageHandler _instance = WebSocketMessageHandler._internal();
  factory WebSocketMessageHandler() => _instance;

  WebSocketMessageHandler._internal();

  // 消息监听器
  final Map<String, List<Function(Map<String, dynamic>)>> _messageListeners = {};

  // 初始化
  void initialize() {
    // 注册WebSocket消息监听器
    WebSocketManager().addMessageListener('*', _handleMessage);

    // 注册特定类型的消息监听器
    WebSocketManager().addMessageListener('chat_message', _handleChatMessage);
    WebSocketManager().addMessageListener('group_message', _handleGroupMessage);
    WebSocketManager().addMessageListener('friend_request', _handleFriendRequest);
    WebSocketManager().addMessageListener('friend_accepted', _handleFriendAccepted);
    WebSocketManager().addMessageListener('friend_rejected', _handleFriendRejected);
    WebSocketManager().addMessageListener('group_invitation', _handleGroupInvitation);
    WebSocketManager().addMessageListener('group_joined', _handleGroupJoined);
    WebSocketManager().addMessageListener('group_left', _handleGroupLeft);
    WebSocketManager().addMessageListener('user_online', _handleUserOnline);
    WebSocketManager().addMessageListener('user_offline', _handleUserOffline);
    WebSocketManager().addMessageListener('message_read', _handleMessageRead);
    WebSocketManager().addMessageListener('typing', _handleTyping);

    debugPrint('[WebSocketMessageHandler] 初始化完成');
  }

  // 释放资源
  void dispose() {
    // 移除WebSocket消息监听器
    WebSocketManager().removeMessageListener('*', _handleMessage);

    // 移除特定类型的消息监听器
    WebSocketManager().removeMessageListener('chat_message', _handleChatMessage);
    WebSocketManager().removeMessageListener('group_message', _handleGroupMessage);
    WebSocketManager().removeMessageListener('friend_request', _handleFriendRequest);
    WebSocketManager().removeMessageListener('friend_accepted', _handleFriendAccepted);
    WebSocketManager().removeMessageListener('friend_rejected', _handleFriendRejected);
    WebSocketManager().removeMessageListener('group_invitation', _handleGroupInvitation);
    WebSocketManager().removeMessageListener('group_joined', _handleGroupJoined);
    WebSocketManager().removeMessageListener('group_left', _handleGroupLeft);
    WebSocketManager().removeMessageListener('user_online', _handleUserOnline);
    WebSocketManager().removeMessageListener('user_offline', _handleUserOffline);
    WebSocketManager().removeMessageListener('message_read', _handleMessageRead);
    WebSocketManager().removeMessageListener('typing', _handleTyping);

    // 清空消息监听器
    _messageListeners.clear();

    debugPrint('[WebSocketMessageHandler] 资源已释放');
  }

  // 处理所有消息
  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'];
    debugPrint('[WebSocketMessageHandler] 收到消息: $type');

    // 通知消息监听器
    if (_messageListeners.containsKey(type)) {
      for (var listener in _messageListeners[type]!) {
        listener(message);
      }
    }

    // 通知通用消息监听器
    if (_messageListeners.containsKey('*')) {
      for (var listener in _messageListeners['*']!) {
        listener(message);
      }
    }
  }

  // 处理单聊消息
  void _handleChatMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'];
      if (data == null) return;

      final fromId = data['from_id'];
      final toId = data['to_id'];
      final content = data['content'];
      final type = data['type'] ?? 'text';
      final messageId = data['id'];
      final timestamp = data['created_at'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

      debugPrint('[WebSocketMessageHandler] 收到单聊消息: $fromId -> $toId: $content');

      // 获取当前用户ID
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) return;

      final userId = userInfo.id;

      // 保存消息到本地存储
      final chatMessage = {
        'id': messageId,
        'from_id': fromId,
        'to_id': toId,
        'content': content,
        'type': type,
        'created_at': timestamp,
        'status': 1, // 已发送
      };

      // 如果有额外数据，添加到消息中
      if (data['extra'] != null) {
        chatMessage['extra'] = data['extra'];
      }

      // 保存消息到本地存储
      LocalMessageStorage.saveMessage(userId, fromId == userId ? toId : fromId, chatMessage);

      // 通知聊天服务
      debugPrint('[WebSocketMessageHandler] 收到新消息: $chatMessage');
      // 如果ChatService存在，则通知
      try {
        // 这里应该调用ChatService.notifyNewMessage，但暂时注释掉，等ChatService实现后再启用
        // ChatService.notifyNewMessage(chatMessage);
      } catch (e) {
        debugPrint('[WebSocketMessageHandler] 通知ChatService失败: $e');
      }
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理单聊消息失败: $e');
    }
  }

  // 处理群聊消息
  void _handleGroupMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'];
      if (data == null) return;

      final fromId = data['from_id'];
      final groupId = data['group_id'];
      final content = data['content'];
      final type = data['type'] ?? 'text';
      final messageId = data['id'];
      final timestamp = data['created_at'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

      debugPrint('[WebSocketMessageHandler] 收到群聊消息: $fromId -> 群$groupId: $content');

      // 获取当前用户ID
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) return;

      // 通知群聊服务
      final groupMessage = {
        'id': messageId,
        'sender_id': fromId,
        'group_id': groupId,
        'content': content,
        'type': type,
        'created_at': timestamp,
        'status': 1, // 已发送
        'extra': data['extra'],
      };

      debugPrint('[WebSocketMessageHandler] 收到群聊消息: $groupMessage');
      // 如果GroupChatService存在，则通知
      try {
        // 这里应该调用GroupChatService.notifyNewGroupMessage，但暂时注释掉，等GroupChatService实现后再启用
        // GroupChatService.notifyNewGroupMessage(groupMessage);
      } catch (e) {
        debugPrint('[WebSocketMessageHandler] 通知GroupChatService失败: $e');
      }
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理群聊消息失败: $e');
    }
  }

  // 处理好友请求
  void _handleFriendRequest(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 收到好友请求: ${message['data']}');
    // 实现好友请求处理逻辑
  }

  // 处理好友接受
  void _handleFriendAccepted(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 好友请求已接受: ${message['data']}');
    // 实现好友接受处理逻辑
  }

  // 处理好友拒绝
  void _handleFriendRejected(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 好友请求已拒绝: ${message['data']}');
    // 实现好友拒绝处理逻辑
  }

  // 处理群组邀请
  void _handleGroupInvitation(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 收到群组邀请: ${message['data']}');
    // 实现群组邀请处理逻辑
  }

  // 处理加入群组
  void _handleGroupJoined(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 已加入群组: ${message['data']}');
    // 实现加入群组处理逻辑
  }

  // 处理离开群组
  void _handleGroupLeft(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 已离开群组: ${message['data']}');
    // 实现离开群组处理逻辑
  }

  // 处理用户上线
  void _handleUserOnline(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 用户上线: ${message['data']}');
    // 实现用户上线处理逻辑
  }

  // 处理用户离线
  void _handleUserOffline(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 用户离线: ${message['data']}');
    // 实现用户离线处理逻辑
  }

  // 处理消息已读
  void _handleMessageRead(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 消息已读: ${message['data']}');
    // 实现消息已读处理逻辑
  }

  // 处理正在输入
  void _handleTyping(Map<String, dynamic> message) {
    debugPrint('[WebSocketMessageHandler] 正在输入: ${message['data']}');
    // 实现正在输入处理逻辑
  }

  // 添加消息监听器
  void addMessageListener(String type, Function(Map<String, dynamic>) listener) {
    if (!_messageListeners.containsKey(type)) {
      _messageListeners[type] = [];
    }

    if (!_messageListeners[type]!.contains(listener)) {
      _messageListeners[type]!.add(listener);
    }
  }

  // 移除消息监听器
  void removeMessageListener(String type, Function(Map<String, dynamic>) listener) {
    if (_messageListeners.containsKey(type)) {
      _messageListeners[type]!.remove(listener);

      if (_messageListeners[type]!.isEmpty) {
        _messageListeners.remove(type);
      }
    }
  }
}
