import 'package:flutter/material.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/api.dart';
import '../../../common/local_message_storage.dart';
import '../../../widgets/app_avatar.dart';
import 'add_friend_dialog.dart';
import 'chat_detail.dart';
import 'chat_service.dart';
import 'chat_detail_page.dart';
import 'self_chat_page.dart';
import '../friends/friends_page.dart';
import 'widgets/telegram_style_chat_list_item.dart';

/// 二栏式聊天界面（桌面端）
/// 左侧：最近聊天列表
/// 右侧：聊天内容
class TwoPanelChatPage extends StatefulWidget {
  @override
  _TwoPanelChatPageState createState() => _TwoPanelChatPageState();
}

class _TwoPanelChatPageState extends State<TwoPanelChatPage> {
  // 好友列表
  List _friends = [];
  bool _loadingFriends = true;
  String _friendsError = '';

  // 聊天列表
  List _recentChats = [];
  bool _loadingChats = true;
  String _chatsError = '';

  // 消息列表
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = false;
  String _messagesError = '';

  // 选中的好友和聊天
  int? _selectedFriendIdx;
  int? _selectedChatIdx;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadRecentChats();
  }

  // 加载好友列表
  Future<void> _loadFriends() async {
    setState(() {
      _loadingFriends = true;
      _friendsError = '';
    });

    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        // 自动重试获取用户信息
        await Future.delayed(Duration(seconds: 1));
        final userInfo = await Persistence.getUserInfoAsync();
        if (userInfo?.id == null) {
          setState(() {
            _friendsError = '未获取到用户信息，正在重试...';
            _loadingFriends = false;
          });
          // 延迟后自动重试
          Future.delayed(Duration(seconds: 2), _loadFriends);
          return;
        }
      }

      final response = await Api.getFriendList();

      if (response['success'] == true) {
        setState(() {
          _friends = response['data'] ?? [];
          _loadingFriends = false;
        });
      } else {
        setState(() {
          _friendsError = response['msg'] ?? '加载好友列表失败';
          _loadingFriends = false;
        });
        // 延迟后自动重试
        Future.delayed(Duration(seconds: 3), _loadFriends);
      }
    } catch (e) {
      setState(() {
        _friendsError = '加载好友列表出错，正在重试...';
        _loadingFriends = false;
      });
      // 延迟后自动重试
      Future.delayed(Duration(seconds: 3), _loadFriends);
    }
  }

  // 加载最近聊天列表
  Future<void> _loadRecentChats() async {
    setState(() {
      _loadingChats = true;
      _chatsError = '';
    });

    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        // 自动重试获取用户信息
        await Future.delayed(Duration(seconds: 1));
        final userInfo = await Persistence.getUserInfoAsync();
        if (userInfo?.id == null) {
          setState(() {
            _chatsError = '未获取到用户信息，正在重试...';
            _loadingChats = false;
          });
          // 延迟后自动重试
          Future.delayed(Duration(seconds: 2), _loadRecentChats);
          return;
        }
      }

      final chats = await ChatService.fetchRecentChats(userId ?? 0);
      setState(() {
        _recentChats = chats;
        _loadingChats = false;
      });
    } catch (e) {
      setState(() {
        _chatsError = '加载聊天列表出错，正在重试...';
        _loadingChats = false;
      });
      // 延迟后自动重试
      Future.delayed(Duration(seconds: 3), _loadRecentChats);
    }
  }

  // 选择好友
  void _selectFriend(int idx) {
    setState(() {
      _selectedFriendIdx = idx;
      // 查找该好友是否在聊天列表中
      final friendId = _friends[idx]['friend_id'];
      final chatIdx = _recentChats.indexWhere((chat) => chat['target_id'] == friendId);

      if (chatIdx != -1) {
        // 如果在聊天列表中，选中该聊天
        _selectedChatIdx = chatIdx;
        _loadMessages(chatIdx);
      } else {
        // 如果不在聊天列表中，清空消息列表
        _selectedChatIdx = null;
        _messages = [];
      }
    });
  }

  // 选择聊天
  Future<void> _selectChat(int idx) async {
    // 获取当前选中的聊天ID和新选中的聊天ID
    final currentChatId = _selectedChatIdx != null ? _recentChats[_selectedChatIdx!]['target_id'] : null;
    final newChatId = _recentChats[idx]['target_id'];

    // 如果切换到不同的聊天，先清除本地消息缓存
    if (currentChatId != null && currentChatId != newChatId) {
      debugPrint('[ThreePanelChatPage] 切换聊天: 从 $currentChatId 到 $newChatId');

      // 清除内存中的消息
      setState(() {
        _messages = [];
      });
    }

    setState(() {
      _selectedChatIdx = idx;
      _loadingMessages = true;
      _messagesError = '';
    });

    await _loadMessages(idx);

    // 查找该聊天对应的好友
    final chatTargetId = _recentChats[idx]['target_id'];
    final friendIdx = _friends.indexWhere((friend) => friend['friend_id'] == chatTargetId);

    if (friendIdx != -1) {
      setState(() {
        _selectedFriendIdx = friendIdx;
      });
    }
  }

  // 加载消息
  Future<void> _loadMessages(int chatIdx) async {
    try {
      final chatId = _recentChats[chatIdx]['target_id'];
      final fetchedMessages = await ChatService.fetchMessages(chatId);
      setState(() {
        _messages = fetchedMessages;
        _loadingMessages = false;
      });
    } catch (e) {
      setState(() {
        _messagesError = '获取消息失败: $e';
        _loadingMessages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取消息失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 发送文本消息
  Future<void> _sendText(String text) async {
    if (_selectedChatIdx == null) return;

    final chatId = _recentChats[_selectedChatIdx!]['target_id'];
    final userId = Persistence.getUserInfo()?.id ?? 0;

    // 先添加一条本地消息，提高响应速度
    setState(() {
      _messages = List<Map<String, dynamic>>.from(_messages)
        ..add({
          "from_id": userId,
          "to_id": chatId,
          "content": text,
          "type": "text",
          "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
          "status": 0, // 发送中
        });
    });

    try {
      final success = await ChatService.sendMessage(chatId, text);

      if (success) {
        // 刷新消息列表
        _loadMessages(_selectedChatIdx!);
        // 刷新聊天列表
        _loadRecentChats();
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

  // 显示添加好友对话框
  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddFriendDialog(
        onAdd: (friendData) {
          // 刷新好友列表
          _loadFriends();
          // 显示成功消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已发送好友请求'), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  // 开始与好友聊天
  void _startChatWithFriend(Map<String, dynamic> friend) {
    if (_selectedFriendIdx == null) return;

    final friendId = friend['friend_id'];
    // 查找是否已有聊天
    final chatIdx = _recentChats.indexWhere((chat) => chat['target_id'] == friendId);

    if (chatIdx != -1) {
      // 如果已有聊天，选中该聊天
      _selectChat(chatIdx);
    } else {
      // 如果没有聊天，创建一个新的聊天
      setState(() {
        _selectedChatIdx = null;
        _messages = [];
        _messagesError = '';
      });

      // 发送一条初始消息来创建聊天
      _sendText('你好！');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Row(
      children: [
        // 左侧：聊天列表
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: theme.isDark ? Color(0xFF2D2D2D) : Colors.white,
            border: Border(
              right: BorderSide(
                color: theme.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // 聊天列表标题和搜索框
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.isDark ? Color(0xFF2D2D2D) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // 标题和刷新按钮
                    Row(
                      children: [
                        Text(
                          '消息',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: theme.primaryColor,
                          ),
                          tooltip: '刷新',
                          onPressed: _loadRecentChats,
                          iconSize: 20,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.person_add,
                            color: theme.primaryColor,
                          ),
                          tooltip: '添加好友',
                          onPressed: _showAddFriendDialog,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // 搜索框
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索聊天',
                          hintStyle: TextStyle(
                            color: theme.isDark ? Colors.grey[400] : Colors.grey[500],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.isDark ? Colors.grey[400] : Colors.grey[500],
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 聊天列表
              Expanded(
                child: _loadingChats
                    ? Center(child: CircularProgressIndicator())
                    : _chatsError.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_chatsError, style: TextStyle(color: Colors.red)),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadRecentChats,
                                  child: Text('重试'),
                                ),
                              ],
                            ),
                          )
                        : _recentChats.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('暂无聊天', style: TextStyle(color: Colors.grey)),
                                    SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      icon: Icon(Icons.person_add),
                                      label: Text('添加好友开始聊天'),
                                      onPressed: _showAddFriendDialog,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _recentChats.length,
                                itemBuilder: (context, index) {
                                  final chat = _recentChats[index];
                                  final isSelected = _selectedChatIdx == index;

                                  return TelegramStyleChatListItem(
                                    chat: chat,
                                    isSelected: isSelected,
                                    onTap: () => _selectChat(index),
                                    onLongPress: () {
                                      // 长按操作，可以添加更多功能
                                    },
                                    onDelete: () async {
                                      // 删除聊天记录
                                      final userInfo = Persistence.getUserInfo();
                                      if (userInfo == null) return;

                                      final userId = userInfo.id;
                                      final targetId = chat['target_id'];

                                      // 清除本地消息
                                      final success = await LocalMessageStorage.clearMessages(userId, targetId);

                                      if (success) {
                                        // 刷新聊天列表
                                        _loadRecentChats();

                                        // 如果当前选中的是被删除的聊天，清空消息列表
                                        if (_selectedChatIdx == index) {
                                          setState(() {
                                            _messages = [];
                                            _messagesError = '';
                                          });
                                        }

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('聊天记录已删除'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('删除聊天记录失败'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),



        // 右侧：聊天内容
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              // 使用渐变背景，类似QQ的聊天背景
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.primaryColor.withOpacity(0.05),
                  theme.backgroundColor,
                ],
              ),
            ),
            child: _selectedChatIdx == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: theme.isDark ? Colors.grey[700] : Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          '选择一个聊天开始会话',
                          style: TextStyle(
                            color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _loadingMessages
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                            ),
                            SizedBox(height: 16),
                            Text(
                              '加载消息中...',
                              style: TextStyle(
                                color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _messagesError.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red[300],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  _messagesError,
                                  style: TextStyle(color: Colors.red[300]),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.refresh),
                                  label: Text('重试'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () => _loadMessages(_selectedChatIdx!),
                                ),
                              ],
                            ),
                          )
                        : ChatDetail(
                            chat: _recentChats[_selectedChatIdx!],
                            messages: _messages,
                            onSendText: _sendText,
                            onSendImage: (image, path) {
                              // TODO: 实现发送图片功能
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('发送图片功能开发中')),
                              );
                            },
                            onSendEmoji: (emoji) {
                              // TODO: 实现发送表情功能
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('发送表情功能开发中')),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }
}
