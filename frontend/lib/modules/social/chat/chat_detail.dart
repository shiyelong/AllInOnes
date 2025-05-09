import 'package:flutter/material.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/common/local_message_storage_extension.dart';
import 'package:frontend/common/enhanced_file_utils.dart';
import 'package:frontend/modules/social/chat/chat_message_item.dart';
import 'package:frontend/modules/social/chat/draggable_chat_input.dart';
import 'package:frontend/modules/social/chat/red_packet_dialog.dart';
import 'package:frontend/modules/social/chat/call/voice_call_page.dart';
import 'package:frontend/modules/social/chat/call/video_call_page.dart';
import 'package:frontend/modules/social/chat/call/simplified/simplified_call_manager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 聊天详情页面
/// 显示与特定用户的聊天消息
class ChatDetail extends StatefulWidget {
  final String targetId;
  final String targetName;
  final String? targetAvatar;
  final Function(Map<String, dynamic>)? onMessageSent;
  final Function()? onBack;
  final Function()? onStartVoiceCall;
  final Function()? onStartVideoCall;
  final Function(double, String)? onSendRedPacket;

  const ChatDetail({
    Key? key,
    required this.targetId,
    required this.targetName,
    this.targetAvatar,
    this.onMessageSent,
    this.onBack,
    this.onStartVoiceCall,
    this.onStartVideoCall,
    this.onSendRedPacket,
  }) : super(key: key);

  @override
  _ChatDetailState createState() => _ChatDetailState();
}

