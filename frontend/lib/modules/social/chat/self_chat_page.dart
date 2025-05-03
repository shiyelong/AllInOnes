import 'package:flutter/material.dart';
import 'dart:io';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import 'self_chat_message_list.dart';
import 'self_chat_input.dart';
import 'chat_service.dart';

/// 自己的设备聊天页面
/// 用于给自己发送消息、文件等
class SelfChatPage extends StatefulWidget {
  @override
  _SelfChatPageState createState() => _SelfChatPageState();
}

class _SelfChatPageState extends State<SelfChatPage> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String _error = '';
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        setState(() {
          _error = '未获取到用户信息，请重新登录';
          _loading = false;
        });
        return;
      }

      // 获取与自己的聊天记录
      final messages = await ChatService.fetchMessages(userId);

      // 按时间排序，确保最新的消息在底部
      messages.sort((a, b) {
        final aTime = a['created_at'] ?? 0;
        final bTime = b['created_at'] ?? 0;
        return aTime.compareTo(bTime);
      });

      setState(() {
        _messages = messages;
        _loading = false;
      });

      // 滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() {
        _error = '加载消息失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _sendText(String text) async {
    final userId = Persistence.getUserInfo()?.id ?? 0;

    // 先添加一条本地消息，提高响应速度
    setState(() {
      _messages = List<Map<String, dynamic>>.from(_messages)
        ..add({
          "from_id": userId,
          "to_id": userId,
          "content": text,
          "type": "text",
          "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
          "status": 0, // 发送中
        });
    });

    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });

    try {
      final success = await ChatService.sendMessage(userId, text);

      if (success) {
        // 刷新消息列表
        _loadMessages();
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = _messages.indexWhere((msg) =>
            msg['from_id'] == userId &&
            msg['content'] == text &&
            msg['status'] == 0
          );

          if (index != -1) {
            _messages[index]['status'] = 2; // 发送失败
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('发送消息失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送消息失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = Persistence.getUserInfo();
    final userName = userInfo?.nickname ?? userInfo?.account ?? '我';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('我的设备'),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '仅自己可见',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // 提示信息
          Container(
            padding: EdgeInsets.all(12),
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '这是您的私人空间，可以给自己发送消息、文件等，方便在不同设备间传输数据',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // 消息列表
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error, style: TextStyle(color: Colors.red)),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadMessages,
                              child: Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('暂无消息', style: TextStyle(color: Colors.grey)),
                                SizedBox(height: 16),
                                Text(
                                  '发送一条消息给自己吧',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : SelfChatMessageList(
                            messages: _messages,
                            controller: _scrollCtrl,
                          ),
          ),

          // 输入框
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            child: SelfChatInput(
              onSendText: _sendText,
              onSendImage: (image, path) async {
                final userId = Persistence.getUserInfo()?.id ?? 0;

                // 先添加一条本地消息，提高响应速度
                setState(() {
                  _messages = List<Map<String, dynamic>>.from(_messages)
                    ..add({
                      "from_id": userId,
                      "to_id": userId,
                      "content": path, // 临时使用本地路径
                      "type": "image",
                      "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      "status": 0, // 发送中
                    });
                });

                // 滚动到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });

                try {
                  // 这里应该上传图片到服务器，获取URL后发送消息
                  // 目前简化处理，直接发送成功提示
                  await Future.delayed(Duration(seconds: 1)); // 模拟网络延迟

                  // 更新消息状态为已发送
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == path &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 1; // 已发送
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('图片发送成功'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  print('发送图片失败: $e');

                  // 更新消息状态为发送失败
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == path &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 2; // 发送失败
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('发送图片失败: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              onSendEmoji: (emoji) async {
                final userId = Persistence.getUserInfo()?.id ?? 0;

                // 先添加一条本地消息，提高响应速度
                setState(() {
                  _messages = List<Map<String, dynamic>>.from(_messages)
                    ..add({
                      "from_id": userId,
                      "to_id": userId,
                      "content": emoji,
                      "type": "emoji",
                      "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      "status": 0, // 发送中
                    });
                });

                // 滚动到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });

                try {
                  // 这里应该调用API发送表情
                  // 目前简化处理，直接发送成功提示
                  await Future.delayed(Duration(milliseconds: 500)); // 模拟网络延迟

                  // 更新消息状态为已发送
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == emoji &&
                      msg['type'] == 'emoji' &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 1; // 已发送
                    }
                  });
                } catch (e) {
                  print('发送表情失败: $e');

                  // 更新消息状态为发送失败
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == emoji &&
                      msg['type'] == 'emoji' &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 2; // 发送失败
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('发送表情失败: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              onSendVideo: (video, path) async {
                final userId = Persistence.getUserInfo()?.id ?? 0;

                // 先添加一条本地消息，提高响应速度
                setState(() {
                  _messages = List<Map<String, dynamic>>.from(_messages)
                    ..add({
                      "from_id": userId,
                      "to_id": userId,
                      "content": path, // 临时使用本地路径
                      "type": "video",
                      "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      "status": 0, // 发送中
                    });
                });

                // 滚动到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });

                try {
                  // 这里应该上传视频到服务器，获取URL后发送消息
                  // 目前简化处理，直接发送成功提示
                  await Future.delayed(Duration(seconds: 1)); // 模拟网络延迟

                  // 更新消息状态为已发送
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == path &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 1; // 已发送
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('视频发送成功'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  print('发送视频失败: $e');

                  // 更新消息状态为发送失败
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == path &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 2; // 发送失败
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('发送视频失败: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              onSendFile: (file, path, fileName) async {
                final userId = Persistence.getUserInfo()?.id ?? 0;

                // 先添加一条本地消息，提高响应速度
                setState(() {
                  _messages = List<Map<String, dynamic>>.from(_messages)
                    ..add({
                      "from_id": userId,
                      "to_id": userId,
                      "content": path, // 临时使用本地路径
                      "type": "file",
                      "extra": fileName, // 文件名存在extra字段
                      "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      "status": 0, // 发送中
                    });
                });

                // 滚动到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });

                try {
                  // 这里应该上传文件到服务器，获取URL后发送消息
                  // 目前简化处理，直接发送成功提示
                  await Future.delayed(Duration(seconds: 1)); // 模拟网络延迟

                  // 更新消息状态为已发送
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == path &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 1; // 已发送
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('文件发送成功'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  print('发送文件失败: $e');

                  // 更新消息状态为发送失败
                  setState(() {
                    final index = _messages.indexWhere((msg) =>
                      msg['from_id'] == userId &&
                      msg['content'] == path &&
                      msg['status'] == 0
                    );

                    if (index != -1) {
                      _messages[index]['status'] = 2; // 发送失败
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('发送文件失败: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
