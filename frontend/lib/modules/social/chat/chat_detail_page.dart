import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/text_sanitizer.dart';
import '../../../common/network_monitor.dart';
import '../../../common/message_queue_manager.dart';
import '../../../common/local_message_storage.dart';
import '../../../widgets/app_avatar.dart';
import '../../../widgets/resizable_panel.dart';
import '../../../widgets/network_status_indicator.dart';
import 'emoji_picker.dart';
import 'red_packet_dialog.dart';
import 'chat_message_item.dart';
import 'draggable_chat_input.dart';
import 'location_picker.dart';
import 'chat_message_manager.dart';
import 'media_message_handler.dart';
import 'voice_call_handler.dart';

class ChatDetailPage extends StatefulWidget {
  final String userId;
  final String targetId;
  final String targetName;
  final String targetAvatar;

  const ChatDetailPage({
    Key? key,
    required this.userId,
    required this.targetId,
    required this.targetName,
    this.targetAvatar = '',
  }) : super(key: key);

  @override
  _ChatDetailPageState createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String _error = '';
  bool _isNetworkConnected = true; // 网络连接状态
  double _networkQuality = 1.0; // 网络质量

  @override
  void initState() {
    super.initState();

    // 监听网络状态变化
    NetworkMonitor().addListener(_updateNetworkStatus);

    // 初始化网络状态
    _isNetworkConnected = NetworkMonitor().isConnected;
    _networkQuality = NetworkMonitor().networkQuality;

    // 首次加载消息，添加重试机制
    _loadMessages().then((_) {
      // 如果加载失败且组件仍然挂载，自动重试一次
      if (_error.isNotEmpty && mounted) {
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            _loadMessages();
          }
        });
      }

