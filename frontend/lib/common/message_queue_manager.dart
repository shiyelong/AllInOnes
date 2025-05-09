import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/modules/social/chat/chat_service.dart';
import 'package:frontend/modules/social/chat/group/group_chat_service.dart';

/// 消息队列管理器
/// 用于管理消息发送队列，确保消息按顺序发送，并在发送失败时自动重试
class MessageQueueManager {
  static final MessageQueueManager _instance = MessageQueueManager._internal();
  factory MessageQueueManager() => _instance;

  MessageQueueManager._internal();

  // 单聊消息队列，按聊天ID分组
  final Map<int, Queue<Map<String, dynamic>>> _singleChatQueues = {};
  
  // 群聊消息队列，按群组ID分组
  final Map<int, Queue<Map<String, dynamic>>> _groupChatQueues = {};
  
  // 处理状态
  final Map<int, bool> _processingStatus = {};
  
  // 重试计数器
  final Map<String, int> _retryCounters = {};
  
  // 最大重试次数
  static const int maxRetries = 5;
  
  // 重试间隔（毫秒）
  static const List<int> retryIntervals = [1000, 2000, 5000, 10000, 30000]; // 递增的重试间隔
  
  // 初始化
  Future<void> initialize() async {
    debugPrint('[MessageQueueManager] 初始化消息队列管理器');
    
    // 加载所有失败的消息
    await _loadFailedMessages();
    
    // 开始处理队列
    _startProcessingQueues();
  }
  
  // 加载所有失败的消息
  Future<void> _loadFailedMessages() async {
    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) return;
      
      final userId = userInfo.id;
      
      // 获取所有失败的消息
      final failedMessages = await LocalMessageStorage.getFailedMessages(userId);
      
      if (failedMessages.isEmpty) {
        debugPrint('[MessageQueueManager] 没有找到失败的消息');
        return;
      }
      
      debugPrint('[MessageQueueManager] 找到 ${failedMessages.length} 条失败的消息');
      
