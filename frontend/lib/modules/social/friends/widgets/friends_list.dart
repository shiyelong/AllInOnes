import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../friend_list/friend_block_service.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});
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
                                // TODO: 跳转聊天界面
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
