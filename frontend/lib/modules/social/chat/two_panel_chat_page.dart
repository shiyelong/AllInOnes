import 'package:flutter/material.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/api.dart';
import '../../../common/search_service.dart';
import '../../../widgets/app_avatar.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/resizable_panel.dart';
import 'add_friend_dialog.dart';
import 'chat_detail.dart';
import 'chat_service.dart';
import 'chat_detail_page.dart';
import 'self_chat_page.dart';
import '../friends/friends_page.dart';
import '../search/search_results_page.dart';

/// 二栏式聊天界面（桌面端）
/// 左侧：最近聊天列表
/// 右侧：聊天内容
class TwoPanelChatPage extends StatefulWidget {
  final String? userId;
  final String? targetId;
  final String? targetName;
  final String? targetAvatar;
  final VoidCallback? onBackPressed;

  const TwoPanelChatPage({
    Key? key,
    this.userId,
    this.targetId,
    this.targetName,
    this.targetAvatar,
    this.onBackPressed,
  }) : super(key: key);

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
    _loadRecentChats().then((_) {
      // 如果提供了目标ID，自动选择对应的聊天
      if (widget.targetId != null && widget.targetId!.isNotEmpty) {
        final targetId = int.tryParse(widget.targetId!);
        if (targetId != null) {
          // 查找该目标是否在聊天列表中
          final chatIdx = _recentChats.indexWhere((chat) => chat['target_id'] == targetId);
          if (chatIdx != -1) {
            // 如果在聊天列表中，选中该聊天
            _selectChat(chatIdx);
          } else {
            // 如果不在聊天列表中，创建一个新的聊天
            // 首先查找该目标是否在好友列表中
            final friendIdx = _friends.indexWhere((friend) => friend['friend_id'] == targetId);
            if (friendIdx != -1) {
              _selectFriend(friendIdx);
            } else {
              // 如果既不在聊天列表也不在好友列表中，创建一个临时聊天
              if (widget.targetName != null && widget.targetName!.isNotEmpty) {
                setState(() {
                  _recentChats.add({
                    'target_id': targetId,
                    'target_name': widget.targetName,
                    'target_avatar': widget.targetAvatar ?? '',
                    'last_message': '',
                    'unread_count': 0,
                    'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  });
                  _selectedChatIdx = _recentChats.length - 1;
                });
              }
            }
          }
        }
      }
    });
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
    setState(() {
      _selectedChatIdx = idx;
      _loadingMessages = true;
      _messagesError = '';
      _messages = [];
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
      final isSelfChat = _recentChats[chatIdx]['is_self'] == true;

      // 无论是自己的设备还是其他聊天，都使用相同的方法获取消息
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

  // 处理返回按钮点击
  void _handleBackPressed() {
    if (widget.onBackPressed != null) {
      widget.onBackPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Row(
      children: [
        // 左侧：聊天列表（可调整大小）
        ResizablePanel(
          key: Key('chat_list_panel'),
          initialWidth: 320,
          minWidth: 240,
          maxWidth: 480,
          child: Container(
            decoration: BoxDecoration(
              color: theme.isDark ? Color(0xFF2D2D2D) : Colors.white,
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
                          // 如果有返回按钮回调，显示返回按钮
                          if (widget.onBackPressed != null)
                            IconButton(
                              icon: Icon(Icons.arrow_back),
                              onPressed: _handleBackPressed,
                              tooltip: '返回',
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          if (widget.onBackPressed != null)
                            SizedBox(width: 8),
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
                      AppSearchBar(
                        searchType: SearchType.chat,
                        onSearch: (keyword) {
                          // 打开搜索结果页面
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchResultsPage(
                                initialKeyword: keyword,
                                searchType: SearchType.chat,
                              ),
                            ),
                          );
                        },
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
                                  final isSelfChat = chat['is_self'] == true;

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: theme.isDark
                                        ? theme.primaryColor.withOpacity(0.15)
                                        : theme.primaryColor.withOpacity(0.1),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: isSelfChat
                                        ? Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? theme.primaryColor
                                                  : theme.primaryColor.withOpacity(0.7),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.devices,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          )
                                        : CircleAvatar(
                                            radius: 20,
                                            backgroundColor: isSelected
                                                ? theme.primaryColor
                                                : theme.isDark
                                                    ? Colors.grey[700]
                                                    : Colors.grey[300],
                                            child: Text(
                                              chat['target_name']?[0] ?? '?',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : theme.isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                    title: Text(
                                      chat['target_name'] ?? '',
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : null,
                                        color: theme.isDark ? Colors.white : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      chat['last_message'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelfChat)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '我的',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        SizedBox(width: 4),
                                        if (chat['unread_count'] != null && chat['unread_count'] > 0)
                                          Container(
                                            padding: EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${chat['unread_count']}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    onTap: () {
                                      // 无论是自己的设备还是其他聊天，都使用相同的处理方式
                                      _selectChat(index);
                                    },
                                  );
                                },
                              ),
                ),
              ],
            ),
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
                            onSendImage: (image, path) async {
                              if (_selectedChatIdx == null) return;

                              final chatId = _recentChats[_selectedChatIdx!]['target_id'];
                              final userId = Persistence.getUserInfo()?.id ?? 0;

                              // 先添加一条本地消息，提高响应速度
                              setState(() {
                                _messages = List<Map<String, dynamic>>.from(_messages)
                                  ..add({
                                    "from_id": userId,
                                    "to_id": chatId,
                                    "content": path, // 临时使用本地路径
                                    "type": "image",
                                    "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                    "status": 0, // 发送中
                                  });
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
                              if (_selectedChatIdx == null) return;

                              final chatId = _recentChats[_selectedChatIdx!]['target_id'];
                              final userId = Persistence.getUserInfo()?.id ?? 0;

                              // 先添加一条本地消息，提高响应速度
                              setState(() {
                                _messages = List<Map<String, dynamic>>.from(_messages)
                                  ..add({
                                    "from_id": userId,
                                    "to_id": chatId,
                                    "content": emoji,
                                    "type": "emoji",
                                    "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                    "status": 0, // 发送中
                                  });
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
                          ),
          ),
        ),
      ],
    );
  }
}
