import 'package:flutter/material.dart';
import 'profile/profile_page.dart';
import 'chat/chat_page.dart';
import 'moments/moments_page.dart';
import 'friends/friends_page.dart';

/// 社交主界面（包含左侧导航栏和主内容区）
class SocialMainPage extends StatefulWidget {
  const SocialMainPage({super.key});

  @override
  State<SocialMainPage> createState() => _SocialMainPageState();
}

class _SocialMainPageState extends State<SocialMainPage> {
  int mainTabIndex = 0;
  int subTabIndex = 0;

  // 主模块标签和图标（顺序决定顶部Tab顺序）
  final List<String> mainTabs = [
    '社交', '游戏', '广场', '购物', 'AI', '外卖'
  ];
  final List<IconData> mainIcons = [
    Icons.chat_bubble_outline,
    Icons.sports_esports_outlined,
    Icons.public,
    Icons.shopping_cart_outlined,
    Icons.smart_toy_outlined,
    Icons.delivery_dining,
  ];
  // 每个主模块的子导航（顺序与 mainTabs 对应）
  final List<List<Map<String, dynamic>>> subTabs = [
    [ // 社交
      {'icon': Icons.chat_bubble_outline, 'label': '聊天'},
      {'icon': Icons.photo_album_outlined, 'label': '朋友圈'},
      {'icon': Icons.people_outline, 'label': '好友'},
    ],
    [ // 游戏
      {'icon': Icons.sports_esports_outlined, 'label': '大厅'},
      {'icon': Icons.emoji_events_outlined, 'label': '排行'},
    ],
    [ // 广场
      {'icon': Icons.forum_outlined, 'label': '帖子'},
      {'icon': Icons.star_border, 'label': '达人'},
    ],
    [ // 购物
      {'icon': Icons.shopping_bag_outlined, 'label': '商城'},
      {'icon': Icons.list_alt_outlined, 'label': '订单'},
      {'icon': Icons.favorite_border, 'label': '收藏'},
    ],
    [ // AI
      {'icon': Icons.smart_toy_outlined, 'label': 'AI助手'},
      {'icon': Icons.settings_suggest_outlined, 'label': 'AI设置'},
    ],
    [ // 外卖
      {'icon': Icons.delivery_dining, 'label': '点餐'},
      {'icon': Icons.receipt_long, 'label': '订单'},
    ],
  ];

  Widget buildDesktop() {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: Material(
          color: Colors.white,
          elevation: 2,
          child: Row(
            children: [
              ...List.generate(mainTabs.length, (i) => InkWell(
                onTap: () => setState(() { mainTabIndex = i; subTabIndex = 0; }),
                child: Container(
                  height: 56,
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: mainTabIndex == i ? Colors.blueAccent : Colors.transparent,
                        width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(mainIcons[i], color: mainTabIndex == i ? Colors.blueAccent : Colors.grey),
                      SizedBox(width: 6),
                      Text(mainTabs[i], style: TextStyle(fontWeight: mainTabIndex == i ? FontWeight.bold : FontWeight.normal, color: mainTabIndex == i ? Colors.blueAccent : Colors.grey)),
                    ],
                  ),
                ),
              )),
              Spacer(),
              // 可放全局搜索、通知等
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          // 左侧子导航
          Container(
            width: 80,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            child: Column(
              children: [
                SizedBox(height: 20),
                ...List.generate(subTabs[mainTabIndex].length, (i) => GestureDetector(
                  onTap: () => setState(() => subTabIndex = i),
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: subTabIndex == i ? Colors.blueAccent.withOpacity(0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Icon(subTabs[mainTabIndex][i]['icon'], color: subTabIndex == i ? Colors.blueAccent : Colors.grey),
                        SizedBox(height: 2),
                        Text(subTabs[mainTabIndex][i]['label'], style: TextStyle(fontSize: 10, color: subTabIndex == i ? Colors.blueAccent : Colors.grey)),
                      ],
                    ),
                  ),
                )),
                Spacer(),
                // “我的”按钮固定左下
                GestureDetector(
                  onTap: () {/* TODO: 头像切换/个人中心 */},
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        CircleAvatar(radius: 22, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                        SizedBox(height: 6),
                        Text('我的', style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 主内容区
          Expanded(
            child: Center(
              child: Text('${mainTabs[mainTabIndex]} - ${subTabs[mainTabIndex][subTabIndex]['label']}模块'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMobile() {
    // 移动端主导航悬浮左侧，底部为子导航栏，“我的”固定底部右侧，支持隐藏
    bool navOpen = true;
    return StatefulBuilder(
      builder: (context, setStateSB) {
        return Scaffold(
          body: Stack(
            children: [
              // 主内容区
              Positioned.fill(
                child: Center(
                  child: Text('${mainTabs[mainTabIndex]} - ${subTabs[mainTabIndex][subTabIndex]['label']}模块'),
                ),
              ),
              // 悬浮主导航（可隐藏/展开）
              AnimatedPositioned(
                duration: Duration(milliseconds: 260),
                curve: Curves.ease,
                top: MediaQuery.of(context).size.height * 0.18,
                left: navOpen ? 0 : -64,
                child: MouseRegion(
                  child: Material(
                    color: Colors.white.withOpacity(0.95),
                    elevation: 2,
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
                    child: Container(
                      width: 56,
                      height: MediaQuery.of(context).size.height * 0.64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(mainTabs.length, (i) => IconButton(
                            icon: Icon(mainIcons[i], color: mainTabIndex == i ? Colors.blueAccent : Colors.grey),
                            onPressed: () => setState(() { mainTabIndex = i; subTabIndex = 0; }),
                          )),
                          Spacer(),
                          // 折叠按钮
                          IconButton(
                            icon: Icon(navOpen ? Icons.chevron_left : Icons.chevron_right, size: 20),
                            onPressed: () => setStateSB(() => navOpen = !navOpen),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // 侧栏隐藏时显示呼出按钮
            if (!navOpen)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.38,
                left: 0,
                child: GestureDetector(
                  onTap: () => setStateSB(() => navOpen = true),
                  child: Material(
                    color: Colors.blueAccent,
                    elevation: 2,
                    shape: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.chevron_right, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: BottomAppBar(
            color: Colors.white,
              child: Row(
                children: [
                  ...List.generate(subTabs[mainTabIndex].length, (i) => Expanded(
                    child: InkWell(
                      onTap: () => setState(() => subTabIndex = i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(subTabs[mainTabIndex][i]['icon'], color: subTabIndex == i ? Colors.blueAccent : Colors.grey),
                            SizedBox(height: 2),
                            Text(subTabs[mainTabIndex][i]['label'], style: TextStyle(fontSize: 10, color: subTabIndex == i ? Colors.blueAccent : Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  )),
                  // “我的”按钮固定底部右侧
                  InkWell(
                    onTap: () {/* TODO: 头像切换/个人中心 */},
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 16, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                          SizedBox(height: 2),
                          Text('我的', style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile ? buildMobile() : buildDesktop();
  }
}
