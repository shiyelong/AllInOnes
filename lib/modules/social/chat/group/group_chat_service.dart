import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../common/api.dart';
import '../../../../common/persistence.dart';

/// 群聊服务
/// 用于管理群聊消息、群组等
class GroupChatService {
  static final GroupChatService _instance = GroupChatService._internal();
  factory GroupChatService() => _instance;

  GroupChatService._internal();

  // 消息监听器
  final List<Function(Map<String, dynamic>)> _messageListeners = [];

  // 群组监听器
  final List<Function(List<Map<String, dynamic>>)> _groupListeners = [];

  // 未读消息数监听器
  final List<Function(int)> _unreadCountListeners = [];

  // 消息状态监听器
  final List<Function(String, String)> _messageStatusListeners = [];

  // 群组列表
  List<Map<String, dynamic>> _groups = [];

  // 聊天消息缓存
  final Map<String, List<Map<String, dynamic>>> _messageCache = {};

  // 群成员缓存
  final Map<String, List<Map<String, dynamic>>> _memberCache = {};

  // 未读消息数
  int _totalUnreadCount = 0;

  // 获取群组列表
  List<Map<String, dynamic>> get groups => _groups;

  // 获取未读消息数
  int get totalUnreadCount => _totalUnreadCount;

  /// 初始化
  Future<void> initialize() async {
    debugPrint('[GroupChatService] 初始化');

    // 加载群组列表
    await loadGroups();
  }

  /// 加载群组列表
  Future<void> loadGroups() async {
    try {
      // 调用API获取群组列表
      final response = await Api.getGroups();

      if (response['success'] == true) {
        // 更新群组列表
        _groups = List<Map<String, dynamic>>.from(response['data']['groups']);

        // 计算总未读消息数
        _calculateTotalUnreadCount();

        // 通知群组监听器
        _notifyGroupListeners();

        debugPrint('[GroupChatService] 加载群组列表成功: ${_groups.length}个群组');
      } else {
        debugPrint('[GroupChatService] 加载群组列表失败: ${response['msg']}');
      }
    } catch (e) {
      debugPrint('[GroupChatService] 加载群组列表异常: $e');
    }
  }

  /// 加载群聊记录
  Future<List<Map<String, dynamic>>> loadGroupChatHistory(String groupId, {String? lastMessageId, int limit = 20}) async {
    try {
      // 调用API获取群聊记录
      final response = await Api.getGroupChatHistory(
        groupId: groupId,
        lastMessageId: lastMessageId,
        limit: limit,
      );

      if (response['success'] == true) {
        // 获取消息列表
        final messages = List<Map<String, dynamic>>.from(response['data']['messages']);

        // 更新消息缓存
        if (lastMessageId == null) {
          // 如果是第一次加载，则替换缓存
          _messageCache[groupId] = messages;
        } else {
          // 如果是加载更多，则追加到缓存
          _messageCache[groupId] = [..._messageCache[groupId] ?? [], ...messages];
        }

        debugPrint('[GroupChatService] 加载群聊记录成功: ${messages.length}条消息');

        return messages;
      } else {
        debugPrint('[GroupChatService] 加载群聊记录失败: ${response['msg']}');
        return [];
      }
    } catch (e) {
      debugPrint('[GroupChatService] 加载群聊记录异常: $e');
      return [];
    }
  }

  /// 发送群聊消息
  Future<Map<String, dynamic>> sendGroupMessage({
    required String groupId,
    required String content,
    required String type,
  }) async {
    try {
      // 生成临时消息ID
      final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${groupId}';

      // 获取用户信息
      final userInfo = Persistence.getUserInfo();
      final userId = Persistence.getUserId();

      // 构建消息对象
      final message = {
        'id': tempMessageId,
        'sender_id': userId,
        'sender_name': userInfo?['nickname'] ?? '我',
        'sender_avatar': userInfo?['avatar'],
        'group_id': groupId,
        'content': content,
        'type': type,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'sending',
      };

      // 添加到消息缓存
      if (_messageCache.containsKey(groupId)) {
        _messageCache[groupId] = [message, ..._messageCache[groupId]!];
      } else {
        _messageCache[groupId] = [message];
      }

      // 更新群组列表
      _updateGroup(groupId, message);

      // 通知消息监听器
      _notifyMessageListeners(message);

      // 调用API发送群聊消息
      final response = await Api.sendGroupMessage(
        groupId: groupId,
        content: content,
        type: type,
      );

      if (response['success'] == true) {
        // 获取真实消息ID
        final realMessageId = response['data']['message_id'];

        // 更新消息状态
        _updateMessageStatus(tempMessageId, 'sent');

        // 更新消息ID
        _updateMessageId(tempMessageId, realMessageId);

        debugPrint('[GroupChatService] 发送群聊消息成功: $realMessageId');

        return {
          'success': true,
          'message_id': realMessageId,
        };
      } else {
        // 更新消息状态
        _updateMessageStatus(tempMessageId, 'failed');

        debugPrint('[GroupChatService] 发送群聊消息失败: ${response['msg']}');

        return {
          'success': false,
          'msg': response['msg'],
        };
      }
    } catch (e) {
      debugPrint('[GroupChatService] 发送群聊消息异常: $e');

      return {
        'success': false,
        'msg': '发送群聊消息异常: $e',
      };
    }
  }

