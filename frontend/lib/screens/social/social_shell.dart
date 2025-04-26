import 'package:flutter/material.dart';
import '../../widgets/social_nav_rail.dart';
import '../../modules/social/chat/chat_page.dart';
import '../../modules/social/moments/moments_page.dart';
import '../../modules/social/square/square_page.dart';
import '../../modules/social/friends/friends_page.dart';
import '../../modules/social/miniapp/miniapp_page.dart';
import '../../modules/social/shop/shop_page.dart';
import '../../modules/social/game/game_page.dart';
import '../../modules/social/ai/ai_page.dart';
import '../../modules/social/profile/profile_page.dart';

/// 登录后主壳页面
class SocialShell extends StatefulWidget {
  @override
  State<SocialShell> createState() => _SocialShellState();
}

class _SocialShellState extends State<SocialShell> {
  int _selectedIndex = 0;
  final List<String> _navTitles = [
    '聊天', '朋友圈', '广场', '好友', '小程序', '购物', '游戏', 'AI', '我的'
  ];
  final List<IconData> _navIcons = [
    Icons.chat_bubble_outline, Icons.camera, Icons.forum, Icons.people, Icons.apps, Icons.shopping_cart, Icons.videogame_asset, Icons.smart_toy, Icons.person
  ];
  final List<Widget> _pages = [
    ChatPage(), MomentsPage(), SquarePage(), FriendsPage(), MiniAppPage(), ShopPage(), GamePage(), AiPage(), ProfilePage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Telegram风格侧边栏
          Container(
            width: 260,
            color: Colors.blueGrey[900],
            child: Column(
              children: [
                SizedBox(height: 40),
                CircleAvatar(radius: 32, backgroundColor: Colors.blue, child: Text('ALL', style: TextStyle(fontSize: 22, color: Colors.white))),
                SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: _navTitles.length,
                    itemBuilder: (context, idx) => ListTile(
                      leading: Icon(_navIcons[idx], color: _selectedIndex == idx ? Colors.blue : Colors.white),
                      title: Text(_navTitles[idx], style: TextStyle(color: _selectedIndex == idx ? Colors.blue : Colors.white)),
                      selected: _selectedIndex == idx,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () => setState(() => _selectedIndex = idx),
                    ),
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
          // 主内容区（含Twitter风格顶部栏）
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Text("ALL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                      Spacer(),
                      Icon(Icons.search, color: Colors.blueGrey[800]),
                      SizedBox(width: 16),
                      CircleAvatar(radius: 18, backgroundColor: Colors.grey[300]),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.grey[50],
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