      // 将失败的消息添加到相应的队列
      for (var message in failedMessages) {
        final chatId = message['to_id'] as int;
        final groupId = message['group_id'] as int?;
        
        if (groupId != null) {
          // 群聊消息
          _addToGroupChatQueue(groupId, message);
        } else {
          // 单聊消息
          _addToSingleChatQueue(chatId, message);
        }
      }
    } catch (e) {
      debugPrint('[MessageQueueManager] 加载失败消息时出错: $e');
    }
  }
  
  // 开始处理所有队列
  void _startProcessingQueues() {
    // 处理单聊队列
    for (var chatId in _singleChatQueues.keys) {
      _processQueue(chatId, isGroupChat: false);
    }
    
    // 处理群聊队列
    for (var groupId in _groupChatQueues.keys) {
      _processQueue(groupId, isGroupChat: true);
    }
  }
  
  // 添加消息到单聊队列
  void _addToSingleChatQueue(int chatId, Map<String, dynamic> message) {
    if (!_singleChatQueues.containsKey(chatId)) {
      _singleChatQueues[chatId] = Queue<Map<String, dynamic>>();
    }
    
    // 生成消息ID（如果没有）
    if (!message.containsKey('queue_id')) {
      message['queue_id'] = '${DateTime.now().millisecondsSinceEpoch}_${message.hashCode}';
    }
    
    _singleChatQueues[chatId]!.add(message);
    debugPrint('[MessageQueueManager] 添加消息到单聊队列: chatId=$chatId, queueLength=${_singleChatQueues[chatId]!.length}');
    
    // 开始处理队列（如果尚未处理）
    if (!(_processingStatus[chatId] ?? false)) {
      _processQueue(chatId, isGroupChat: false);
    }
  }
  
  // 添加消息到群聊队列
  void _addToGroupChatQueue(int groupId, Map<String, dynamic> message) {
    if (!_groupChatQueues.containsKey(groupId)) {
      _groupChatQueues[groupId] = Queue<Map<String, dynamic>>();
    }
    
    // 生成消息ID（如果没有）
    if (!message.containsKey('queue_id')) {
      message['queue_id'] = '${DateTime.now().millisecondsSinceEpoch}_${message.hashCode}';
    }
    
    _groupChatQueues[groupId]!.add(message);
    debugPrint('[MessageQueueManager] 添加消息到群聊队列: groupId=$groupId, queueLength=${_groupChatQueues[groupId]!.length}');
    
    // 开始处理队列（如果尚未处理）
    if (!(_processingStatus[groupId] ?? false)) {
      _processQueue(groupId, isGroupChat: true);
    }
  }
  
  // 处理队列
  Future<void> _processQueue(int id, {required bool isGroupChat}) async {
    // 标记为正在处理
    _processingStatus[id] = true;
    
    try {
      final queue = isGroupChat ? _groupChatQueues[id] : _singleChatQueues[id];
      
      if (queue == null || queue.isEmpty) {
        _processingStatus[id] = false;
        return;
      }
      
      while (queue.isNotEmpty) {
        final message = queue.first;
        final queueId = message['queue_id'] as String;
        final retryCount = _retryCounters[queueId] ?? 0;
        
        if (retryCount >= maxRetries) {
          // 超过最大重试次数，放弃该消息
          debugPrint('[MessageQueueManager] 消息重试次数超过上限，放弃: $queueId');
          queue.removeFirst();
          _retryCounters.remove(queueId);
          continue;
        }
        
        bool success = false;
        
        try {
          if (isGroupChat) {
            // 发送群聊消息
            success = await _sendGroupMessage(id, message);
          } else {
            // 发送单聊消息
            success = await _sendSingleMessage(id, message);
          }
        } catch (e) {
          debugPrint('[MessageQueueManager] 发送消息失败: $e');
          success = false;
        }
        
        if (success) {
          // 发送成功，移除消息
          queue.removeFirst();
          _retryCounters.remove(queueId);
        } else {
          // 发送失败，增加重试计数
          _retryCounters[queueId] = retryCount + 1;
          
          // 计算重试间隔
          final intervalIndex = retryCount < retryIntervals.length ? retryCount : retryIntervals.length - 1;
          final retryInterval = retryIntervals[intervalIndex];
          
          debugPrint('[MessageQueueManager] 消息发送失败，将在 $retryInterval 毫秒后重试: $queueId, 重试次数: ${retryCount + 1}');
          
          // 等待一段时间后再次处理队列
          await Future.delayed(Duration(milliseconds: retryInterval));
          break; // 跳出循环，下次再试
        }
      }
    } finally {
      // 如果队列不为空，继续处理
      final queue = isGroupChat ? _groupChatQueues[id] : _singleChatQueues[id];
      if (queue != null && queue.isNotEmpty) {
        // 延迟一段时间后继续处理
        Timer(Duration(milliseconds: 500), () {
          _processQueue(id, isGroupChat: isGroupChat);
        });
      } else {
        // 队列为空，标记为未处理
        _processingStatus[id] = false;
      }
    }
  }
  
  // 发送单聊消息
  Future<bool> _sendSingleMessage(int chatId, Map<String, dynamic> message) async {
    final content = message['content'] as String;
    final type = message['type'] as String? ?? 'text';
    
    return await ChatService.sendMessage(chatId, content);
  }
  
  // 发送群聊消息
  Future<bool> _sendGroupMessage(int groupId, Map<String, dynamic> message) async {
    final content = message['content'] as String;
    final type = message['type'] as String? ?? 'text';
    final mentionedUsers = message['mentioned_users'] as List<String>?;
    
    return await GroupChatService.sendGroupMessage(groupId, content, mentionedUsers: mentionedUsers);
  }
  
  // 添加单聊消息到队列
  Future<void> addSingleChatMessage(int chatId, String content, {String type = 'text'}) async {
    final message = {
      'content': content,
      'type': type,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'from_id': Persistence.getUserInfo()?.id,
      'to_id': chatId,
    };
    
    _addToSingleChatQueue(chatId, message);
  }
  
  // 添加群聊消息到队列
  Future<void> addGroupChatMessage(int groupId, String content, {String type = 'text', List<String>? mentionedUsers}) async {
    final message = {
      'content': content,
      'type': type,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'from_id': Persistence.getUserInfo()?.id,
      'group_id': groupId,
      'mentioned_users': mentionedUsers,
    };
    
    _addToGroupChatQueue(groupId, message);
  }
}
