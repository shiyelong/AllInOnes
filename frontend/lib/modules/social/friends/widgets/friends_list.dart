import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../friend_list/friend_block_service.dart';
import '../../chat/chat_detail_page.dart';
import '../../../../common/persistence.dart';
import '../../../../common/theme_manager.dart';

class FriendsList extends StatefulWidget {
  final Function(Map<String, dynamic>)? onFriendSelected;

  const FriendsList({
    super.key,
    this.onFriendSelected,
  });

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  List _friends = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:3001/friend/list?user_id=$userId'));
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        setState(() => _friends = data['data']);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _block(String friendId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    final ok = await FriendBlockService.blockFriend(userId: userId, friendId: friendId);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已屏蔽')));
      _fetchFriends();
    }
  }

  Future<void> _unblock(String friendId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    final ok = await FriendBlockService.unblockFriend(userId: userId, friendId: friendId);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已取消屏蔽')));
      _fetchFriends();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchFriends,
            child: _friends.isEmpty
                ? const Center(child: Text('暂无好友'))
                : ListView.separated(
                    itemCount: _friends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final f = _friends[i];
                      final isBlocked = f['blocked'] == 1;
                      return ListTile(
                        leading: Icon(isBlocked ? Icons.block : Icons.person,
                            color: isBlocked ? Colors.red : null),
                        title: Text('用户ID: ${f['friend_id']}',
                            style: TextStyle(
                              color: isBlocked ? Colors.grey : null,
                              decoration: isBlocked ? TextDecoration.lineThrough : null,
                            )),
                        subtitle: Text('添加时间: ${DateTime.fromMillisecondsSinceEpoch((f['created_at']??0)*1000)}'),
                        enabled: !isBlocked,
                        onTap: isBlocked
                            ? () => ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已屏蔽，无法聊天')),
                                )
                            : () {
                                final userInfo = Persistence.getUserInfo();
                                if (userInfo == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('用户信息不存在，请重新登录')),
                                  );
                                  return;
                                }

                                // 创建好友信息对象
                                final friend = {
                                  'id': f['friend_id'],
                                  'nickname': f['nickname'] ?? '好友${f['friend_id']}',
                                  'avatar': f['avatar'] ?? '',
                                };

                                // 检查是否是桌面平台
                                final isDesktop = ThemeManager.instance.isDesktop;

                                if (isDesktop && widget.onFriendSelected != null) {
                                  // 在桌面平台上，使用回调通知父组件更新聊天面板
                                  widget.onFriendSelected!(friend);
                                } else {
                                  // 在移动平台上，导航到聊天详情页
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatDetailPage(
                                        userId: userInfo.id.toString(),
                                        targetId: friend['id'].toString(),
                                        targetName: friend['nickname'],
                                        targetAvatar: friend['avatar'],
                                      ),
                                    ),
                                  );
                                }
                              },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'block') _block(f['friend_id'].toString());
                            if (v == 'unblock') _unblock(f['friend_id'].toString());
                          },
                          itemBuilder: (_) => [
                            if (!isBlocked)
                              const PopupMenuItem(value: 'block', child: Text('屏蔽')),
                            if (isBlocked)
                              const PopupMenuItem(value: 'unblock', child: Text('取消屏蔽')),
                          ],
                        ),
                      );
                    },
                  ),
          );
  }
}
