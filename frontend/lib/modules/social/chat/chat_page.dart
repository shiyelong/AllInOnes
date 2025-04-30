import 'package:flutter/material.dart';

import 'qr_scan_placeholder.dart';
import 'chat_detail.dart';
import 'add_friend_dialog.dart';
import 'chat_service.dart';

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List recentChats = [];
  List<Map<String, dynamic>> messages = [];
  int? selectedChatIdx;
  bool loading = true;
  bool isAddingFriend = false;

  @override
  void initState() {
    super.initState();
    fetchRecentChats();
  }

  Future<void> fetchRecentChats() async {
    // TODO: 替换为实际登录用户ID
    final userId = 1;
    final chats = await ChatService.fetchRecentChats(userId);
    setState(() {
      recentChats = chats;
      loading = false;
    });
  }

  bool get isMobile => MediaQuery.of(context).size.width < 600;

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddFriendDialog(
        onAdd: (friendId) {
          // TODO: 刷新好友/聊天列表
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已发送好友请求: $friendId'), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  void _selectChat(int idx) async {
    setState(() {
      selectedChatIdx = idx;
      messages = <Map<String, dynamic>>[];
    });
    // TODO: 拉取聊天消息
    await Future.delayed(Duration(milliseconds: 200));
    setState(() {
      messages = <Map<String, dynamic>>[
        {"from_me": false, "text": "你好，这是一条历史消息"},
        {"from_me": true, "text": "你好！"},
      ];
    });
  }

  void _sendText(String text) {
    if (selectedChatIdx == null) return;
    setState(() {
      messages = List<Map<String, dynamic>>.from(messages)
        ..add({"from_me": true, "text": text});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      // 移动端：聊天页带扫一扫按钮
      return Scaffold(
        appBar: AppBar(
          title: Text('聊天'),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.add),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'scan', child: Row(children: [Icon(Icons.qr_code_scanner), SizedBox(width: 8), Text('扫一扫')])) ,
                PopupMenuItem(value: 'add_friend', child: Row(children: [Icon(Icons.person_add), SizedBox(width: 8), Text('加好友')])) ,
              ],
              onSelected: (value) {
                if (value == 'scan') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => QrScanPage(
                        onScan: (code) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('扫码结果: $code'), backgroundColor: Colors.green),
                          );
                        },
                      ),
                    ),
                  );
                } else if (value == 'add_friend') {
                  Navigator.pushNamed(context, '/add_friend');
                }
              },
            ),
          ],
        ),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : (recentChats.isEmpty
                ? Center(child: Text('暂无最近聊天'))
                : ListView.builder(
                    itemCount: recentChats.length,
                    itemBuilder: (context, idx) {
                      final chat = recentChats[idx];
                      return ListTile(
                        leading: CircleAvatar(child: Text(chat['peer_name']?[0] ?? '?')),
                        title: Text(chat['peer_name'] ?? ''),
                        subtitle: Text(chat['last_message'] ?? ''),
                        trailing: chat['unread_count'] != null && chat['unread_count'] > 0 ? CircleAvatar(radius: 10, child: Text('${chat['unread_count']}')) : null,
                      );
                    },
                  )),
      );
    } else {
      // 桌面/平板端：左侧最近聊天，右侧消息区（预留）
      return Row(
        children: [
          Container(
            width: 260,
            color: Colors.grey[100],
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.person_add),
                      label: Text('加好友'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _showAddFriendDialog,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: recentChats.length,
                    itemBuilder: (ctx, idx) => ListTile(
                      selected: selectedChatIdx == idx,
                      leading: CircleAvatar(child: Text(recentChats[idx]['peer_name']?[0] ?? '?')),
                      title: Text(recentChats[idx]['peer_name'] ?? ''),
                      subtitle: Text(recentChats[idx]['last_message'] ?? ''),
                      trailing: recentChats[idx]['unread_count'] != null && recentChats[idx]['unread_count'] > 0
                          ? CircleAvatar(radius: 10, child: Text('${recentChats[idx]['unread_count']}'), backgroundColor: Colors.redAccent, foregroundColor: Colors.white)
                          : null,
                      onTap: () => _selectChat(idx),
                    ),
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1),
          Expanded(
            child: selectedChatIdx == null
                ? Center(child: Text('请选择聊天会话', style: TextStyle(color: Colors.grey)))
                : ChatDetail(
                    chat: recentChats[selectedChatIdx!],
                    messages: messages,
                    onSendText: _sendText,
                  ),
          ),
        ],
      );
    }
  }
}
