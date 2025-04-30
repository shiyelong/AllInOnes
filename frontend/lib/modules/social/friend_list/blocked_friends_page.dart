import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'friend_block_service.dart';

/// 已屏蔽好友管理页
class BlockedFriendsPage extends StatefulWidget {
  const BlockedFriendsPage({super.key});
  @override
  State<BlockedFriendsPage> createState() => _BlockedFriendsPageState();
}

class _BlockedFriendsPageState extends State<BlockedFriendsPage> {
  List _blocked = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchBlocked();
  }

  Future<void> _fetchBlocked() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:3001/friend/list?user_id=$userId'));
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        setState(() => _blocked = (data['data'] as List).where((f) => f['blocked'] == 1).toList());
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _unblock(String friendId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    final ok = await FriendBlockService.unblockFriend(userId: userId, friendId: friendId);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已取消屏蔽')));
      _fetchBlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('已屏蔽好友'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked.isEmpty
              ? const Center(child: Text('暂无已屏蔽好友'))
              : ListView.separated(
                  itemCount: _blocked.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = _blocked[i];
                    return ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: Text('用户ID: ${f['friend_id']}'),
                      subtitle: Text('屏蔽时间: ${DateTime.fromMillisecondsSinceEpoch((f['created_at']??0)*1000)}'),
                      trailing: ElevatedButton(
                        onPressed: () => _unblock(f['friend_id'].toString()),
                        child: const Text('取消屏蔽'),
                      ),
                    );
                  },
                ),
    );
  }
}
