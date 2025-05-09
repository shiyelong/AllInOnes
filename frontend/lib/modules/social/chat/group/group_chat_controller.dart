import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/websocket_manager.dart';

class GroupChatController {
  final String groupId;
  final StreamController<List<Map<String, dynamic>>> _messagesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _membersController = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  Timer? _refreshTimer;
  bool _isInitialized = false;

  // 获取消息流
  Stream<List<Map<String, dynamic>>> get messagesStream => _messagesController.stream;

  // 获取成员流
  Stream<List<Map<String, dynamic>>> get membersStream => _membersController.stream;

  GroupChatController({required this.groupId}) {
    _initialize();
  }

  // 初始化
  Future<void> _initialize() async {
    if (_isInitialized) return;

    // 加载初始数据
    await Future.wait([
      loadMessages(),
      loadMembers(),
    ]);

    // 设置定时刷新
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      loadMessages();
    });

    // 监听WebSocket消息
    WebSocketManager.instance.addListener(_handleWebSocketMessage);

    _isInitialized = true;
  }

  // 加载消息
  Future<void> loadMessages() async {
    try {
      final result = await Api.getGroupMessages(
        groupId: groupId,
        limit: 50,
        offset: 0,
      );

      if (result['success'] == true) {
        _messages = List<Map<String, dynamic>>.from(result['data'] ?? []);
        // 按时间排序（从旧到新）
        _messages.sort((a, b) => (a['created_at'] ?? 0).compareTo(b['created_at'] ?? 0));
        _messagesController.add(_messages);
      }
    } catch (e) {
      debugPrint('加载群聊消息失败: $e');
    }
  }

  // 加载成员
  Future<void> loadMembers() async {
    try {
      final result = await Api.getGroupMembers(
        groupId: groupId,
      );

      if (result['success'] == true) {
        _members = List<Map<String, dynamic>>.from(result['data'] ?? []);
        _membersController.add(_members);
      }
    } catch (e) {
      debugPrint('加载群成员失败: $e');
    }
  }

  // 发送消息
  Future<bool> sendMessage(String content, String type, {List<int>? mentionedUsers}) async {
    if (content.isEmpty) return false;

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        throw Exception('用户未登录');
      }

      final result = await Api.sendGroupMessage(
        groupId: groupId,
        content: content,
        type: type,
        mentionedUsers: mentionedUsers ?? [],
      );

      if (result['success'] == true) {
        // 添加新消息到列表
        final newMessage = result['data'];
        if (newMessage != null) {
          _messages.add(Map<String, dynamic>.from(newMessage));
          _messagesController.add(_messages);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('发送群聊消息失败: $e');
      return false;
    }
  }

  // 处理WebSocket消息
  void _handleWebSocketMessage(dynamic message) {
    if (message == null) return;

    try {
      final data = message as Map<String, dynamic>;

      // 处理群聊消息
      if (data['type'] == 'group_message' && data['group_id'].toString() == groupId) {
        // 添加新消息
        _messages.add(Map<String, dynamic>.from(data['message']));
        _messagesController.add(_messages);
      }

      // 处理群成员变更
      else if (data['type'] == 'group_member_changed' && data['group_id'].toString() == groupId) {
        // 重新加载群成员
        loadMembers();
      }
    } catch (e) {
      debugPrint('处理WebSocket消息失败: $e');
    }
  }

  // 释放资源
  void dispose() {
    _refreshTimer?.cancel();
    WebSocketManager.instance.removeListener(_handleWebSocketMessage);
    _messagesController.close();
    _membersController.close();
  }
}