class _ChatDetailState extends State<ChatDetail> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _hasMoreMessages = true;
  int _page = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听器，用于加载更多消息
  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMoreMessages) {
        _loadMoreMessages();
      }
    }
  }

  // 加载消息
  Future<void> _loadMessages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取本地消息
      final localMessages = await LocalMessageStorageExtension.getMessagesStr(widget.targetId);

      if (localMessages.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(localMessages);
          _isLoading = false;
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

      // 从服务器获取消息
      await _fetchMessagesFromServer();
    } catch (e) {
      debugPrint('加载消息失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 从服务器获取消息
  Future<void> _fetchMessagesFromServer() async {
    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) return;

      final response = await LocalMessageStorageExtension.getMessagesFromApi(
        fromId: userInfo.id.toString(),
        toId: widget.targetId,
        page: _page,
        pageSize: _pageSize,
      );

      if (response['code'] == 0) {
        final List<dynamic> serverMessages = response['data'] ?? [];

        if (serverMessages.isEmpty) {
          setState(() {
            _hasMoreMessages = false;
            _isLoading = false;
          });
          return;
        }

        // 转换服务器消息格式
        final List<Map<String, dynamic>> formattedMessages = [];
        for (var msg in serverMessages) {
          formattedMessages.add({
            'id': msg['id'],
            'from_id': msg['from_id'],
            'to_id': msg['to_id'],
            'type': msg['type'] ?? 'text',
            'content': msg['content'],
            'created_at': msg['created_at'],
            'status': msg['status'] ?? 1,
            'file_name': msg['file_name'],
            'file_size': msg['file_size'],
            'thumbnail': msg['thumbnail'],
            'original_url': msg['original_url'],
            'server_url': msg['server_url'],
          });
        }

        // 保存到本地
        await LocalMessageStorageExtension.saveMessagesStr(widget.targetId, formattedMessages);

        // 更新UI
        setState(() {
          _messages.clear();
          _messages.addAll(formattedMessages);
          _page++;
          _isLoading = false;
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
        debugPrint('获取消息失败: ${response['message']}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('从服务器获取消息失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 加载更多消息
  Future<void> _loadMoreMessages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) return;

      final response = await LocalMessageStorageExtension.getMessagesFromApi(
        fromId: userInfo.id.toString(),
        toId: widget.targetId,
        page: _page,
        pageSize: _pageSize,
      );

      if (response['code'] == 0) {
        final List<dynamic> serverMessages = response['data'] ?? [];

        if (serverMessages.isEmpty) {
          setState(() {
            _hasMoreMessages = false;
            _isLoading = false;
          });
          return;
        }

        // 转换服务器消息格式
        final List<Map<String, dynamic>> formattedMessages = [];
        for (var msg in serverMessages) {
          formattedMessages.add({
            'id': msg['id'],
            'from_id': msg['from_id'],
            'to_id': msg['to_id'],
            'type': msg['type'] ?? 'text',
            'content': msg['content'],
            'created_at': msg['created_at'],
            'status': msg['status'] ?? 1,
            'file_name': msg['file_name'],
            'file_size': msg['file_size'],
            'thumbnail': msg['thumbnail'],
            'original_url': msg['original_url'],
            'server_url': msg['server_url'],
          });
        }

        // 保存到本地
        await LocalMessageStorageExtension.saveMessagesStr(widget.targetId, formattedMessages);

        // 更新UI
        setState(() {
          _messages.addAll(formattedMessages);
          _page++;
          _isLoading = false;
        });
      } else {
        debugPrint('获取更多消息失败: ${response['message']}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载更多消息失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 发送消息
  Future<void> _sendMessage(String content, String type) async {
    if (content.isEmpty) return;

    final userInfo = Persistence.getUserInfo();
    if (userInfo == null) return;

    // 创建消息对象
    final message = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'from_id': userInfo.id,
      'to_id': int.parse(widget.targetId),
      'type': type,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'status': 0, // 0: 发送中, 1: 已发送, 2: 已送达, 3: 已读, -1: 发送失败
    };

    // 更新UI
    setState(() {
      _messages.add(message);
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

    // 回调通知
    if (widget.onMessageSent != null) {
      widget.onMessageSent!(message);
    }

    try {
      // 发送消息到服务器
      final response = await LocalMessageStorageExtension.sendMessageToApi(
        fromId: userInfo.id.toString(),
        toId: widget.targetId,
        content: content,
        type: type,
      );

      if (response['code'] == 0) {
        // 更新消息状态
        final index = _messages.indexWhere((msg) => msg['id'] == message['id']);
        if (index != -1) {
          setState(() {
            _messages[index]['status'] = 1;
            _messages[index]['id'] = response['data']['id'] ?? message['id'];
          });
        }

        // 保存到本地
        await LocalMessageStorageExtension.saveMessagesStr(widget.targetId, _messages);
      } else {
        // 更新消息状态为发送失败
        final index = _messages.indexWhere((msg) => msg['id'] == message['id']);
        if (index != -1) {
          setState(() {
            _messages[index]['status'] = -1;
          });
        }

        debugPrint('发送消息失败: ${response['message']}');
      }
    } catch (e) {
      // 更新消息状态为发送失败
      final index = _messages.indexWhere((msg) => msg['id'] == message['id']);
      if (index != -1) {
        setState(() {
          _messages[index]['status'] = -1;
        });
      }

      debugPrint('发送消息异常: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetName),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {
              if (widget.onStartVoiceCall != null) {
                widget.onStartVoiceCall!();
              } else {
                // 使用简化版通话管理器
                SimplifiedCallManager().startVoiceCall(
                  context,
                  widget.targetId,
                  widget.targetName,
                  targetAvatar: widget.targetAvatar,
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () {
              if (widget.onStartVideoCall != null) {
                widget.onStartVideoCall!();
              } else {
                // 使用简化版通话管理器
                SimplifiedCallManager().startVideoCall(
                  context,
                  widget.targetId,
                  widget.targetName,
                  targetAvatar: widget.targetAvatar,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('暂无消息'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length + (_isLoading && _hasMoreMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && _isLoading && _hasMoreMessages) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final messageIndex = _isLoading && _hasMoreMessages ? index - 1 : index;
                      final message = _messages[messageIndex];

                      final userInfo = Persistence.getUserInfo();
                      return ChatMessageItem(
                        message: message,
                        isMe: message['sender_id'] == userInfo?.id.toString(),
                        targetName: widget.targetName,
                        targetAvatar: widget.targetAvatar,
                      );
                    },
                  ),
          ),
          DraggableChatInput(
            onSendText: (text) => _sendMessage(text, 'text'),
            onSendImage: (file, path) => _sendMessage(path, 'image'),
            onSendVideo: (path, thumbnail) {
              final message = {
                'content': path,
                'thumbnail': thumbnail,
                'type': 'video',
              };
              _sendMessage(jsonEncode(message), 'video');
            },
            onSendFile: (path, fileName, fileSize) {
              final message = {
                'content': path,
                'file_name': fileName,
                'file_size': fileSize,
                'type': 'file',
              };
              _sendMessage(jsonEncode(message), 'file');
            },
            onSendRedPacket: (amount, greeting) {
              if (widget.onSendRedPacket != null) {
                widget.onSendRedPacket!(amount, greeting);
              }
            },
            onStartVoiceCall: () {
              if (widget.onStartVoiceCall != null) {
                widget.onStartVoiceCall!();
              } else {
                // 使用简化版通话管理器
                SimplifiedCallManager().startVoiceCall(
                  context,
                  widget.targetId,
                  widget.targetName,
                  targetAvatar: widget.targetAvatar,
                );
              }
            },
            onStartVideoCall: () {
              if (widget.onStartVideoCall != null) {
                widget.onStartVideoCall!();
              } else {
                // 使用简化版通话管理器
                SimplifiedCallManager().startVideoCall(
                  context,
                  widget.targetId,
                  widget.targetName,
                  targetAvatar: widget.targetAvatar,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
