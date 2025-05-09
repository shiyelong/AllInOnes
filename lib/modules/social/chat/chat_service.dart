import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';

/// 聊天服务
/// 用于管理聊天消息、会话等
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  ChatService._internal();

  // 消息监听器
  final List<Function(Map<String, dynamic>)> _messageListeners = [];
  
  // 会话监听器
  final List<Function(List<Map<String, dynamic>>)> _conversationListeners = [];
  
  // 未读消息数监听器
  final List<Function(int)> _unreadCountListeners = [];
  
  // 消息状态监听器
  final List<Function(String, String)> _messageStatusListeners = [];
  
  // 会话列表
  List<Map<String, dynamic>> _conversations = [];
  
  // 聊天消息缓存
  final Map<String, List<Map<String, dynamic>>> _messageCache = {};
  
  // 未读消息数
  int _totalUnreadCount = 0;
  
  // 获取会话列表
  List<Map<String, dynamic>> get conversations => _conversations;
  
  // 获取未读消息数
  int get totalUnreadCount => _totalUnreadCount;
  
  /// 初始化
  Future<void> initialize() async {
    debugPrint('[ChatService] 初始化');
    
    // 加载会话列表
    await loadConversations();
  }
  
  /// 加载会话列表
  Future<void> loadConversations() async {
    try {
      // 调用API获取会话列表
      final response = await Api.getConversations();
      
      if (response['success'] == true) {
        // 更新会话列表
        _conversations = List<Map<String, dynamic>>.from(response['data']['conversations']);
        
        // 计算总未读消息数
        _calculateTotalUnreadCount();
        
        // 通知会话监听器
        _notifyConversationListeners();
        
        debugPrint('[ChatService] 加载会话列表成功: ${_conversations.length}个会话');
      } else {
        debugPrint('[ChatService] 加载会话列表失败: ${response['msg']}');
      }
    } catch (e) {
      debugPrint('[ChatService] 加载会话列表异常: $e');
    }
  }
  
  /// 加载聊天记录
  Future<List<Map<String, dynamic>>> loadChatHistory(String targetId, {String? lastMessageId, int limit = 20}) async {
    try {
      // 调用API获取聊天记录
      final response = await Api.getChatHistory(
        targetId: targetId,
        lastMessageId: lastMessageId,
        limit: limit,
      );
      
      if (response['success'] == true) {
        // 获取消息列表
        final messages = List<Map<String, dynamic>>.from(response['data']['messages']);
        
        // 更新消息缓存
        if (lastMessageId == null) {
          // 如果是第一次加载，则替换缓存
          _messageCache[targetId] = messages;
        } else {
          // 如果是加载更多，则追加到缓存
          _messageCache[targetId] = [..._messageCache[targetId] ?? [], ...messages];
        }
        
        debugPrint('[ChatService] 加载聊天记录成功: ${messages.length}条消息');
        
        return messages;
      } else {
        debugPrint('[ChatService] 加载聊天记录失败: ${response['msg']}');
        return [];
      }
    } catch (e) {
      debugPrint('[ChatService] 加载聊天记录异常: $e');
      return [];
    }
  }
  
  /// 发送消息
  Future<Map<String, dynamic>> sendMessage({
    required String targetId,
    required String content,
    required String type,
  }) async {
    try {
      // 生成临时消息ID
      final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${targetId}';
      
      // 获取用户信息
      final userInfo = Persistence.getUserInfo();
      final userId = Persistence.getUserId();
      
      // 构建消息对象
      final message = {
        'id': tempMessageId,
        'sender_id': userId,
        'sender_name': userInfo?['nickname'] ?? '我',
        'sender_avatar': userInfo?['avatar'],
        'target_id': targetId,
        'content': content,
        'type': type,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'sending',
        'is_read': false,
      };
      
      // 添加到消息缓存
      if (_messageCache.containsKey(targetId)) {
        _messageCache[targetId] = [message, ..._messageCache[targetId]!];
      } else {
        _messageCache[targetId] = [message];
      }
      
      // 更新会话列表
      _updateConversation(targetId, message);
      
      // 通知消息监听器
      _notifyMessageListeners(message);
      
      // 调用API发送消息
      final response = await Api.sendMessage(
        targetId: targetId,
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
        
        debugPrint('[ChatService] 发送消息成功: $realMessageId');
        
        return {
          'success': true,
          'message_id': realMessageId,
        };
      } else {
        // 更新消息状态
        _updateMessageStatus(tempMessageId, 'failed');
        
        debugPrint('[ChatService] 发送消息失败: ${response['msg']}');
        
        return {
          'success': false,
          'msg': response['msg'],
        };
      }
    } catch (e) {
      debugPrint('[ChatService] 发送消息异常: $e');
      
      return {
        'success': false,
        'msg': '发送消息异常: $e',
      };
    }
  }
  
  /// 标记消息为已读
  Future<bool> markMessagesAsRead(String targetId) async {
    try {
      // 获取最后一条消息ID
      final lastMessageId = _getLastMessageId(targetId);
      if (lastMessageId == null) {
        debugPrint('[ChatService] 没有消息需要标记为已读');
        return true;
      }
      
      // 调用API标记消息为已读
      final response = await Api.markMessagesAsRead(
        targetId: targetId,
        lastMessageId: lastMessageId,
      );
      
      if (response['success'] == true) {
        // 更新会话未读数
        _updateConversationUnreadCount(targetId, 0);
        
        // 更新消息已读状态
        _updateMessagesReadStatus(targetId);
        
        debugPrint('[ChatService] 标记消息为已读成功');
        return true;
      } else {
        debugPrint('[ChatService] 标记消息为已读失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 标记消息为已读异常: $e');
      return false;
    }
  }
  
  /// 撤回消息
  Future<bool> recallMessage(String messageId) async {
    try {
      // 调用API撤回消息
      final response = await Api.recallMessage(
        messageId: messageId,
      );
      
      if (response['success'] == true) {
        // 更新消息状态
        _updateMessageRecallStatus(messageId, true);
        
        debugPrint('[ChatService] 撤回消息成功');
        return true;
      } else {
        debugPrint('[ChatService] 撤回消息失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 撤回消息异常: $e');
      return false;
    }
  }
  
  /// 转发消息
  Future<bool> forwardMessage(String messageId, String targetId, String type) async {
    try {
      // 调用API转发消息
      final response = await Api.forwardMessage(
        messageId: messageId,
        targetId: targetId,
        type: type,
      );
      
      if (response['success'] == true) {
        debugPrint('[ChatService] 转发消息成功');
        return true;
      } else {
        debugPrint('[ChatService] 转发消息失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 转发消息异常: $e');
      return false;
    }
  }
  
  /// 删除消息
  Future<bool> deleteMessage(String messageId) async {
    try {
      // 调用API删除消息
      final response = await Api.deleteMessage(
        messageId: messageId,
      );
      
      if (response['success'] == true) {
        // 从缓存中删除消息
        _deleteMessageFromCache(messageId);
        
        debugPrint('[ChatService] 删除消息成功');
        return true;
      } else {
        debugPrint('[ChatService] 删除消息失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 删除消息异常: $e');
      return false;
    }
  }
  
  /// 删除会话
  Future<bool> deleteConversation(String targetId) async {
    try {
      // 调用API删除会话
      final response = await Api.deleteConversation(
        targetId: targetId,
      );
      
      if (response['success'] == true) {
        // 从会话列表中删除
        _conversations.removeWhere((conversation) => conversation['target_id'] == targetId);
        
        // 从消息缓存中删除
        _messageCache.remove(targetId);
        
        // 计算总未读消息数
        _calculateTotalUnreadCount();
        
        // 通知会话监听器
        _notifyConversationListeners();
        
        debugPrint('[ChatService] 删除会话成功');
        return true;
      } else {
        debugPrint('[ChatService] 删除会话失败: ${response['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('[ChatService] 删除会话异常: $e');
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
  
  /// 添加会话监听器
  void addConversationListener(Function(List<Map<String, dynamic>>) listener) {
    if (!_conversationListeners.contains(listener)) {
      _conversationListeners.add(listener);
    }
  }
  
  /// 移除会话监听器
  void removeConversationListener(Function(List<Map<String, dynamic>>) listener) {
    _conversationListeners.remove(listener);
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
  
  /// 通知会话监听器
  void _notifyConversationListeners() {
    for (var listener in _conversationListeners) {
      listener(_conversations);
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
  
  /// 更新会话
  void _updateConversation(String targetId, Map<String, dynamic> message) {
    // 查找会话
    final index = _conversations.indexWhere((conversation) => conversation['target_id'] == targetId);
    
    if (index >= 0) {
      // 更新会话
      _conversations[index] = {
        ..._conversations[index],
        'last_message': message,
        'last_message_time': message['timestamp'],
      };
    } else {
      // 创建新会话
      _conversations.add({
        'target_id': targetId,
        'target_name': message['target_name'] ?? '未知用户',
        'target_avatar': message['target_avatar'],
        'last_message': message,
        'last_message_time': message['timestamp'],
        'unread_count': 0,
      });
    }
    
    // 按最后消息时间排序
    _conversations.sort((a, b) => (b['last_message_time'] ?? 0).compareTo(a['last_message_time'] ?? 0));
    
    // 通知会话监听器
    _notifyConversationListeners();
  }
  
  /// 更新会话未读数
  void _updateConversationUnreadCount(String targetId, int unreadCount) {
    // 查找会话
    final index = _conversations.indexWhere((conversation) => conversation['target_id'] == targetId);
    
    if (index >= 0) {
      // 更新会话未读数
      _conversations[index]['unread_count'] = unreadCount;
      
      // 计算总未读消息数
      _calculateTotalUnreadCount();
      
      // 通知会话监听器
      _notifyConversationListeners();
      
      // 通知未读消息数监听器
      _notifyUnreadCountListeners();
    }
  }
  
  /// 更新消息状态
  void _updateMessageStatus(String messageId, String status) {
    // 遍历所有会话的消息缓存
    for (var targetId in _messageCache.keys) {
      final messages = _messageCache[targetId]!;
      
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
    // 遍历所有会话的消息缓存
    for (var targetId in _messageCache.keys) {
      final messages = _messageCache[targetId]!;
      
      // 查找消息
      final index = messages.indexWhere((message) => message['id'] == oldMessageId);
      
      if (index >= 0) {
        // 更新消息ID
        messages[index]['id'] = newMessageId;
        
        break;
      }
    }
  }
  
  /// 更新消息已读状态
  void _updateMessagesReadStatus(String targetId) {
    // 获取消息缓存
    final messages = _messageCache[targetId];
    
    if (messages != null) {
      // 更新所有消息的已读状态
      for (var i = 0; i < messages.length; i++) {
        messages[i]['is_read'] = true;
      }
    }
  }
  
  /// 更新消息撤回状态
  void _updateMessageRecallStatus(String messageId, bool isRecalled) {
    // 遍历所有会话的消息缓存
    for (var targetId in _messageCache.keys) {
      final messages = _messageCache[targetId]!;
      
      // 查找消息
      final index = messages.indexWhere((message) => message['id'] == messageId);
      
      if (index >= 0) {
        // 更新消息撤回状态
        messages[index]['is_recalled'] = isRecalled;
        
        break;
      }
    }
  }
  
  /// 从缓存中删除消息
  void _deleteMessageFromCache(String messageId) {
    // 遍历所有会话的消息缓存
    for (var targetId in _messageCache.keys) {
      final messages = _messageCache[targetId]!;
      
      // 查找消息
      final index = messages.indexWhere((message) => message['id'] == messageId);
      
      if (index >= 0) {
        // 删除消息
        messages.removeAt(index);
        
        break;
      }
    }
  }
  
  /// 获取最后一条消息ID
  String? _getLastMessageId(String targetId) {
    // 获取消息缓存
    final messages = _messageCache[targetId];
    
    if (messages != null && messages.isNotEmpty) {
      // 获取最后一条消息ID
      return messages.first['id'];
    }
    
    return null;
  }
  
  /// 计算总未读消息数
  void _calculateTotalUnreadCount() {
    // 计算所有会话的未读消息数之和
    _totalUnreadCount = _conversations.fold(0, (sum, conversation) => sum + (conversation['unread_count'] ?? 0));
  }
  
  /// 处理新消息
  void notifyNewMessage(Map<String, dynamic> message) {
    // 获取目标ID
    final targetId = message['sender_id'];
    
    // 添加到消息缓存
    if (_messageCache.containsKey(targetId)) {
      _messageCache[targetId] = [message, ..._messageCache[targetId]!];
    } else {
      _messageCache[targetId] = [message];
    }
    
    // 更新会话列表
    _updateConversation(targetId, message);
    
    // 更新会话未读数
    final index = _conversations.indexWhere((conversation) => conversation['target_id'] == targetId);
    if (index >= 0) {
      _conversations[index]['unread_count'] = (_conversations[index]['unread_count'] ?? 0) + 1;
      
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
    _conversationListeners.clear();
    _unreadCountListeners.clear();
    _messageStatusListeners.clear();
    
    // 清空缓存
    _messageCache.clear();
    
    // 清空会话列表
    _conversations.clear();
    
    debugPrint('[ChatService] 资源已释放');
  }
}
