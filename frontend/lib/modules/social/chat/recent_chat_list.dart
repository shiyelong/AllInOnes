import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecentChatListPage extends StatefulWidget {
  final int userId;
  const RecentChatListPage({Key? key, required this.userId}) : super(key: key);
  @override
  State<RecentChatListPage> createState() => _RecentChatListPageState();
}

class _RecentChatListPageState extends State<RecentChatListPage> {
  List recentChats = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchRecentChats();
  }

  Future<void> fetchRecentChats() async {
    final resp = await http.get(Uri.parse('http://localhost:3001/chat/recent?user_id=${widget.userId}'));
    final data = jsonDecode(resp.body);
    if (data['success']) {
      setState(() {
        recentChats = data['data'];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    if (recentChats.isEmpty) return Center(child: Text('暂无最近聊天'));
    return ListView.builder(
      itemCount: recentChats.length,
      itemBuilder: (context, idx) {
        final chat = recentChats[idx];
        return ListTile(
          leading: CircleAvatar(child: Text(chat['peer_name']?[0] ?? '?')),
          title: Text(chat['peer_name'] ?? ''),
          subtitle: Text(chat['last_message'] ?? ''),
          trailing: chat['unread_count'] > 0 ? CircleAvatar(radius: 10, child: Text('${chat['unread_count']}')) : null,
          onTap: () {/* 跳转到聊天详情 */},
        );
      },
    );
  }
}
