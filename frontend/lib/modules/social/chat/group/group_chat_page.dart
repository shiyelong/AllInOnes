import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/common/image_thumbnail_generator.dart';
import 'package:frontend/common/network_monitor.dart';
import 'package:frontend/common/message_queue_manager.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/modules/social/chat/enhanced_chat_input.dart';
import 'package:frontend/modules/social/chat/message_bubble.dart';
import 'package:frontend/widgets/app_avatar.dart';
import 'package:frontend/widgets/network_status_indicator.dart';
import 'package:frontend/modules/social/chat/group/group_chat_service.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

class GroupChatPage extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupChatPage({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  int _currentUserId = 0;
  bool _isNetworkConnected = true; // 网络连接状态
  double _networkQuality = 1.0; // 网络质量
  List<Map<String, dynamic>> _pendingMessages = []; // 待发送的消息

  @override
  void initState() {
    super.initState();

    // 监听网络状态变化
    NetworkMonitor().addListener(_updateNetworkStatus);

    // 初始化网络状态
    _isNetworkConnected = NetworkMonitor().isConnected;
    _networkQuality = NetworkMonitor().networkQuality;

    _initData();

    // 设置定时刷新消息
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (_isNetworkConnected) {
        _loadMessages();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshTimer?.cancel();

    // 移除网络状态监听
    NetworkMonitor().removeListener(_updateNetworkStatus);

    super.dispose();
  }

  // 更新网络状态
  void _updateNetworkStatus(bool isConnected, double quality) {
    if (mounted) {
      setState(() {
        _isNetworkConnected = isConnected;
        _networkQuality = quality;
      });

      // 如果网络从断开变为连接，自动重新加载消息
      if (isConnected && _errorMessage.isNotEmpty) {
        _loadMessages();

        // 尝试发送所有待发送的消息
        _retryPendingMessages();
      }
    }
  }

  // 重试所有待发送的消息
  Future<void> _retryPendingMessages() async {
    if (_pendingMessages.isEmpty) return;

    debugPrint('[GroupChatPage] 尝试重新发送 ${_pendingMessages.length} 条待发送消息');

    final pendingMessages = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();

    for (var message in pendingMessages) {
      await _sendMessage(
        message['content'],
        message['type'],
        isRetry: true,
      );
    }
  }

  Future<void> _initData() async {
    final userInfo = Persistence.getUserInfo();
    if (userInfo != null) {
      _currentUserId = userInfo.id;
    }

    await Future.wait([
      _loadMessages(),
      _loadGroupMembers(),
    ]);
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        if (_messages.isEmpty) {
          _isLoading = true;
        }
        _errorMessage = '';
      });

      final result = await Api.getGroupMessages(
        groupId: widget.group['id'].toString(),
        limit: 50,
      );

      if (result['success'] == true) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(result['data'] ?? []);
          // 按时间排序（从旧到新）
          _messages.sort((a, b) => (a['created_at'] ?? 0).compareTo(b['created_at'] ?? 0));
        });

        // 滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() {
          _errorMessage = result['msg'] ?? '获取消息失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载消息失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGroupMembers() async {
    try {
      final result = await Api.getGroupMembers(
        groupId: widget.group['id'].toString(),
      );

      if (result['success'] == true) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
      }
    } catch (e) {
      print('加载群成员失败: $e');
    }
  }

  Future<void> _sendMessage(String content, String type, {bool isRetry = false}) async {
    if (content.isEmpty) return;

    // 如果网络断开且不是重试，将消息添加到待发送队列
    if (!_isNetworkConnected && !isRetry) {
      setState(() {
        _pendingMessages.add({
          'content': content,
          'type': type,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });
      });

      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络已断开，消息将在网络恢复后自动发送'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

      // 添加一条本地消息，显示为"发送中"状态
      final localMessage = {
        'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
        'sender_id': _currentUserId,
        'group_id': widget.group['id'],
        'content': content,
        'type': type,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'status': 0, // 发送中
      };

      setState(() {
        _messages.add(localMessage);
      });

      // 滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        throw Exception('用户未登录');
      }

      // 如果是图片消息，先生成缩略图
      String finalContent = content;
      Map<String, dynamic> extraData = {};

      if (type == 'image' && content.startsWith('/')) {
        // 这是本地图片路径，需要生成缩略图
        debugPrint('[GroupChatPage] 开始生成缩略图: $content');
        try {
          final thumbnailPath = await ImageThumbnailGenerator.generateThumbnail(
            content,
            width: 200,
            height: 200,
            quality: 80,
          );

          if (thumbnailPath.isNotEmpty) {
            debugPrint('[GroupChatPage] 缩略图生成成功: $thumbnailPath');
            extraData['thumbnail'] = thumbnailPath;
            extraData['original'] = content;
          }
        } catch (e) {
          debugPrint('[GroupChatPage] 生成缩略图失败: $e');
          // 缩略图生成失败不影响消息发送
        }
      }

      // 解析@用户
      List<String> mentionedUsers = [];
      RegExp regExp = RegExp(r'@(\d+)');
      regExp.allMatches(content).forEach((match) {
        if (match.group(1) != null) {
          mentionedUsers.add(match.group(1)!);
        }
      });

      // 添加一条本地消息，显示为"发送中"状态
      final localMessageId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final localMessage = {
        'id': localMessageId,
        'sender_id': _currentUserId,
        'group_id': widget.group['id'],
        'content': finalContent,
        'type': type,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'status': 0, // 发送中
        'extra': extraData.isNotEmpty ? jsonEncode(extraData) : null,
      };

      // 如果不是重试，添加本地消息
      if (!isRetry) {
        setState(() {
          _messages.add(localMessage);
        });

        // 滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }

      // 使用消息队列管理器发送消息
      await MessageQueueManager().addGroupChatMessage(
        widget.group['id'],
        finalContent,
        type: type,
        mentionedUsers: mentionedUsers,
      );

      // 发送到服务器
      final result = await Api.sendGroupMessage(
        groupId: widget.group['id'].toString(),
        content: finalContent,
        type: type,
        mentionedUsers: mentionedUsers,
        extra: extraData.isNotEmpty ? jsonEncode(extraData) : null,
      );

      if (result['success'] == true) {
        // 添加新消息到列表或更新本地消息
        final newMessage = result['data'];
        if (newMessage != null) {
          setState(() {
            // 查找本地消息
            final localIndex = _messages.indexWhere((msg) => msg['id'] == localMessageId);
            if (localIndex != -1) {
              // 更新本地消息
              _messages[localIndex] = Map<String, dynamic>.from(newMessage);
              _messages[localIndex]['status'] = 1; // 已发送
            } else {
              // 添加新消息
              _messages.add(Map<String, dynamic>.from(newMessage));
            }
          });
        }
      } else {
        // 更新本地消息状态为发送失败
        setState(() {
          final localIndex = _messages.indexWhere((msg) => msg['id'] == localMessageId);
          if (localIndex != -1) {
            _messages[localIndex]['status'] = 2; // 发送失败
          }
        });

        // 如果网络连接正常，显示错误消息
        if (_isNetworkConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['msg'] ?? '发送失败'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: '重试',
                onPressed: () => _retryMessage(localMessageId),
              ),
            ),
          );
        } else {
          // 如果网络断开，添加到待发送队列
          _pendingMessages.add({
            'content': content,
            'type': type,
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('网络已断开，消息将在网络恢复后自动发送'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // 如果网络连接正常，显示错误消息
      if (_isNetworkConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _sendMessage(content, type, isRetry: true),
            ),
          ),
        );
      } else {
        // 如果网络断开，添加到待发送队列
        _pendingMessages.add({
          'content': content,
          'type': type,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('网络已断开，消息将在网络恢复后自动发送'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // 重试发送失败的消息
  Future<void> _retryMessage(String messageId) async {
    final messageIndex = _messages.indexWhere((msg) => msg['id'] == messageId);
    if (messageIndex == -1) return;

    final message = _messages[messageIndex];

    // 更新消息状态为发送中
    setState(() {
      _messages[messageIndex]['status'] = 0; // 发送中
    });

    // 重新发送消息
    await _sendMessage(
      message['content'],
      message['type'],
      isRetry: true,
    );
  }

  void _showGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('群组信息')),
          body: Center(child: Text('群组信息页面')),
        ),
      ),
    );
  }

  String _getMemberNickname(int userId) {
    final member = _members.firstWhere(
      (m) => m['user_id'] == userId,
      orElse: () => {'nickname': '未知用户'},
    );
    return member['nickname'] ?? '未知用户';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showGroupInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.group['name'] ?? '群聊'),
              Row(
                children: [
                  Text(
                    '${_members.length}人',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (!_isNetworkConnected)
                    Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        '网络已断开',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // 网络状态指示器
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: NetworkStatusIndicator(
              showDetails: false,
              iconSize: 14,
              autoHide: true,
              onTap: () {
                NetworkMonitor().forceCheckNetwork();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('正在检查网络状态...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // 错误消息
          if (_errorMessage.isNotEmpty)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 16),
                    onPressed: _loadMessages,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text('暂无消息'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['sender_id'] == _currentUserId;
                          final senderName = isMe ? '我' : _getMemberNickname(message['sender_id']);

                          // 使用统一的MessageBubble组件处理所有消息类型
                          return MessageBubble(
                            message: message,
                            isMe: isMe,
                            showAvatar: true,
                            showName: true, // 群聊中总是显示发送者
                            onRetry: isMe && message['status'] == 2 ? () => _retryMessage(message['id']) : null,
                          );
                        },
                      ),
          ),

          // 输入框
          EnhancedChatInput(
            onSendText: (text) => _sendMessage(text, 'text'),
            onSendImage: (file, path) => _sendMessage(path, 'image'),
            targetId: widget.group['id'].toString(),
            targetName: widget.group['name'],
            targetAvatar: widget.group['avatar'],
          ),
        ],
      ),
    );
  }
}
