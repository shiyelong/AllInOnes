import 'package:flutter/material.dart';
import '../miniapp/miniapp_panel.dart';
import 'qr_scan_placeholder.dart';

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // 假数据：最近聊天好友
  final List<Map<String, String>> friends = [
    {"name": "小明", "avatar": "明"},
    {"name": "小红", "avatar": "红"},
    {"name": "小刚", "avatar": "刚"},
    {"name": "小美", "avatar": "美"},
  ];
  int? selectedFriendIdx;

  bool get isMobile => MediaQuery.of(context).size.width < 600;

  // 下拉相关
  double _pullDownDistance = 0;
  final double _pullDownThreshold = 70;
  bool _showingMiniApp = false;

  void _showMiniAppPanel() {
    if (_showingMiniApp) return;
    _showingMiniApp = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MiniAppPanel(onClose: () => Navigator.of(context).pop()),
    ).whenComplete(() => _showingMiniApp = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      // 移动端：聊天页带扫一扫按钮 + 下拉呼出小程序
      return Scaffold(
        appBar: AppBar(
          title: Text('聊天'),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.add),
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
                          // TODO: 可在此处处理加好友/登录等逻辑
                        },
                      ),
                    ),
                  );
                } else if (value == 'add_friend') {
                  // TODO: 跳转到加好友页面
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('加好友功能开发中'), backgroundColor: Colors.blue),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'scan',
                  child: Row(
                    children: [Icon(Icons.qr_code_scanner, color: Colors.blueAccent), SizedBox(width: 8), Text('扫一扫')],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_friend',
                  child: Row(
                    children: [Icon(Icons.person_add_alt_1, color: Colors.green), SizedBox(width: 8), Text('加好友')],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is OverscrollNotification && notification.overscroll < 0) {
              _pullDownDistance -= notification.overscroll;
              if (_pullDownDistance > _pullDownThreshold) {
                _pullDownDistance = 0;
                _showMiniAppPanel();
              }
            } else if (notification is ScrollEndNotification || notification is ScrollUpdateNotification) {
              _pullDownDistance = 0;
            }
            return false;
          },
          child: Navigator(
            onGenerateRoute: (settings) {
              if (settings.name == '/chat') {
                final idx = settings.arguments as int;
                return MaterialPageRoute(
                  builder: (_) => _ChatDetailPage(friend: friends[idx]),
                );
              }
              // 聊天列表页
              return MaterialPageRoute(
                builder: (_) => ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (ctx, idx) => ListTile(
                    leading: CircleAvatar(child: Text(friends[idx]["avatar"]!)),
                    title: Text(friends[idx]["name"]!),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(ctx).pushNamed('/chat', arguments: idx),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      // 桌面/平板端：左侧好友，右侧消息
      return Row(
        children: [
          Container(
            width: 260,
            color: Colors.grey[100],
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (ctx, idx) => ListTile(
                selected: selectedFriendIdx == idx,
                leading: CircleAvatar(child: Text(friends[idx]["avatar"]!)),
                title: Text(friends[idx]["name"]!),
                onTap: () => setState(() => selectedFriendIdx = idx),
              ),
            ),
          ),
          VerticalDivider(width: 1),
          Expanded(
            child: selectedFriendIdx == null
                ? Center(child: Text('请选择聊天好友'))
                : _ChatDetailPage(friend: friends[selectedFriendIdx!]),
          ),
        ],
      );
    }
  }
}

class _ChatDetailPage extends StatelessWidget {
  final Map<String, String> friend;
  const _ChatDetailPage({required this.friend});

  @override
  Widget build(BuildContext context) {
    // 这里可替换为 SingleChatPage 等实际聊天内容组件
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(child: Text(friend["avatar"]!)),
              SizedBox(width: 12),
              Text(friend["name"]!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: Center(child: Text('与 ${friend["name"]} 的聊天内容（可集成消息列表）')),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '输入消息',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.blue,
                child: Icon(Icons.send, color: Colors.white),
              )
            ],
          ),
        ),
      ],
    );
  }
}