  /// 标记群聊消息为已读
  Future<bool> markGroupMessagesAsRead(String groupId) async {
    try {
      // 获取最后一条消息ID
      final lastMessageId = _getLastMessageId(groupId);
      if (lastMessageId == null) {
        debugPrint('[GroupChatService] 没有消息需要标记为已读');
        return true;
      }

      // 调用API标记群聊消息为已读
      final response = await Api.markGroupMessagesAsRead(
        groupId: groupId,
        lastMessageId: lastMessageId,
      );

      if (response['success'] == true) {
        // 更新群组未读数
        _updateGroupUnreadCount(groupId, 0);

        debugPrint('[GroupChatService] 标记群聊消息为已读成功');
        return true;
      } else {
        debugPrint('[GroupChatService] 标记群聊消息为已读失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[GroupChatService] 标记群聊消息为已读异常: $e');
      return false;
    }
  }

  /// 撤回群聊消息
  Future<bool> recallGroupMessage(String messageId) async {
    try {
      // 调用API撤回群聊消息
      final response = await Api.recallGroupMessage(
        messageId: messageId,
      );

      if (response['success'] == true) {
        // 更新消息状态
        _updateMessageRecallStatus(messageId, true);

        debugPrint('[GroupChatService] 撤回群聊消息成功');
        return true;
      } else {
        debugPrint('[GroupChatService] 撤回群聊消息失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[GroupChatService] 撤回群聊消息异常: $e');
      return false;
    }
  }

  /// 获取群成员列表
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      // 检查缓存
      if (_memberCache.containsKey(groupId)) {
        return _memberCache[groupId]!;
      }

      // 调用API获取群成员列表
      final response = await Api.getGroupMembers(groupId: groupId);

      if (response['success'] == true) {
        // 获取成员列表
        final members = List<Map<String, dynamic>>.from(response['data']['members']);

        // 更新缓存
        _memberCache[groupId] = members;

        debugPrint('[GroupChatService] 获取群成员列表成功: ${members.length}个成员');

        return members;
      } else {
        debugPrint('[GroupChatService] 获取群成员列表失败: ${response['msg']}');
        return [];
      }
    } catch (e) {
      debugPrint('[GroupChatService] 获取群成员列表异常: $e');
      return [];
    }
  }

