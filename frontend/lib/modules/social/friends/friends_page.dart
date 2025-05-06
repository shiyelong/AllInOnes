import 'package:flutter/material.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/text_sanitizer.dart';
import '../../../widgets/app_avatar.dart';
import '../chat/chat_detail_page.dart';
import '../chat/two_panel_chat_page.dart';
import '../chat/friend_requests_page.dart';
import '../chat/add_friend_dialog.dart';
import 'widgets/friends_list.dart';
import 'widgets/friend_request_header.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List _friends = [];
  bool _loading = true;
  String _error = '';

  // 好友请求数量
  int _friendRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadFriendRequestCount();
  }

  Future<void> _loadFriends() async {
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

      final response = await Api.getFriendList();

      if (response['success'] == true) {
        setState(() {
          _friends = response['data'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = response['msg'] ?? '加载好友列表失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载好友列表出错: $e';
        _loading = false;
      });
    }
  }

  // 加载好友请求数量
  Future<void> _loadFriendRequestCount() async {
    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        return;
      }

      final response = await Api.getFriendRequests(
        userId: userId.toString(),
        type: 'received',
        status: 'pending',
      );

      if (response['success'] == true && mounted) {
        setState(() {
          // 确保data是List类型
          if (response['data'] is List) {
            _friendRequestCount = (response['data'] as List).length;
          } else {
            _friendRequestCount = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('加载好友请求数量失败: $e');
    }
  }

  void _navigateToChat(Map<String, dynamic> friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          userId: Persistence.getUserInfo()?.id.toString() ?? '',
          targetId: friend['friend_id'].toString(),
          targetName: TextSanitizer.sanitize(friend['nickname'] ?? '好友${friend['friend_id']}'),
          targetAvatar: friend['avatar'] ?? '',
        ),
      ),
    );
  }

  // 当前选中的好友
  Map<String, dynamic>? _selectedFriend;

  @override
  Widget build(BuildContext context) {
    // 检查是否是桌面平台
    final isDesktop = ThemeManager.instance.isDesktop;

    // 如果是桌面平台，使用两面板布局
    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      // 移动平台使用单面板布局
      return _buildMobileLayout();
    }
  }

  // 桌面平台的两面板布局
  Widget _buildDesktopLayout() {
    // 如果有选中的好友，显示两面板聊天界面
    if (_selectedFriend != null) {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        return Center(child: Text('用户信息不存在，请重新登录'));
      }

      return TwoPanelChatPage(
        userId: userInfo.id.toString(),
        targetId: _selectedFriend!['id'].toString(),
        targetName: TextSanitizer.sanitize(_selectedFriend!['nickname'] ?? '好友'),
        targetAvatar: _selectedFriend!['avatar'] ?? '',
        onBackPressed: () {
          setState(() {
            _selectedFriend = null;
          });
        },
      );
    }

    // 否则显示好友列表
    return _buildFriendsList(
      onFriendSelected: (friend) {
        setState(() {
          _selectedFriend = friend;
        });
      },
    );
  }

  // 移动平台的单面板布局
  Widget _buildMobileLayout() {
    return _buildFriendsList();
  }

  // 性别图标
  Widget _buildGenderIcon(String? gender) {
    IconData icon;
    Color color;

    switch (gender) {
      case '男':
        icon = Icons.male;
        color = Colors.blue;
        break;
      case '女':
        icon = Icons.female;
        color = Colors.pink;
        break;
      case '未知':
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  // 构建好友列表
  Widget _buildFriendsList({Function(Map<String, dynamic>)? onFriendSelected}) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFriends,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return Scaffold(
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 好友请求浮动按钮（仅当有请求时显示）
            if (_friendRequestCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FriendRequestsPage(
                          onRequestProcessed: () {
                            // 刷新好友请求数量
                            _loadFriendRequestCount();
                          },
                        ),
                      ),
                    );
                  },
                  heroTag: 'friendRequests',
                  backgroundColor: Colors.red,
                  mini: true,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_active, color: Colors.white),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Center(
                            child: Text(
                              _friendRequestCount > 9 ? '9+' : _friendRequestCount.toString(),
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  tooltip: '处理好友请求',
                ),
              ),
            // 添加好友按钮
            FloatingActionButton(
              onPressed: () {
                // 显示添加好友对话框
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
              },
              heroTag: 'addFriend',
              child: Icon(Icons.person_add),
              tooltip: '添加好友',
            ),
          ],
        ),
        body: Column(
          children: [
            // 好友请求头部（仅当有请求时显示）
            if (_friendRequestCount > 0)
              FriendRequestHeader(
                requestCount: _friendRequestCount,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FriendRequestsPage(
                        onRequestProcessed: () {
                          // 刷新好友请求数量
                          _loadFriendRequestCount();
                        },
                      ),
                    ),
                  );
                },
              ),
            // 空状态提示
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('暂无好友', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.person_add),
                      label: Text('添加好友'),
                      onPressed: () {
                        // 显示添加好友对话框
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
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 好友请求浮动按钮（仅当有请求时显示）
          if (_friendRequestCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FriendRequestsPage(
                        onRequestProcessed: () {
                          // 刷新好友请求数量
                          _loadFriendRequestCount();
                        },
                      ),
                    ),
                  );
                },
                heroTag: 'friendRequests',
                backgroundColor: Colors.red,
                mini: true,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_active, color: Colors.white),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Center(
                          child: Text(
                            _friendRequestCount > 9 ? '9+' : _friendRequestCount.toString(),
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: '处理好友请求',
              ),
            ),
          // 添加好友按钮
          FloatingActionButton(
            onPressed: () {
              // 显示添加好友对话框
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
            },
            heroTag: 'addFriend',
            child: Icon(Icons.person_add),
            tooltip: '添加好友',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadFriends();
          await _loadFriendRequestCount();
        },
        child: ListView.builder(
        itemCount: _friends.length + 1, // +1 是为了添加好友请求头部
        itemBuilder: (context, index) {
          // 第一项是好友请求头部
          if (index == 0) {
            return FriendRequestHeader(
              requestCount: _friendRequestCount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FriendRequestsPage(
                      onRequestProcessed: () {
                        // 刷新好友请求数量
                        _loadFriendRequestCount();
                      },
                    ),
                  ),
                );
              },
            );
          }

          // 调整索引，因为第一项是好友请求头部
          final friendIndex = index - 1;
          final friend = _friends[friendIndex];
          final isBlocked = friend['blocked'] == 1;

          // 创建好友信息对象
          final friendData = {
            'id': friend['friend_id'],
            'nickname': TextSanitizer.sanitize(friend['nickname'] ?? '好友${friend['friend_id']}'),
            'avatar': friend['avatar'] ?? '',
          };

          return Column(
            children: [
              // 在第一个好友项前添加分隔线
              if (friendIndex == 0) Divider(height: 1),

              ListTile(
                leading: AppAvatar(
                  name: friendData['nickname'],
                  size: 40,
                  imageUrl: friendData['avatar'],
                ),
                title: Row(
                  children: [
                    Text(
                      friendData['nickname'],
                      style: TextStyle(
                        color: isBlocked ? Colors.grey : null,
                        decoration: isBlocked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    SizedBox(width: 4),
                    _buildGenderIcon(friend['gender']),
                  ],
                ),
                subtitle: Text(
                  '账号: ${friend['account'] ?? friend['friend_id']}',
                  style: TextStyle(
                    color: isBlocked ? Colors.grey : AppTheme.textSecondaryColor,
                  ),
                ),
                enabled: !isBlocked,
                onTap: isBlocked
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('该好友已被屏蔽，无法聊天')),
                    )
                  : () {
                      if (onFriendSelected != null) {
                        // 使用回调通知父组件
                        onFriendSelected(friendData);
                      } else {
                        // 导航到聊天详情页
                        _navigateToChat(friend);
                      }
                    },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'block') {
                      // 屏蔽好友
                      final userId = Persistence.getUserInfo()?.id.toString() ?? '';
                      final response = await Api.blockFriend(
                        userId: userId,
                        friendId: friend['friend_id'].toString(),
                      );

                      if (response['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已屏蔽该好友')),
                        );
                        _loadFriends();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(response['msg'] ?? '操作失败')),
                        );
                      }
                    } else if (value == 'unblock') {
                      // 取消屏蔽
                      final userId = Persistence.getUserInfo()?.id.toString() ?? '';
                      final response = await Api.unblockFriend(
                        userId: userId,
                        friendId: friend['friend_id'].toString(),
                      );

                      if (response['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已取消屏蔽该好友')),
                        );
                        _loadFriends();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(response['msg'] ?? '操作失败')),
                        );
                      }
                    } else if (value == 'delete') {
                      // TODO: 实现删除好友功能
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('删除好友功能开发中')),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isBlocked)
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red),
                            SizedBox(width: 8),
                            Text('屏蔽'),
                          ],
                        ),
                      ),
                    if (isBlocked)
                      PopupMenuItem(
                        value: 'unblock',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('取消屏蔽'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除好友'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 在每个好友项后添加分隔线
              Divider(height: 1),
            ],
          );
        },
      ),
      ),
    );
  }
}
