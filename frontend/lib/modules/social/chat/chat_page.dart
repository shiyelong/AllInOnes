import 'package:flutter/material.dart';

import 'qr_scan_placeholder.dart';
import 'chat_detail.dart';
import 'add_friend_dialog.dart';
import 'chat_service.dart';
import 'chat_detail_page.dart';
import 'two_panel_chat_page.dart';
import '../../../common/persistence.dart';
import '../../../common/text_sanitizer.dart';

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
    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      final chats = await ChatService.fetchRecentChats(userId);
      setState(() {
        recentChats = chats;
        loading = false;
      });
    } catch (e) {
      print('获取聊天列表失败: $e');
      setState(() {
        loading = false;
      });
    }
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

  Future<void> _selectChat(int idx) async {
    setState(() {
      selectedChatIdx = idx;
      messages = <Map<String, dynamic>>[];
    });

    try {
      final chatId = recentChats[idx]['target_id'];
      final fetchedMessages = await ChatService.fetchMessages(chatId);
      setState(() {
        messages = fetchedMessages;
      });
    } catch (e) {
      print('获取消息失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取消息失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendText(String text) async {
    if (selectedChatIdx == null) return;

    final chatId = recentChats[selectedChatIdx!]['target_id'];
    final userId = Persistence.getUserInfo()?.id ?? 0;

    // 先添加一条本地消息，提高响应速度
    setState(() {
      messages = List<Map<String, dynamic>>.from(messages)
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
        _selectChat(selectedChatIdx!);
      } else {
        // 更新消息状态为发送失败
        setState(() {
          final index = messages.indexWhere((msg) =>
            msg['from_id'] == userId &&
            msg['content'] == text &&
            msg['status'] == 0
          );

          if (index != -1) {
            messages[index]['status'] = 2; // 发送失败
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
                        leading: CircleAvatar(
                          child: Text(
                            TextSanitizer.sanitize(chat['target_name'] ?? '?').isNotEmpty ?
                              TextSanitizer.sanitize(chat['target_name'] ?? '?')[0] : '?'
                          )
                        ),
                        title: Text(TextSanitizer.sanitize(chat['target_name'] ?? '')),
                        subtitle: Text(TextSanitizer.sanitize(chat['last_message'] ?? '')),
                        trailing: chat['unread_count'] != null && chat['unread_count'] > 0 ? CircleAvatar(radius: 10, child: Text('${chat['unread_count']}')) : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailPage(
                                userId: Persistence.getUserInfo()?.id.toString() ?? '',
                                targetId: chat['target_id'].toString(),
                                targetName: TextSanitizer.sanitize(chat['target_name'] ?? '好友'),
                                targetAvatar: chat['target_avatar'] ?? '',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )),
      );
    } else {
      // 桌面/平板端：使用二栏式布局
      return TwoPanelChatPage();
    }
  }
}