  /// 创建群组
  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String avatar,
    required List<String> memberIds,
  }) async {
    try {
      // 调用API创建群组
      final response = await Api.createGroup(
        name: name,
        avatar: avatar,
        memberIds: memberIds,
      );

      if (response['success'] == true) {
        // 获取群组信息
        final groupInfo = response['data']['group_info'];

        // 添加到群组列表
        _groups.add(groupInfo);

        // 通知群组监听器
        _notifyGroupListeners();

        debugPrint('[GroupChatService] 创建群组成功: ${groupInfo['id']}');

        return {
          'success': true,
          'group_id': groupInfo['id'],
        };
      } else {
        debugPrint('[GroupChatService] 创建群组失败: ${response['msg']}');

        return {
          'success': false,
          'msg': response['msg'],
        };
      }
    } catch (e) {
      debugPrint('[GroupChatService] 创建群组异常: $e');

      return {
        'success': false,
        'msg': '创建群组异常: $e',
      };
    }
  }

  /// 添加群成员
  Future<bool> addGroupMember(String groupId, String userId) async {
    try {
      // 调用API添加群成员
      final response = await Api.addGroupMember(
        groupId: groupId,
        userId: userId,
      );

      if (response['success'] == true) {
        // 清除成员缓存
        _memberCache.remove(groupId);

        debugPrint('[GroupChatService] 添加群成员成功');
        return true;
      } else {
        debugPrint('[GroupChatService] 添加群成员失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[GroupChatService] 添加群成员异常: $e');
      return false;
    }
  }

  /// 移除群成员
  Future<bool> removeGroupMember(String groupId, String userId) async {
    try {
      // 调用API移除群成员
      final response = await Api.removeGroupMember(
        groupId: groupId,
        userId: userId,
      );

      if (response['success'] == true) {
        // 清除成员缓存
        _memberCache.remove(groupId);

        debugPrint('[GroupChatService] 移除群成员成功');
        return true;
      } else {
        debugPrint('[GroupChatService] 移除群成员失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[GroupChatService] 移除群成员异常: $e');
      return false;
    }
  }

  /// 退出群组
  Future<bool> quitGroup(String groupId) async {
    try {
      // 调用API退出群组
      final response = await Api.quitGroup(
        groupId: groupId,
      );

      if (response['success'] == true) {
        // 从群组列表中移除
        _groups.removeWhere((group) => group['id'] == groupId);

        // 清除缓存
        _messageCache.remove(groupId);
        _memberCache.remove(groupId);

        // 计算总未读消息数
        _calculateTotalUnreadCount();

        // 通知群组监听器
        _notifyGroupListeners();

        debugPrint('[GroupChatService] 退出群组成功');
        return true;
      } else {
        debugPrint('[GroupChatService] 退出群组失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[GroupChatService] 退出群组异常: $e');
      return false;
    }
  }

  /// 解散群组
  Future<bool> dismissGroup(String groupId) async {
    try {
      // 调用API解散群组
      final response = await Api.dismissGroup(
        groupId: groupId,
      );

      if (response['success'] == true) {
        // 从群组列表中移除
        _groups.removeWhere((group) => group['id'] == groupId);

        // 清除缓存
        _messageCache.remove(groupId);
        _memberCache.remove(groupId);

        // 计算总未读消息数
        _calculateTotalUnreadCount();

        // 通知群组监听器
        _notifyGroupListeners();

        debugPrint('[GroupChatService] 解散群组成功');
        return true;
      } else {
        debugPrint('[GroupChatService] 解散群组失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[GroupChatService] 解散群组异常: $e');
      return false;
    }
  }

  /// 添加消息监听器
  void addMessageListener(Function(Map<String, dynamic>) listener) {
    if (!_messageListeners.contains(listener)) {
      _messageListeners.add(listener);
    }
  }

  /// 移除消息监听器
  void removeMessageListener(Function(Map<String, dynamic>) listener) {
    _messageListeners.remove(listener);
  }

  /// 添加群组监听器
  void addGroupListener(Function(List<Map<String, dynamic>>) listener) {
    if (!_groupListeners.contains(listener)) {
      _groupListeners.add(listener);
    }
  }

  /// 移除群组监听器
  void removeGroupListener(Function(List<Map<String, dynamic>>) listener) {
    _groupListeners.remove(listener);
  }

  /// 添加未读消息数监听器
  void addUnreadCountListener(Function(int) listener) {
    if (!_unreadCountListeners.contains(listener)) {
      _unreadCountListeners.add(listener);
    }
  }

  /// 移除未读消息数监听器
  void removeUnreadCountListener(Function(int) listener) {
    _unreadCountListeners.remove(listener);
  }

  /// 添加消息状态监听器
  void addMessageStatusListener(Function(String, String) listener) {
    if (!_messageStatusListeners.contains(listener)) {
      _messageStatusListeners.add(listener);
    }
  }

  /// 移除消息状态监听器
  void removeMessageStatusListener(Function(String, String) listener) {
    _messageStatusListeners.remove(listener);
  }

  /// 通知消息监听器
  void _notifyMessageListeners(Map<String, dynamic> message) {
    for (var listener in _messageListeners) {
      listener(message);
    }
  }

  /// 通知群组监听器
  void _notifyGroupListeners() {
    for (var listener in _groupListeners) {
      listener(_groups);
    }
  }

  /// 通知未读消息数监听器
  void _notifyUnreadCountListeners() {
    for (var listener in _unreadCountListeners) {
      listener(_totalUnreadCount);
    }
  }

  /// 通知消息状态监听器
  void _notifyMessageStatusListeners(String messageId, String status) {
    for (var listener in _messageStatusListeners) {
      listener(messageId, status);
    }
  }

  /// 更新群组
  void _updateGroup(String groupId, Map<String, dynamic> message) {
    // 查找群组
    final index = _groups.indexWhere((group) => group['id'] == groupId);

    if (index >= 0) {
      // 更新群组
      _groups[index] = {
        ..._groups[index],
        'last_message': message,
        'last_message_time': message['timestamp'],
      };

      // 按最后消息时间排序
      _groups.sort((a, b) => (b['last_message_time'] ?? 0).compareTo(a['last_message_time'] ?? 0));

      // 通知群组监听器
      _notifyGroupListeners();
    }
  }

  /// 更新群组未读数
  void _updateGroupUnreadCount(String groupId, int unreadCount) {
    // 查找群组
    final index = _groups.indexWhere((group) => group['id'] == groupId);

    if (index >= 0) {
      // 更新群组未读数
      _groups[index]['unread_count'] = unreadCount;

      // 计算总未读消息数
      _calculateTotalUnreadCount();

      // 通知群组监听器
      _notifyGroupListeners();

      // 通知未读消息数监听器
      _notifyUnreadCountListeners();
    }
  }

  /// 更新消息状态
  void _updateMessageStatus(String messageId, String status) {
    // 遍历所有群组的消息缓存
    for (var groupId in _messageCache.keys) {
      final messages = _messageCache[groupId]!;

      // 查找消息
      final index = messages.indexWhere((message) => message['id'] == messageId);

      if (index >= 0) {
        // 更新消息状态
        messages[index]['status'] = status;

        // 通知消息状态监听器
        _notifyMessageStatusListeners(messageId, status);

        break;
      }
    }
  }

  /// 更新消息ID
  void _updateMessageId(String oldMessageId, String newMessageId) {
    // 遍历所有群组的消息缓存
    for (var groupId in _messageCache.keys) {
      final messages = _messageCache[groupId]!;

      // 查找消息
      final index = messages.indexWhere((message) => message['id'] == oldMessageId);

      if (index >= 0) {
        // 更新消息ID
        messages[index]['id'] = newMessageId;

        break;
      }
    }
  }

  /// 更新消息撤回状态
  void _updateMessageRecallStatus(String messageId, bool isRecalled) {
    // 遍历所有群组的消息缓存
    for (var groupId in _messageCache.keys) {
      final messages = _messageCache[groupId]!;

      // 查找消息
      final index = messages.indexWhere((message) => message['id'] == messageId);

      if (index >= 0) {
        // 更新消息撤回状态
        messages[index]['is_recalled'] = isRecalled;

        break;
      }
    }
  }

  /// 获取最后一条消息ID
  String? _getLastMessageId(String groupId) {
    // 获取消息缓存
    final messages = _messageCache[groupId];

    if (messages != null && messages.isNotEmpty) {
      // 获取最后一条消息ID
      return messages.first['id'];
    }

    return null;
  }

  /// 计算总未读消息数
  void _calculateTotalUnreadCount() {
    // 计算所有群组的未读消息数之和
    _totalUnreadCount = _groups.fold(0, (sum, group) => sum + (group['unread_count'] ?? 0));
  }

  /// 处理新群聊消息
  void notifyNewGroupMessage(Map<String, dynamic> message) {
    // 获取群组ID
    final groupId = message['group_id'];

    // 添加到消息缓存
    if (_messageCache.containsKey(groupId)) {
      _messageCache[groupId] = [message, ..._messageCache[groupId]!];
    } else {
      _messageCache[groupId] = [message];
    }

    // 更新群组列表
    _updateGroup(groupId, message);

    // 更新群组未读数
    final index = _groups.indexWhere((group) => group['id'] == groupId);
    if (index >= 0) {
      _groups[index]['unread_count'] = (_groups[index]['unread_count'] ?? 0) + 1;

      // 计算总未读消息数
      _calculateTotalUnreadCount();

      // 通知未读消息数监听器
      _notifyUnreadCountListeners();
    }

    // 通知消息监听器
    _notifyMessageListeners(message);
  }

  /// 释放资源
  void dispose() {
    // 清空监听器
    _messageListeners.clear();
    _groupListeners.clear();
    _unreadCountListeners.clear();
    _messageStatusListeners.clear();

    // 清空缓存
    _messageCache.clear();
    _memberCache.clear();

    // 清空群组列表
    _groups.clear();

    debugPrint('[GroupChatService] 资源已释放');
  }
}
