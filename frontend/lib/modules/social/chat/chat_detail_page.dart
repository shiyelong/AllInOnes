import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/text_sanitizer.dart';
import '../../../widgets/app_avatar.dart';
import 'emoji_picker.dart';
import 'red_packet_dialog.dart';
import 'chat_message_item.dart';
import '../call/voice_call_page.dart';
import '../call/video_call_page.dart';
import '../../../modules/chat/widgets/voice_recorder_widget.dart';
import '../../../modules/chat/widgets/voice_message_widget.dart';
import 'location_picker.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String _error = '';
  bool _showEmoji = false;
  bool _isRecording = false; // 是否正在录音

  @override
  void initState() {
    super.initState();

    // 清理聊天消息，确保没有无效的 UTF-16 字符
    _clearChatMessages().then((_) {
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
      });
    });
  }

  // 清理聊天消息
  Future<void> _clearChatMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_messages_${widget.userId}_${widget.targetId}';
      await prefs.remove(key);
      debugPrint('[ChatDetailPage] 已清理聊天消息: $key');
    } catch (e) {
      debugPrint('[ChatDetailPage] 清理聊天消息失败: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // 打印调试信息
      debugPrint('[ChatDetailPage] 加载消息: userId=${widget.userId}, targetId=${widget.targetId}');

      // 先尝试从本地存储加载消息
      final localMessages = await Persistence.getChatMessages(widget.userId, widget.targetId);
      if (localMessages.isNotEmpty) {
        debugPrint('[ChatDetailPage] 从本地存储加载了 ${localMessages.length} 条消息');

        if (!mounted) return;

        setState(() {
          _messages = localMessages;
          _loading = false;
        });
      }

      // 然后从服务器加载最新消息
      final response = await Api.getMessagesByUser(
        userId: widget.userId,
        targetId: widget.targetId,
      );

      // 打印响应结果
      debugPrint('[ChatDetailPage] 消息加载响应: success=${response['success']}, msg=${response['msg']}');

      if (!mounted) return;

      if (response['success'] == true) {
        // 确保消息按时间排序，最早的消息在前面
        final rawMessages = List<Map<String, dynamic>>.from(response['data'] ?? []);
        debugPrint('[ChatDetailPage] 从服务器获取到 ${rawMessages.length} 条消息');

        // 使用 TextSanitizer 清理消息内容
        final messages = rawMessages.map((msg) => TextSanitizer.sanitizeMessage(msg)).toList();

        messages.sort((a, b) {
          final aTime = a['created_at'] ?? 0;
          final bTime = b['created_at'] ?? 0;
          return aTime.compareTo(bTime);
        });

        // 保存到本地存储
        await Persistence.saveChatMessages(widget.userId, widget.targetId, messages);

        if (!mounted) return;

        setState(() {
          _messages = messages;
          _loading = false;
          _error = ''; // 确保清除错误信息
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
        if (!mounted) return;

        setState(() {
          _error = response['msg'] ?? '加载消息失败';
          _loading = false;
        });

        // 如果是首次加载失败，自动重试
        if (_messages.isEmpty) {
          debugPrint('[ChatDetailPage] 首次加载失败，2秒后自动重试');
          Future.delayed(Duration(seconds: 2), () {
            if (mounted && _error.isNotEmpty) {
              _loadMessages();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[ChatDetailPage] 加载消息异常: $e');

      if (!mounted) return;

      setState(() {
        _error = '加载消息出错: $e';
        _loading = false;
      });

      // 如果是首次加载失败，自动重试
      if (_messages.isEmpty) {
        debugPrint('[ChatDetailPage] 首次加载异常，2秒后自动重试');
        Future.delayed(Duration(seconds: 2), () {
          if (mounted && _error.isNotEmpty) {
            _loadMessages();
          }
        });
      }
    }
  }

  // 发送文本消息
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    // 隐藏表情选择器
    if (_showEmoji) {
      setState(() {
        _showEmoji = false;
      });
    }

    // 先添加一条本地消息，提高响应速度
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'from_id': int.parse(widget.userId),
        'to_id': int.parse(widget.targetId),
        'content': message,
        'type': 'text',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'status': 0, // 发送中
      });
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

    try {
      final response = await Api.sendMessage(
        fromId: widget.userId,
        toId: widget.targetId,
        content: message,
        type: 'text',
      );

      if (response['success'] == true) {
        // 更新消息状态为已发送
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == message &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 1; // 已发送
            _messages[index]['id'] = response['data']['id'] ?? _messages[index]['id'];
          }
        });

        // 保存到本地存储
        await Persistence.saveChatMessages(widget.userId, widget.targetId, _messages);
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == message &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 2; // 发送失败
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? '发送失败')),
        );
      }
    } catch (e) {
      // 更新消息状态为发送失败
      setState(() {
        final index = _messages.indexWhere((msg) =>
          msg['from_id'] == int.parse(widget.userId) &&
          msg['content'] == message &&
          msg['status'] == 0
        );

        if (index != -1) {
          _messages[index]['status'] = 2; // 发送失败
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送出错: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Text(
                widget.targetName[0],
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              widget.targetName,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              // 发起语音通话
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VoiceCallPage(
                    userId: widget.userId,
                    targetId: widget.targetId,
                    targetName: widget.targetName,
                    targetAvatar: widget.targetAvatar,
                    isIncoming: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // 显示更多选项
              showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.person, color: theme.primaryColor),
                        title: Text('查看资料'),
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: 跳转到好友资料页
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('查看资料功能开发中')),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.call, color: theme.primaryColor),
                        title: Text('语音通话'),
                        onTap: () {
                          Navigator.pop(context);
                          // 发起语音通话
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VoiceCallPage(
                                userId: widget.userId,
                                targetId: widget.targetId,
                                targetName: widget.targetName,
                                targetAvatar: widget.targetAvatar,
                                isIncoming: false,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.videocam, color: theme.primaryColor),
                        title: Text('视频通话'),
                        onTap: () {
                          Navigator.pop(context);
                          // 发起视频通话
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoCallPage(
                                userId: widget.userId,
                                targetId: widget.targetId,
                                targetName: widget.targetName,
                                targetAvatar: widget.targetAvatar,
                                isIncoming: false,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('清空聊天记录'),
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: 清空聊天记录
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('清空聊天记录功能开发中')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // 使用渐变背景，类似QQ的聊天背景
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              theme.backgroundColor,
            ],
          ),
        ),
        child: Column(
          children: [
            // 消息列表
            Expanded(
              child: _buildMessageList(),
            ),
            // 输入框
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('加载消息中...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error.isNotEmpty && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                debugPrint('[ChatDetailPage] 用户点击重试按钮');
                _loadMessages();
              },
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text('暂无消息，发送一条消息开始聊天吧', style: TextStyle(color: Colors.grey)),
      );
    }

    // 如果有消息但仍在加载更多，可以在顶部显示加载指示器
    if (_loading && _messages.isNotEmpty) {
      return Stack(
        children: [
          _buildMessageListView(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '加载更多消息...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _buildMessageListView();
  }

  Widget _buildMessageListView() {
    final theme = ThemeManager.currentTheme;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        // 确保from_id是整数类型
        int fromId;
        if (message['from_id'] is String) {
          fromId = int.tryParse(message['from_id'].toString()) ?? 0;
        } else {
          fromId = message['from_id'] ?? 0;
        }

        final isSelf = fromId == int.parse(widget.userId);
        final status = message['status'] ?? 1; // 默认为已发送

        // 检查是否需要显示日期分隔线
        Widget? dateHeader;
        if (index == 0 || _shouldShowDateHeader(index)) {
          dateHeader = _buildDateHeader(message['created_at'] ?? 0);
        }

        return Column(
          children: [
            if (dateHeader != null) dateHeader,
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSelf) ...[
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.primaryColor.withOpacity(0.2),
                      child: Text(
                        widget.targetName[0],
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        _buildMessageContent(message, isSelf),
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message['created_at'] ?? 0),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            if (isSelf) ...[
                              SizedBox(width: 4),
                              if (status == 0)
                                Icon(Icons.access_time, size: 12, color: Colors.grey)
                              else if (status == 1)
                                Icon(Icons.check, size: 12, color: Colors.green)
                              else if (status == 2)
                                Icon(Icons.error_outline, size: 12, color: Colors.red)
                              else if (status == 3) // 已送达
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 12, color: Colors.grey),
                                    Icon(Icons.check, size: 12, color: Colors.grey),
                                  ],
                                )
                              else if (status == 4) // 已读
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 12, color: theme.primaryColor),
                                    Icon(Icons.check, size: 12, color: theme.primaryColor),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelf) ...[
                    SizedBox(width: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.primaryColor,
                      child: Text(
                        (Persistence.getUserInfo()?.nickname ?? '我')[0],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 判断是否需要显示日期分隔线
  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;

    final currentMsg = _messages[index];
    final prevMsg = _messages[index - 1];

    final currentTime = currentMsg['created_at'] ?? 0;
    final prevTime = prevMsg['created_at'] ?? 0;

    // 如果两条消息的日期不同，显示日期分隔线
    final currentDate = DateTime.fromMillisecondsSinceEpoch(currentTime * 1000);
    final prevDate = DateTime.fromMillisecondsSinceEpoch(prevTime * 1000);

    return currentDate.year != prevDate.year ||
           currentDate.month != prevDate.month ||
           currentDate.day != prevDate.day;
  }

  // 构建日期分隔线
  Widget _buildDateHeader(int timestamp) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDateHeader(timestamp),
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
        ],
      ),
    );
  }

  // 格式化日期分隔线的日期
  String _formatDateHeader(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '今天';
    } else if (messageDate == yesterday) {
      return '昨天';
    } else if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }

  // 发送图片消息
  Future<void> _sendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      // 先添加一条本地消息，提高响应速度
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'from_id': int.parse(widget.userId),
          'to_id': int.parse(widget.targetId),
          'content': image.path,
          'type': 'image',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'status': 0, // 发送中
        });
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

      // 上传图片
      final uploadResponse = await Api.uploadFile(image.path, 'image');

      if (uploadResponse['success'] == true) {
        final imageUrl = uploadResponse['data']['url'];

        // 发送图片消息
        final response = await Api.sendImageMessage(
          int.parse(widget.targetId),
          imageUrl
        );

        if (response['success'] == true) {
          // 更新消息状态为已发送
          setState(() {
            final index = _messages.indexWhere((msg) =>
              msg['from_id'] == int.parse(widget.userId) &&
              msg['content'] == image.path &&
              msg['status'] == 0
            );

            if (index != -1) {
              _messages[index]['status'] = 1; // 已发送
              _messages[index]['id'] = response['data']['id'] ?? _messages[index]['id'];
              _messages[index]['content'] = imageUrl; // 更新为服务器URL
            }
          });
        } else {
          // 更新消息状态为发送失败
          setState(() {
            final index = _messages.indexWhere((msg) =>
              msg['from_id'] == int.parse(widget.userId) &&
              msg['content'] == image.path &&
              msg['status'] == 0
            );

            if (index != -1) {
              _messages[index]['status'] = 2; // 发送失败
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['msg'] ?? '发送图片消息失败')),
          );
        }
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == image.path &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 2; // 发送失败
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploadResponse['msg'] ?? '上传图片失败')),
        );
      }
    } catch (e) {
      // 更新消息状态为发送失败
      setState(() {
        final index = _messages.indexWhere((msg) =>
          msg['from_id'] == int.parse(widget.userId) &&
          msg['type'] == 'image' &&
          msg['status'] == 0
        );

        if (index != -1) {
          _messages[index]['status'] = 2; // 发送失败
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送图片失败: $e')),
      );
    }
  }

  // 发送视频消息
  Future<void> _sendVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return;

      // 先添加一条本地消息，提高响应速度
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'from_id': int.parse(widget.userId),
          'to_id': int.parse(widget.targetId),
          'content': video.path,
          'type': 'video',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'status': 0, // 发送中
        });
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

      // 上传视频
      final uploadResponse = await Api.uploadFile(video.path, 'video');

      if (uploadResponse['success'] == true) {
        final videoUrl = uploadResponse['data']['url'];

        // 发送视频消息
        final response = await Api.sendVideoMessage(
          int.parse(widget.targetId),
          videoUrl,
          null // 暂时不提供缩略图
        );

        if (response['success'] == true) {
          // 更新消息状态为已发送
          setState(() {
            final index = _messages.indexWhere((msg) =>
              msg['from_id'] == int.parse(widget.userId) &&
              msg['content'] == video.path &&
              msg['status'] == 0
            );

            if (index != -1) {
              _messages[index]['status'] = 1; // 已发送
              _messages[index]['id'] = response['data']['id'] ?? _messages[index]['id'];
              _messages[index]['content'] = videoUrl; // 更新为服务器URL
            }
          });
        } else {
          // 更新消息状态为发送失败
          setState(() {
            final index = _messages.indexWhere((msg) =>
              msg['from_id'] == int.parse(widget.userId) &&
              msg['content'] == video.path &&
              msg['status'] == 0
            );

            if (index != -1) {
              _messages[index]['status'] = 2; // 发送失败
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['msg'] ?? '发送视频消息失败')),
          );
        }
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == video.path &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 2; // 发送失败
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploadResponse['msg'] ?? '上传视频失败')),
        );
      }
    } catch (e) {
      // 更新消息状态为发送失败
      setState(() {
        final index = _messages.indexWhere((msg) =>
          msg['from_id'] == int.parse(widget.userId) &&
          msg['type'] == 'video' &&
          msg['status'] == 0
        );

        if (index != -1) {
          _messages[index]['status'] = 2; // 发送失败
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送视频失败: $e')),
      );
    }
  }

  // 发送文件消息
  Future<void> _sendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // 先添加一条本地消息，提高响应速度
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'from_id': int.parse(widget.userId),
          'to_id': int.parse(widget.targetId),
          'content': fileName,
          'extra': file.path,
          'type': 'file',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'status': 0, // 发送中
        });
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

      // 上传文件
      final uploadResponse = await Api.uploadFile(file.path, 'file');

      if (uploadResponse['success'] == true) {
        final fileUrl = uploadResponse['data']['url'];

        // 发送文件消息
        final response = await Api.sendFileMessage(
          int.parse(widget.targetId),
          fileUrl,
          fileName,
          uploadResponse['data']['file_size'] ?? 0
        );

        if (response['success'] == true) {
          // 更新消息状态为已发送
          setState(() {
            final index = _messages.indexWhere((msg) =>
              msg['from_id'] == int.parse(widget.userId) &&
              msg['content'] == fileName &&
              msg['status'] == 0
            );

            if (index != -1) {
              _messages[index]['status'] = 1; // 已发送
              _messages[index]['id'] = response['data']['id'] ?? _messages[index]['id'];
              _messages[index]['extra'] = jsonEncode({
                'url': fileUrl,
                'name': fileName,
                'size': uploadResponse['data']['file_size'] ?? 0
              });
            }
          });
        } else {
          // 更新消息状态为发送失败
          setState(() {
            final index = _messages.indexWhere((msg) =>
              msg['from_id'] == int.parse(widget.userId) &&
              msg['content'] == fileName &&
              msg['status'] == 0
            );

            if (index != -1) {
              _messages[index]['status'] = 2; // 发送失败
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['msg'] ?? '发送文件消息失败')),
          );
        }
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == fileName &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 2; // 发送失败
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploadResponse['msg'] ?? '上传文件失败')),
        );
      }
    } catch (e) {
      // 更新消息状态为发送失败
      setState(() {
        final index = _messages.indexWhere((msg) =>
          msg['from_id'] == int.parse(widget.userId) &&
          msg['type'] == 'file' &&
          msg['status'] == 0
        );

        if (index != -1) {
          _messages[index]['status'] = 2; // 发送失败
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送文件失败: $e')),
      );
    }
  }

  // 发送表情
  void _sendEmoji(String emoji) {
    setState(() {
      _showEmoji = false;
    });

    // 先添加一条本地消息，提高响应速度
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'from_id': int.parse(widget.userId),
        'to_id': int.parse(widget.targetId),
        'content': emoji,
        'type': 'emoji',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'status': 0, // 发送中
      });
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

    // 模拟发送成功
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        final index = _messages.indexWhere((msg) =>
          msg['from_id'] == int.parse(widget.userId) &&
          msg['content'] == emoji &&
          msg['status'] == 0
        );

        if (index != -1) {
          _messages[index]['status'] = 1; // 已发送
        }
      });
    });
  }

  // 发送语音消息
  Future<void> _sendVoiceMessage(String audioPath, int duration, String? transcription) async {
    try {
      // 读取音频文件
      final file = File(audioPath);
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      // 先添加一条本地消息，提高响应速度
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'from_id': int.parse(widget.userId),
          'to_id': int.parse(widget.targetId),
          'content': audioPath, // 临时使用本地路径
          'type': 'voice',
          'created_at': timestamp,
          'status': 0, // 发送中
          'extra': jsonEncode({
            'duration': duration,
            'text': transcription ?? '',
          }),
        });
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

      // 发送到服务器
      final response = await Api.post('/speech/send', data: {
        'to_id': int.parse(widget.targetId),
        'audio_data': base64Audio,
        'format': 'aac', // 假设格式是aac
        'duration': duration,
      });

      if (response['success'] == true) {
        // 更新消息状态为已发送，并更新内容为服务器返回的URL
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == audioPath &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 1; // 已发送
            _messages[index]['id'] = response['data']['message_id'] ?? _messages[index]['id'];
            _messages[index]['content'] = response['data']['audio_url'] ?? _messages[index]['content'];

            // 更新转录文本
            final extra = jsonDecode(_messages[index]['extra'] ?? '{}');
            extra['text'] = response['data']['text'] ?? extra['text'];
            _messages[index]['extra'] = jsonEncode(extra);
          }
        });
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == audioPath &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 2; // 发送失败
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? '发送语音消息失败')),
        );
      }
    } catch (e) {
      // 更新消息状态为发送失败
      setState(() {
        final index = _messages.indexWhere((msg) =>
          msg['from_id'] == int.parse(widget.userId) &&
          msg['content'] == audioPath &&
          msg['status'] == 0
        );

        if (index != -1) {
          _messages[index]['status'] = 2; // 发送失败
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送语音消息出错: $e')),
      );
    }
  }

  Widget _buildInputArea() {
    final theme = ThemeManager.currentTheme;

    // 如果正在录音，显示录音界面
    if (_isRecording) {
      return VoiceRecorderWidget(
        onVoiceRecorded: (audioPath, duration, transcription) {
          setState(() {
            _isRecording = false;
          });
          _sendVoiceMessage(audioPath, duration, transcription);
        },
        onCancel: () {
          setState(() {
            _isRecording = false;
          });
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 表情选择器
        if (_showEmoji)
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: theme.isDark ? Colors.grey[900] : Colors.grey[100],
              border: Border(
                top: BorderSide(
                  color: theme.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: EmojiPicker(
              onSelected: (emoji) {
                // 将表情插入到输入框而不是直接发送
                final currentText = _messageController.text;
                final selection = _messageController.selection;
                final newText = currentText.replaceRange(
                  selection.start,
                  selection.end,
                  emoji,
                );
                _messageController.text = newText;
                _messageController.selection = TextSelection.collapsed(
                  offset: selection.baseOffset + emoji.length,
                );
              },
            ),
          ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.grey[900] : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.emoji_emotions_outlined,
                  color: _showEmoji ? theme.primaryColor : Colors.grey[600],
                  size: 24,
                ),
                onPressed: () {
                  // 确保输入框获得焦点，这样表情可以插入到输入框中
                  FocusScope.of(context).requestFocus(FocusNode());

                  // 延迟一下再显示表情选择器，确保键盘已经收起
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (mounted) {
                      setState(() {
                        _showEmoji = !_showEmoji;
                      });
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey[600],
                  size: 24,
                ),
                onPressed: () {
                  // 显示更多功能
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: theme.isDark ? Colors.grey[900] : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) => GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      padding: EdgeInsets.all(16),
                      children: [
                        _buildMoreItem(Icons.image, '图片', () {
                          Navigator.pop(context);
                          _sendImage();
                        }),
                        _buildMoreItem(Icons.camera_alt, '拍照', () {
                          Navigator.pop(context);
                          // 使用相机拍照
                          ImagePicker().pickImage(source: ImageSource.camera).then((image) {
                            if (image != null) {
                              // 处理拍照结果
                              // 这里可以复用_sendImage的逻辑
                              // 先添加一条本地消息，提高响应速度
                              setState(() {
                                _messages.add({
                                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                  'from_id': int.parse(widget.userId),
                                  'to_id': int.parse(widget.targetId),
                                  'content': image.path,
                                  'type': 'image',
                                  'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                  'status': 0, // 发送中
                                });
                              });

                              // 模拟发送成功
                              Future.delayed(Duration(seconds: 1), () {
                                setState(() {
                                  final index = _messages.indexWhere((msg) =>
                                    msg['from_id'] == int.parse(widget.userId) &&
                                    msg['content'] == image.path &&
                                    msg['status'] == 0
                                  );

                                  if (index != -1) {
                                    _messages[index]['status'] = 1; // 已发送
                                  }
                                });
                              });
                            }
                          });
                        }),
                        _buildMoreItem(Icons.videocam, '视频', () {
                          Navigator.pop(context);
                          _sendVideo();
                        }),
                        _buildMoreItem(Icons.file_copy, '文件', () {
                          Navigator.pop(context);
                          _sendFile();
                        }),
                        _buildMoreItem(Icons.mic, '语音消息', () {
                          Navigator.pop(context);
                          setState(() {
                            _isRecording = true;
                          });
                        }),
                        _buildMoreItem(Icons.call, '语音通话', () {
                          Navigator.pop(context);
                          // 发起语音通话
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VoiceCallPage(
                                userId: widget.userId,
                                targetId: widget.targetId,
                                targetName: widget.targetName,
                                targetAvatar: widget.targetAvatar,
                                isIncoming: false,
                              ),
                            ),
                          );
                        }),
                        _buildMoreItem(Icons.video_call, '视频通话', () {
                          Navigator.pop(context);
                          // 发起视频通话
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoCallPage(
                                userId: widget.userId,
                                targetId: widget.targetId,
                                targetName: widget.targetName,
                                targetAvatar: widget.targetAvatar,
                                isIncoming: false,
                              ),
                            ),
                          );
                        }),
                        _buildMoreItem(Icons.card_giftcard, '红包', () {
                          Navigator.pop(context);
                          // 显示红包对话框
                          showDialog(
                            context: context,
                            builder: (context) => RedPacketDialog(
                              receiverId: int.parse(widget.targetId),
                              onSend: (amount, greeting) async {
                                // 获取用户信息
                                final userInfo = Persistence.getUserInfo();
                                if (userInfo == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('用户信息不存在，请重新登录')),
                                  );
                                  return;
                                }

                                // 先添加一条本地消息，提高响应速度
                                setState(() {
                                  _messages.add({
                                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                    'from_id': int.parse(widget.userId),
                                    'to_id': int.parse(widget.targetId),
                                    'content': greeting,
                                    'type': 'redpacket',
                                    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                    'status': 0, // 发送中
                                    'extra': jsonEncode({
                                      'amount': amount,
                                      'count': 1,
                                    }),
                                  });
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

                                try {
                                  // 发送红包
                                  final resp = await Api.sendRedPacketWithWallet(
                                    senderID: userInfo.id.toString(),
                                    receiverID: widget.targetId,
                                    amount: amount,
                                    count: 1,
                                    greeting: greeting,
                                  );

                                  if (resp['success'] == true) {
                                    // 更新消息状态为已发送
                                    setState(() {
                                      final index = _messages.indexWhere((msg) =>
                                        msg['from_id'] == int.parse(widget.userId) &&
                                        msg['content'] == greeting &&
                                        msg['type'] == 'redpacket' &&
                                        msg['status'] == 0
                                      );

                                      if (index != -1) {
                                        _messages[index]['status'] = 1; // 已发送
                                        _messages[index]['id'] = resp['data']['message_id'] ?? _messages[index]['id'];

                                        // 更新红包ID
                                        final extra = jsonDecode(_messages[index]['extra'] ?? '{}');
                                        extra['red_packet_id'] = resp['data']['red_packet_id'];
                                        _messages[index]['extra'] = jsonEncode(extra);
                                      }
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('红包发送成功'), backgroundColor: Colors.green),
                                    );
                                  } else {
                                    // 更新消息状态为发送失败
                                    setState(() {
                                      final index = _messages.indexWhere((msg) =>
                                        msg['from_id'] == int.parse(widget.userId) &&
                                        msg['content'] == greeting &&
                                        msg['type'] == 'redpacket' &&
                                        msg['status'] == 0
                                      );

                                      if (index != -1) {
                                        _messages[index]['status'] = 2; // 发送失败
                                      }
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(resp['msg'] ?? '发送红包失败'), backgroundColor: Colors.red),
                                    );
                                  }
                                } catch (e) {
                                  // 更新消息状态为发送失败
                                  setState(() {
                                    final index = _messages.indexWhere((msg) =>
                                      msg['from_id'] == int.parse(widget.userId) &&
                                      msg['content'] == greeting &&
                                      msg['type'] == 'redpacket' &&
                                      msg['status'] == 0
                                    );

                                    if (index != -1) {
                                      _messages[index]['status'] = 2; // 发送失败
                                    }
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('发送红包出错: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                            ),
                          );
                        }),
                        _buildMoreItem(Icons.location_on, '位置', () {
                          Navigator.pop(context);
                          // 显示位置选择对话框
                          showDialog(
                            context: context,
                            builder: (context) => LocationPickerDialog(
                              onLocationSelected: (latitude, longitude, address) {
                                _sendLocationMessage(latitude, longitude, address);
                              },
                            ),
                          );
                        }),
                        _buildMoreItem(Icons.account_balance_wallet, '转账', () {
                          Navigator.pop(context);
                          // 显示转账对话框
                          final amountController = TextEditingController();
                          final messageController = TextEditingController();

                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('转账'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: amountController,
                                    decoration: InputDecoration(
                                      labelText: '金额',
                                      hintText: '请输入转账金额',
                                      prefixIcon: Icon(Icons.attach_money),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  ),
                                  SizedBox(height: 16),
                                  TextField(
                                    controller: messageController,
                                    decoration: InputDecoration(
                                      labelText: '留言',
                                      hintText: '请输入转账留言（可选）',
                                      prefixIcon: Icon(Icons.message),
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('取消'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final amount = double.tryParse(amountController.text);
                                    if (amount != null && amount > 0) {
                                      Navigator.pop(context);

                                      final userInfo = Persistence.getUserInfo();
                                      if (userInfo == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('用户信息不存在，请重新登录')),
                                        );
                                        return;
                                      }

                                      try {
                                        final resp = await Api.transfer(
                                          senderID: userInfo.id,
                                          receiverID: int.parse(widget.targetId),
                                          amount: amount,
                                          message: messageController.text,
                                        );

                                        if (resp['success'] == true) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('转账成功'), backgroundColor: Colors.green),
                                          );

                                          // 添加转账消息
                                          setState(() {
                                            _messages.add({
                                              'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                              'from_id': int.parse(widget.userId),
                                              'to_id': int.parse(widget.targetId),
                                              'content': messageController.text,
                                              'type': 'transfer',
                                              'extra': '{"amount": ${amount.toStringAsFixed(2)}}',
                                              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                              'status': 1, // 已发送
                                            });
                                          });
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(resp['msg'] ?? '转账失败'), backgroundColor: Colors.red),
                                          );
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('网络异常: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('请输入有效金额')),
                                      );
                                    }
                                  },
                                  child: Text('转账'),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
              // 语音按钮
              IconButton(
                icon: Icon(
                  Icons.mic,
                  color: Colors.grey[600],
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _isRecording = true;
                  });
                },
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: theme.isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IgnorePointer(
                    ignoring: false, // 设置为true可以禁用拖拽，但会影响正常输入
                    child: AbsorbPointer(
                      absorbing: false, // 设置为true可以禁用拖拽，但会影响正常输入
                      child: DragTarget<String>(
                        onWillAccept: (data) {
                          // 拒绝所有拖拽
                          return false;
                        },
                        builder: (context, candidateData, rejectedData) {
                          return TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: '输入消息...',
                              hintStyle: TextStyle(
                                color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            style: TextStyle(
                              color: theme.isDark ? Colors.white : Colors.black,
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            // 禁用拖拽功能
                            enableInteractiveSelection: true, // 允许文本选择
                            maxLines: 4, // 限制最大行数
                            minLines: 1, // 最小行数
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.send,
                  color: theme.primaryColor,
                  size: 24,
                ),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 发送位置消息
  Future<void> _sendLocationMessage(double latitude, double longitude, String address) async {
    try {
      // 先添加一条本地消息，提高响应速度
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'from_id': int.parse(widget.userId),
          'to_id': int.parse(widget.targetId),
          'content': address,
          'type': 'location',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'status': 0, // 发送中
          'extra': jsonEncode({
            'latitude': latitude,
            'longitude': longitude,
          }),
        });
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

      // 发送位置消息
      final response = await Api.sendLocationMessage(
        int.parse(widget.targetId),
        latitude,
        longitude,
        address,
      );

      if (response['success'] == true) {
        // 更新消息状态为已发送
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == address &&
            msg['type'] == 'location' &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 1; // 已发送
            _messages[index]['id'] = response['data']['id'] ?? _messages[index]['id'];
          }
        });
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == int.parse(widget.userId) &&
            msg['content'] == address &&
            msg['type'] == 'location' &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 2; // 发送失败
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? '发送位置消息失败')),
        );
      }
    } catch (e) {
      // 更新消息状态为发送失败
      setState(() {
        final index = _messages.indexWhere((msg) =>
          msg['from_id'] == int.parse(widget.userId) &&
          msg['type'] == 'location' &&
          msg['status'] == 0
        );

        if (index != -1) {
          _messages[index]['status'] = 2; // 发送失败
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送位置消息出错: $e')),
      );
    }
  }

  // 构建消息内容
  Widget _buildMessageContent(Map<String, dynamic> message, bool isSelf) {
    final theme = ThemeManager.currentTheme;
    final type = message['type'] ?? 'text';

    // 获取气泡颜色和文本颜色
    final bubbleColor = isSelf ? theme.selfMessageBubbleColor : theme.otherMessageBubbleColor;
    final textColor = isSelf ? theme.selfMessageTextColor : theme.otherMessageTextColor;

    // 根据消息类型构建不同的气泡形状
    BorderRadius bubbleRadius;
    if (isSelf) {
      bubbleRadius = BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    } else {
      bubbleRadius = BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

    switch (type) {
      case 'voice':
        // 解析语音消息的额外信息
        Map<String, dynamic> extra = {};
        try {
          if (message['extra'] != null) {
            extra = jsonDecode(message['extra']);
          }
        } catch (e) {
          debugPrint('解析语音消息额外信息失败: $e');
        }

        final duration = extra['duration'] ?? 0;
        final transcription = extra['text'];

        return VoiceMessageWidget(
          audioUrl: message['content'] ?? '',
          duration: duration,
          transcription: transcription,
          isMe: isSelf,
        );
      case 'image':
        return Container(
          constraints: BoxConstraints(maxWidth: 200),
          child: ClipRRect(
            borderRadius: bubbleRadius,
            child: _buildImageWidget(message['content'] ?? ''),
          ),
        );
      case 'video':
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: bubbleRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam,
                color: textColor,
              ),
              SizedBox(width: 8),
              Text(
                '视频',
                style: TextStyle(
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      case 'file':
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: bubbleRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file,
                color: textColor,
              ),
              SizedBox(width: 8),
              Text(
                message['content'] ?? '文件',
                style: TextStyle(
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      case 'emoji':
        return Container(
          padding: EdgeInsets.all(12),
          child: Text(
            message['content'] ?? '',
            style: TextStyle(fontSize: 24),
          ),
        );
      case 'location':
        // 解析位置消息的额外信息
        Map<String, dynamic> extra = {};
        try {
          if (message['extra'] != null) {
            extra = jsonDecode(message['extra'].toString());
          }
        } catch (e) {
          debugPrint('解析位置消息额外信息失败: $e');
        }

        final latitude = extra['latitude'] ?? 0.0;
        final longitude = extra['longitude'] ?? 0.0;

        return Container(
          constraints: BoxConstraints(maxWidth: 200),
          child: LocationMessageWidget(
            latitude: latitude is int ? latitude.toDouble() : latitude,
            longitude: longitude is int ? longitude.toDouble() : longitude,
            address: message['content'] ?? '未知位置',
            onTap: () {
              // 打开地图应用
              final url = 'https://maps.google.com/maps?q=$latitude,$longitude';
              launchUrl(Uri.parse(url));
            },
          ),
        );
      case 'text':
      default:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: bubbleRadius,
          ),
          child: Text(
            message['content'] ?? '',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          ),
        );
    }
  }

  Widget _buildMoreItem(IconData icon, String label, VoidCallback onTap) {
    final theme = ThemeManager.currentTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.primaryColor,
              size: 28,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // 构建图片消息组件
  Widget _buildImageWidget(String imagePath) {
    // 检查是否是本地文件路径
    if (imagePath.startsWith('/') || imagePath.startsWith('file://')) {
      // 本地文件路径
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image file: $error');
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600]),
          );
        },
      );
    } else if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // 网络图片URL
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading network image: $error');
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600]),
          );
        },
      );
    } else {
      // 可能是相对路径或API路径，尝试添加基础URL
      final baseUrl = Api.baseUrl;
      final fullUrl = imagePath.startsWith('/')
          ? '$baseUrl$imagePath'
          : '$baseUrl/$imagePath';

      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image with base URL: $error');
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600]),
          );
        },
      );
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      // 今天
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      // 昨天
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year) {
      // 今年
      return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      // 往年
      return '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