      // 标记消息为已读
      if (mounted) {
        _markMessagesAsRead();
      }
    });
  }

  // 更新网络状态
  void _updateNetworkStatus(bool isConnected, double quality) {
    if (mounted) {
      setState(() {
        _isNetworkConnected = isConnected;
        _networkQuality = quality;
      });

      // 如果网络从断开变为连接，自动重新加载消息
      if (isConnected && _error.isNotEmpty) {
        _loadMessages();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();

    // 移除网络状态监听
    NetworkMonitor().removeListener(_updateNetworkStatus);

    super.dispose();
  }

  // 加载消息
  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await ChatMessageManager().loadMessages(
        userId: widget.userId,
        targetId: widget.targetId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _messages = result['messages'];
          _loading = false;
          _error = '';
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
          _error = result['error'];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 加载消息异常: $e');

      if (!mounted) return;

      setState(() {
        _error = '加载消息出错: $e';
        _loading = false;
      });
    }
  }

  // 发送文本消息
  Future<void> _sendTextMessage(String text) async {
    if (text.isEmpty) return;

    try {
      final result = await ChatMessageManager().sendTextMessage(
        userId: widget.userId,
        targetId: widget.targetId,
        content: text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 添加消息到列表
        setState(() {
          // 查找是否已存在相同ID的消息
          final message = result['message'];
          final index = _messages.indexWhere((msg) => msg['id'] == message['id']);

          if (index != -1) {
            // 更新现有消息
            _messages[index] = message;
          } else {
            // 添加新消息
            _messages.add(message);
          }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 发送文本消息异常: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送消息失败: $e')),
      );
    }
  }

  // 发送图片消息
  Future<void> _sendImageMessage(File image, String path) async {
    try {
      final result = await MediaMessageHandler().sendImageMessage(
        userId: widget.userId,
        targetId: widget.targetId,
        imageFile: image,
        imagePath: path,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 添加消息到列表
        setState(() {
          // 查找是否已存在相同ID的消息
          final message = result['message'];
          final index = _messages.indexWhere((msg) => msg['id'] == message['id']);

          if (index != -1) {
            // 更新现有消息
            _messages[index] = message;
          } else {
            // 添加新消息
            _messages.add(message);
          }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 发送图片消息异常: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送图片失败: $e')),
      );
    }
  }

  // 发送视频消息
  Future<void> _sendVideoMessage(File video, String path) async {
    try {
      final result = await MediaMessageHandler().sendVideoMessage(
        userId: widget.userId,
        targetId: widget.targetId,
        videoFile: video,
        videoPath: path,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 添加消息到列表
        setState(() {
          // 查找是否已存在相同ID的消息
          final message = result['message'];
          final index = _messages.indexWhere((msg) => msg['id'] == message['id']);

          if (index != -1) {
            // 更新现有消息
            _messages[index] = message;
          } else {
            // 添加新消息
            _messages.add(message);
          }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 发送视频消息异常: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送视频失败: $e')),
      );
    }
  }

  // 发送文件消息
  Future<void> _sendFileMessage(File file, String path, String fileName) async {
    try {
      final result = await MediaMessageHandler().sendFileMessage(
        userId: widget.userId,
        targetId: widget.targetId,
        file: file,
        filePath: path,
        fileName: fileName,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 添加消息到列表
        setState(() {
          // 查找是否已存在相同ID的消息
          final message = result['message'];
          final index = _messages.indexWhere((msg) => msg['id'] == message['id']);

          if (index != -1) {
            // 更新现有消息
            _messages[index] = message;
          } else {
            // 添加新消息
            _messages.add(message);
          }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 发送文件消息异常: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送文件失败: $e')),
      );
    }
  }

  // 发送语音消息
  Future<void> _sendVoiceMessage(String filePath, int duration) async {
    try {
      final result = await VoiceCallHandler().sendVoiceMessage(
        userId: widget.userId,
        targetId: widget.targetId,
        filePath: filePath,
        duration: duration,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 添加消息到列表
        setState(() {
          // 查找是否已存在相同ID的消息
          final message = result['message'];
          final index = _messages.indexWhere((msg) => msg['id'] == message['id']);

          if (index != -1) {
            // 更新现有消息
            _messages[index] = message;
          } else {
            // 添加新消息
            _messages.add(message);
          }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 发送语音消息异常: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送语音消息失败: $e')),
      );
    }
  }

  // 开始语音通话
  Future<void> _startVoiceCall() async {
    try {
      final result = await VoiceCallHandler().startVoiceCall(
        context: context,
        userId: widget.userId,
        targetId: widget.targetId,
        targetName: widget.targetName,
        targetAvatar: widget.targetAvatar,
      );

      if (!mounted) return;

      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 开始语音通话异常: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始语音通话失败: $e')),
      );
    }
  }

  // 开始视频通话
  Future<void> _startVideoCall() async {
    try {
      final result = await VoiceCallHandler().startVideoCall(
        context: context,
        userId: widget.userId,
        targetId: widget.targetId,
        targetName: widget.targetName,
        targetAvatar: widget.targetAvatar,
      );

      if (!mounted) return;

      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 开始视频通话异常: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始视频通话失败: $e')),
      );
    }
  }

  // 标记消息为已读
  Future<void> _markMessagesAsRead() async {
    if (_messages.isEmpty) return;

    try {
      // 获取最后一条消息的ID
      final lastMessage = _messages.last;
      final lastMessageId = lastMessage['id']?.toString();

      if (lastMessageId == null) return;

      // 调用API标记消息为已读
      await Api.markMessagesAsRead(
        targetId: widget.targetId,
        lastMessageId: lastMessageId,
      );

      debugPrint('[ChatDetailPage] 消息已标记为已读');
    } catch (e) {
      debugPrint('[ChatDetailPage] 标记消息为已读失败: $e');
    }
  }

  // 撤回消息
  Future<void> _recallMessage(Map<String, dynamic> message) async {
    final messageId = message['id'];

    try {
      // 调用API撤回消息
      final response = await Api.recallMessage(messageId: messageId.toString());

      if (response['success'] == true) {
        // 更新消息内容为"此消息已被撤回"
        setState(() {
          final index = _messages.indexWhere((msg) => msg['id'] == messageId);
          if (index != -1) {
            _messages[index]['content'] = '此消息已被撤回';
            _messages[index]['type'] = 'recall';
            _messages[index]['recalled'] = true;
          }
        });

        // 保存更新后的消息到本地存储
        await Persistence.saveChatMessages(widget.userId, widget.targetId, _messages);

        // 同时更新LocalMessageStorage
        try {
          await LocalMessageStorage.saveMessage(
            widget.userId,
            widget.targetId,
            {
              'id': messageId,
              'from_id': message['from_id'],
              'to_id': message['to_id'],
              'content': '此消息已被撤回',
              'type': 'recall',
              'created_at': message['created_at'],
              'recalled': true,
            }
          );
        } catch (e) {
          debugPrint('[ChatDetailPage] 更新LocalMessageStorage失败: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('消息已撤回')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤回消息失败: ${response['msg'] ?? '未知错误'}')),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 撤回消息异常: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('撤回消息失败: $e')),
      );
    }
  }

  // 转发消息
  Future<void> _forwardMessage(String messageId) async {
    // 显示联系人选择器
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择转发对象',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: Api.getFriends(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('加载好友列表失败'));
                  }

                  final data = snapshot.data;
                  if (data == null || data['success'] != true || data['data'] == null) {
                    return Center(child: Text('没有好友'));
                  }

                  final friends = List<Map<String, dynamic>>.from(data['data']);

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final friendId = friend['id'];
                      final friendName = friend['nickname'] ?? '未知用户';
                      final friendAvatar = friend['avatar'];

                      return ListTile(
                        leading: AppAvatar(
                          name: friendName,
                          imageUrl: friendAvatar,
                          size: 40,
                        ),
                        title: Text(friendName),
                        onTap: () {
                          Navigator.pop(context, {
                            'id': friendId.toString(),
                            'name': friendName,
                            'type': 'user',
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final targetId = result['id'];
      final targetType = result['type'];

      try {
        // 调用API转发消息
        final response = await Api.forwardMessage(
          messageId: messageId,
          targetId: targetId,
          type: targetType,
        );

        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('消息已转发')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('转发消息失败: ${response['msg'] ?? '未知错误'}')),
          );
        }
      } catch (e) {
        debugPrint('[ChatDetailPage] 转发消息异常: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转发消息失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.targetName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isNetworkConnected)
              Text(
                '在线',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              )
            else
              Text(
                '离线',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              // 显示聊天信息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('查看聊天信息')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 网络状态指示器
          NetworkStatusIndicator(
            showDetails: false,
            autoHide: true,
          ),

          // 消息列表
          Expanded(
            child: _buildMessageList(),
          ),

          // 输入区域
          DraggableChatInput(
            onSendText: _sendTextMessage,
            onSendImage: _sendImageMessage,
            onSendVideo: _sendVideoMessage,
            onSendFile: _sendFileMessage,
            onSendVoiceMessage: _sendVoiceMessage,
            onStartVoiceCall: _startVoiceCall,
            onStartVideoCall: _startVideoCall,
            targetId: widget.targetId,
            targetName: widget.targetName,
            targetAvatar: widget.targetAvatar,
          ),
        ],
      ),
    );
  }

  // 构建消息列表
  Widget _buildMessageList() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text('暂无消息，开始聊天吧'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['from_id'] == int.parse(widget.userId);

        return ChatMessageItem(
          message: message,
          isMe: isMe,
          onRetry: () => _retryMessage(message),
          onRecall: isMe ? () => _recallMessage(message) : null,
          onForward: (messageId) => _forwardMessage(messageId),
          isRead: isMe && message['read'] == true,
          targetName: widget.targetName,
          targetAvatar: widget.targetAvatar,
        );
      },
    );
  }

  // 重试发送失败的消息
  Future<void> _retryMessage(Map<String, dynamic> message) async {
    final type = message['type'] ?? 'text';
    final content = message['content'] ?? '';

    switch (type) {
      case 'text':
        await _sendTextMessage(content);
        break;
      case 'image':
        final file = File(content);
        if (await file.exists()) {
          await _sendImageMessage(file, content);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图片文件不存在')),
          );
        }
        break;
      case 'video':
        final file = File(content);
        if (await file.exists()) {
          await _sendVideoMessage(file, content);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('视频文件不存在')),
          );
        }
        break;
      case 'file':
        final file = File(content);
        if (await file.exists()) {
          final fileName = message['file_name'] ?? path.basename(content);
          await _sendFileMessage(file, content, fileName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件不存在')),
          );
        }
        break;
      case 'voice':
        final file = File(content);
        if (await file.exists()) {
          final duration = message['duration'] ?? 0;
          await _sendVoiceMessage(content, duration);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('语音文件不存在')),
          );
        }
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('不支持重试此类型的消息')),
        );
    }
  }
}
