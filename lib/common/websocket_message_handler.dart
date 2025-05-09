import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'persistence.dart';
import 'platform_utils.dart';
import '../modules/social/chat/chat_service.dart';
import '../modules/social/chat/group/group_chat_service.dart';

/// WebSocket消息处理器
/// 用于处理WebSocket消息
class WebSocketMessageHandler {
  static final WebSocketMessageHandler _instance = WebSocketMessageHandler._internal();
  factory WebSocketMessageHandler() => _instance;

  WebSocketMessageHandler._internal();

  // 本地通知插件
  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;

  // 消息处理器
  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};

  // 通知ID
  int _notificationId = 0;

  /// 初始化
  Future<void> initialize() async {
    // 初始化本地通知插件
    await _initializeLocalNotifications();

    // 注册消息处理器
    _registerMessageHandlers();
  }

  /// 初始化本地通知插件
  Future<void> _initializeLocalNotifications() async {
    try {
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // 初始化设置
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      debugPrint('[WebSocketMessageHandler] 本地通知插件初始化成功');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 本地通知插件初始化失败: $e');
    }
  }

  /// 注册消息处理器
  void _registerMessageHandlers() {
    // 注册消息处理器
    _messageHandlers['message'] = _handleMessageMessage;
    _messageHandlers['friend_request'] = _handleFriendRequestMessage;
    _messageHandlers['friend_accept'] = _handleFriendAcceptMessage;
    _messageHandlers['friend_reject'] = _handleFriendRejectMessage;
    _messageHandlers['group_message'] = _handleGroupMessage;
    _messageHandlers['group_invitation'] = _handleGroupInvitationMessage;
    _messageHandlers['group_join'] = _handleGroupJoinMessage;
    _messageHandlers['group_leave'] = _handleGroupLeaveMessage;
    _messageHandlers['group_kick'] = _handleGroupKickMessage;
    _messageHandlers['group_dismiss'] = _handleGroupDismissMessage;
    _messageHandlers['voice_call'] = _handleVoiceCallMessage;
    _messageHandlers['video_call'] = _handleVideoCallMessage;
    _messageHandlers['call_accept'] = _handleCallAcceptMessage;
    _messageHandlers['call_reject'] = _handleCallRejectMessage;
    _messageHandlers['call_end'] = _handleCallEndMessage;
    _messageHandlers['system'] = _handleSystemMessage;
    _messageHandlers['heartbeat'] = _handleHeartbeatMessage;

    debugPrint('[WebSocketMessageHandler] 消息处理器注册成功');
  }

  /// 处理消息
  void handleMessage(Map<String, dynamic> message) {
    try {
      // 获取消息类型
      final type = message['type'];
      if (type == null) {
        debugPrint('[WebSocketMessageHandler] 消息类型为空');
        return;
      }

      // 获取消息处理器
      final handler = _messageHandlers[type];
      if (handler == null) {
        debugPrint('[WebSocketMessageHandler] 未找到消息处理器: $type');
        return;
      }

      // 处理消息
      handler(message);
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理消息失败: $e');
    }
  }

  /// 处理聊天消息
  void _handleMessageMessage(Map<String, dynamic> message) {
    try {
      // 获取消息内容
      final data = message['data'];
      if (data == null) {
        debugPrint('[WebSocketMessageHandler] 消息内容为空');
        return;
      }

      // 获取发送者ID
      final senderId = data['sender_id'];
      if (senderId == null) {
        debugPrint('[WebSocketMessageHandler] 发送者ID为空');
        return;
      }

      // 构建聊天消息对象
      final chatMessage = {
        'id': data['message_id'] ?? '',
        'sender_id': senderId,
        'sender_name': data['sender_name'] ?? '未知用户',
        'sender_avatar': data['sender_avatar'],
        'content': data['content'] ?? '',
        'type': data['message_type'] ?? 'text',
        'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'status': 'received',
        'is_read': false,
      };

      // 通知聊天服务
      try {
        debugPrint('[WebSocketMessageHandler] 收到新消息: $chatMessage');
      } catch (e) {
        debugPrint('[WebSocketMessageHandler] 处理新消息失败: $e');
      }

      // 获取发送者名称
      final senderName = data['sender_name'] ?? '未知用户';

      // 获取消息内容
      final content = data['content'] ?? '';

      // 获取消息类型
      final messageType = data['message_type'] ?? 'text';

      // 构建通知内容
      String notificationContent;
      if (messageType == 'text') {
        notificationContent = content;
      } else if (messageType == 'image') {
        notificationContent = '[图片]';
      } else if (messageType == 'video') {
        notificationContent = '[视频]';
      } else if (messageType == 'file') {
        notificationContent = '[文件]';
      } else if (messageType == 'voice') {
        notificationContent = '[语音]';
      } else if (messageType == 'location') {
        notificationContent = '[位置]';
      } else if (messageType == 'red_packet') {
        notificationContent = '[红包]';
      } else {
        notificationContent = '[未知消息类型]';
      }

      // 显示通知
      _showNotification(
        title: senderName,
        body: notificationContent,
        payload: 'message:$senderId',
      );

      debugPrint('[WebSocketMessageHandler] 处理聊天消息: $message');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理聊天消息失败: $e');
    }
  }

  /// 处理好友请求消息
  void _handleFriendRequestMessage(Map<String, dynamic> message) {
    try {
      // 获取消息内容
      final data = message['data'];
      if (data == null) {
        debugPrint('[WebSocketMessageHandler] 消息内容为空');
        return;
      }

      // 获取发送者ID
      final senderId = data['sender_id'];
      if (senderId == null) {
        debugPrint('[WebSocketMessageHandler] 发送者ID为空');
        return;
      }

      // 获取发送者名称
      final senderName = data['sender_name'] ?? '未知用户';

      // 获取验证消息
      final verifyMessage = data['verify_message'] ?? '';

      // 显示通知
      _showNotification(
        title: '好友请求',
        body: '$senderName 请求添加您为好友: $verifyMessage',
        payload: 'friend_request:$senderId',
      );

      debugPrint('[WebSocketMessageHandler] 处理好友请求消息: $message');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理好友请求消息失败: $e');
    }
  }

  /// 处理好友接受消息
  void _handleFriendAcceptMessage(Map<String, dynamic> message) {
    try {
      // 获取消息内容
      final data = message['data'];
      if (data == null) {
        debugPrint('[WebSocketMessageHandler] 消息内容为空');
        return;
      }

      // 获取发送者ID
      final senderId = data['sender_id'];
      if (senderId == null) {
        debugPrint('[WebSocketMessageHandler] 发送者ID为空');
        return;
      }

      // 获取发送者名称
      final senderName = data['sender_name'] ?? '未知用户';

      // 显示通知
      _showNotification(
        title: '好友请求已接受',
        body: '$senderName 已接受您的好友请求',
        payload: 'friend_accept:$senderId',
      );

      debugPrint('[WebSocketMessageHandler] 处理好友接受消息: $message');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理好友接受消息失败: $e');
    }
  }

  /// 处理好友拒绝消息
  void _handleFriendRejectMessage(Map<String, dynamic> message) {
    try {
      // 获取消息内容
      final data = message['data'];
      if (data == null) {
        debugPrint('[WebSocketMessageHandler] 消息内容为空');
        return;
      }

      // 获取发送者ID
      final senderId = data['sender_id'];
      if (senderId == null) {
        debugPrint('[WebSocketMessageHandler] 发送者ID为空');
        return;
      }

      // 获取发送者名称
      final senderName = data['sender_name'] ?? '未知用户';

      // 显示通知
      _showNotification(
        title: '好友请求已拒绝',
        body: '$senderName 已拒绝您的好友请求',
        payload: 'friend_reject:$senderId',
      );

      debugPrint('[WebSocketMessageHandler] 处理好友拒绝消息: $message');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理好友拒绝消息失败: $e');
    }
  }

  /// 处理群聊消息
  void _handleGroupMessage(Map<String, dynamic> message) {
    try {
      // 获取消息内容
      final data = message['data'];
      if (data == null) {
        debugPrint('[WebSocketMessageHandler] 群聊消息内容为空');
        return;
      }

      // 获取群组ID
      final groupId = data['group_id'];
      if (groupId == null) {
        debugPrint('[WebSocketMessageHandler] 群组ID为空');
        return;
      }

      // 获取发送者ID
      final senderId = data['sender_id'];
      if (senderId == null) {
        debugPrint('[WebSocketMessageHandler] 发送者ID为空');
        return;
      }

      // 构建群聊消息对象
      final groupMessage = {
        'id': data['message_id'] ?? '',
        'sender_id': senderId,
        'sender_name': data['sender_name'] ?? '未知用户',
        'sender_avatar': data['sender_avatar'],
        'group_id': groupId,
        'content': data['content'] ?? '',
        'type': data['message_type'] ?? 'text',
        'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      };

      // 通知群聊服务
      try {
        debugPrint('[WebSocketMessageHandler] 收到新群聊消息: $groupMessage');
      } catch (e) {
        debugPrint('[WebSocketMessageHandler] 处理新群聊消息失败: $e');
      }

      // 获取发送者名称
      final senderName = data['sender_name'] ?? '未知用户';

      // 获取群组名称
      final groupName = data['group_name'] ?? '未知群组';

      // 获取消息内容
      final content = data['content'] ?? '';

      // 获取消息类型
      final messageType = data['message_type'] ?? 'text';

      // 构建通知内容
      String notificationContent;
      if (messageType == 'text') {
        notificationContent = content;
      } else if (messageType == 'image') {
        notificationContent = '[图片]';
      } else if (messageType == 'video') {
        notificationContent = '[视频]';
      } else if (messageType == 'file') {
        notificationContent = '[文件]';
      } else if (messageType == 'voice') {
        notificationContent = '[语音]';
      } else if (messageType == 'location') {
        notificationContent = '[位置]';
      } else if (messageType == 'red_packet') {
        notificationContent = '[红包]';
      } else {
        notificationContent = '[未知消息类型]';
      }

      // 显示通知
      _showNotification(
        title: '$groupName - $senderName',
        body: notificationContent,
        payload: 'group_message:$groupId',
      );

      debugPrint('[WebSocketMessageHandler] 处理群聊消息: $message');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理群聊消息失败: $e');
    }
  }

  /// 处理群组邀请消息
  void _handleGroupInvitationMessage(Map<String, dynamic> message) {
    // TODO: 实现群组邀请消息处理
    debugPrint('[WebSocketMessageHandler] 处理群组邀请消息: $message');
  }

  /// 处理群组加入消息
  void _handleGroupJoinMessage(Map<String, dynamic> message) {
    // TODO: 实现群组加入消息处理
    debugPrint('[WebSocketMessageHandler] 处理群组加入消息: $message');
  }

  /// 处理群组离开消息
  void _handleGroupLeaveMessage(Map<String, dynamic> message) {
    // TODO: 实现群组离开消息处理
    debugPrint('[WebSocketMessageHandler] 处理群组离开消息: $message');
  }

  /// 处理群组踢出消息
  void _handleGroupKickMessage(Map<String, dynamic> message) {
    // TODO: 实现群组踢出消息处理
    debugPrint('[WebSocketMessageHandler] 处理群组踢出消息: $message');
  }

  /// 处理群组解散消息
  void _handleGroupDismissMessage(Map<String, dynamic> message) {
    // TODO: 实现群组解散消息处理
    debugPrint('[WebSocketMessageHandler] 处理群组解散消息: $message');
  }

  /// 处理语音通话消息
  void _handleVoiceCallMessage(Map<String, dynamic> message) {
    // TODO: 实现语音通话消息处理
    debugPrint('[WebSocketMessageHandler] 处理语音通话消息: $message');
  }

  /// 处理视频通话消息
  void _handleVideoCallMessage(Map<String, dynamic> message) {
    // TODO: 实现视频通话消息处理
    debugPrint('[WebSocketMessageHandler] 处理视频通话消息: $message');
  }

  /// 处理通话接受消息
  void _handleCallAcceptMessage(Map<String, dynamic> message) {
    // TODO: 实现通话接受消息处理
    debugPrint('[WebSocketMessageHandler] 处理通话接受消息: $message');
  }

  /// 处理通话拒绝消息
  void _handleCallRejectMessage(Map<String, dynamic> message) {
    // TODO: 实现通话拒绝消息处理
    debugPrint('[WebSocketMessageHandler] 处理通话拒绝消息: $message');
  }

  /// 处理通话结束消息
  void _handleCallEndMessage(Map<String, dynamic> message) {
    // TODO: 实现通话结束消息处理
    debugPrint('[WebSocketMessageHandler] 处理通话结束消息: $message');
  }

  /// 处理系统消息
  void _handleSystemMessage(Map<String, dynamic> message) {
    // TODO: 实现系统消息处理
    debugPrint('[WebSocketMessageHandler] 处理系统消息: $message');
  }

  /// 处理心跳消息
  void _handleHeartbeatMessage(Map<String, dynamic> message) {
    // 心跳消息不需要处理
    debugPrint('[WebSocketMessageHandler] 处理心跳消息: $message');
  }

  /// 显示通知
  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // 检查通知设置
      final notificationSettings = Persistence.getNotificationSettings();
      final enableNotification = notificationSettings['message'] == true;
      if (!enableNotification) {
        debugPrint('[WebSocketMessageHandler] 通知已禁用');
        return;
      }

      // 检查是否是桌面平台
      if (PlatformUtils.isDesktop) {
        // 桌面平台使用系统通知
        await _showDesktopNotification(title, body, payload);
      } else {
        // 移动平台使用本地通知
        await _showMobileNotification(title, body, payload);
      }
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 显示通知失败: $e');
    }
  }

  /// 显示桌面通知
  Future<void> _showDesktopNotification(String title, String body, String? payload) async {
    try {
      if (_flutterLocalNotificationsPlugin == null) {
        debugPrint('[WebSocketMessageHandler] 本地通知插件未初始化');
        return;
      }

      // 构建通知详情
      final platformChannelSpecifics = NotificationDetails(
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // 显示通知
      await _flutterLocalNotificationsPlugin!.show(
        _notificationId++,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      debugPrint('[WebSocketMessageHandler] 显示桌面通知: $title, $body');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 显示桌面通知失败: $e');
    }
  }

  /// 显示移动通知
  Future<void> _showMobileNotification(String title, String body, String? payload) async {
    try {
      if (_flutterLocalNotificationsPlugin == null) {
        debugPrint('[WebSocketMessageHandler] 本地通知插件未初始化');
        return;
      }

      // 构建通知详情
      final platformChannelSpecifics = NotificationDetails(
        android: AndroidNotificationDetails(
          'message_channel',
          'Messages',
          channelDescription: 'Notification channel for messages',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // 显示通知
      await _flutterLocalNotificationsPlugin!.show(
        _notificationId++,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      debugPrint('[WebSocketMessageHandler] 显示移动通知: $title, $body');
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 显示移动通知失败: $e');
    }
  }

  /// iOS本地通知回调
  void _onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) {
    debugPrint('[WebSocketMessageHandler] 收到iOS本地通知: $id, $title, $body, $payload');
  }

  /// 通知响应回调
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('[WebSocketMessageHandler] 收到通知响应: ${response.payload}');

    // 处理通知点击
    _handleNotificationClick(response.payload);
  }

  /// 处理通知点击
  void _handleNotificationClick(String? payload) {
    if (payload == null || payload.isEmpty) {
      debugPrint('[WebSocketMessageHandler] 通知负载为空');
      return;
    }

    try {
      // 解析负载
      final parts = payload.split(':');
      if (parts.length < 2) {
        debugPrint('[WebSocketMessageHandler] 通知负载格式错误: $payload');
        return;
      }

      final type = parts[0];
      final id = parts[1];

      // 根据类型处理
      if (type == 'message') {
        // 跳转到聊天页面
        debugPrint('[WebSocketMessageHandler] 跳转到聊天页面: $id');
      } else if (type == 'friend_request') {
        // 跳转到好友请求页面
        debugPrint('[WebSocketMessageHandler] 跳转到好友请求页面: $id');
      } else if (type == 'friend_accept') {
        // 跳转到好友页面
        debugPrint('[WebSocketMessageHandler] 跳转到好友页面: $id');
      } else if (type == 'friend_reject') {
        // 跳转到好友页面
        debugPrint('[WebSocketMessageHandler] 跳转到好友页面: $id');
      } else {
        debugPrint('[WebSocketMessageHandler] 未知通知类型: $type');
      }
    } catch (e) {
      debugPrint('[WebSocketMessageHandler] 处理通知点击失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    // 清空消息处理器
    _messageHandlers.clear();

    debugPrint('[WebSocketMessageHandler] 资源已释放');
  }
}
