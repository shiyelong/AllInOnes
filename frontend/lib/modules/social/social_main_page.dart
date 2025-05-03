import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'profile/profile_page.dart';
import 'chat/chat_page.dart';
import 'chat/two_panel_chat_page.dart';
import 'moments/moments_page.dart';
import 'friends/friends_page.dart';
import 'chat/friend_requests_page.dart';
import 'chat/friend_settings_page.dart';
import '../wallet/wallet_page.dart';
import '../../common/theme.dart';
import '../../widgets/app_avatar.dart';
import '../../common/animations.dart';
import '../../common/persistence.dart';
import '../../common/api.dart';
import '../../common/search_service.dart';
import '../../widgets/app_search_bar.dart';
import 'search/search_results_page.dart';
import 'chat/clean_chat_messages.dart';
import '../../tools/clean_chat_messages_tool.dart';
import '../../tools/fix_chat_messages.dart';
import '../../tools/direct_clean_chat.dart';
import '../../tools/clear_all_chat_data.dart';
import '../../tools/reset_all_data.dart';
import '../../tools/simple_clean_chat.dart';

/// 社交主界面（包含左侧导航栏和主内容区）
class SocialMainPage extends StatefulWidget {
  const SocialMainPage({super.key});

  @override
  State<SocialMainPage> createState() => _SocialMainPageState();
}

class _SocialMainPageState extends State<SocialMainPage> {
  int mainTabIndex = 0;
  int subTabIndex = 0;

  // 好友请求数量
  int _friendRequestCount = 0;

  // 用户信息
  UserInfo? _userInfo;

  @override
  void initState() {
    super.initState();
    // 加载好友请求数量
    _loadFriendRequestCount();

    // 获取用户信息
    _loadUserInfo();
  }

  // 加载用户信息
  Future<void> _loadUserInfo() async {
    try {
      // 尝试从API获取最新的用户信息
      final response = await Api.getUserInfo();

      if (response['success'] == true && response['data'] != null) {
        // 保存用户信息到本地
        await Persistence.saveUserInfo(response['data']);

        if (mounted) {
          setState(() {
            _userInfo = UserInfo.fromJson(response['data']);
          });
        }
      } else {
        // 如果API请求失败，尝试从本地获取
        final userInfo = await Persistence.getUserInfoAsync();

        if (mounted) {
          setState(() {
            _userInfo = userInfo;
          });
        }
      }
    } catch (e) {
      debugPrint('[SocialMainPage] 获取用户信息失败: $e');

      // 尝试从本地获取
      final userInfo = await Persistence.getUserInfoAsync();

      if (mounted) {
        setState(() {
          _userInfo = userInfo;
        });
      }
    }
  }

  // 加载好友请求数量
  Future<void> _loadFriendRequestCount() async {
    try {
      // 先尝试从本地获取用户ID
      final userInfo = await Persistence.getUserInfoAsync();
      final userId = userInfo?.id;

      if (userId == null) {
        debugPrint('[SocialMainPage] 无法获取用户ID，无法加载好友请求');
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

            // 如果有新的好友请求，显示通知
            if (_friendRequestCount > 0) {
              // 延迟显示通知，确保界面已经加载完成
              Future.delayed(Duration(seconds: 1), () {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('您有 $_friendRequestCount 个新的好友请求'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 5),
                      action: SnackBarAction(
                        label: '查看',
                        textColor: Colors.white,
                        onPressed: () {
                          // 跳转到好友请求页面
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
                    ),
                  );
                }
              });
            }
          } else {
            _friendRequestCount = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('[SocialMainPage] 加载好友请求数量失败: $e');
    }
  }

  // 根据当前标签获取搜索类型
  SearchType _getSearchTypeForCurrentTab() {
    switch (mainTabIndex) {
      case 0: // 社交
        switch (subTabIndex) {
          case 0: // 聊天
            return SearchType.chat;
          case 2: // 好友
            return SearchType.friend;
          default:
            return SearchType.social;
        }
      case 1: // 游戏
        return SearchType.game;
      case 2: // 广场
        return SearchType.plaza;
      default:
        return SearchType.global;
    }
  }

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
      {'icon': Icons.people_outline, 'label': '好友', 'badge': true},
      {'icon': Icons.settings_outlined, 'label': '好友设置'},
      {'icon': Icons.account_balance_wallet_outlined, 'label': '钱包'},
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
        preferredSize: Size.fromHeight(60),
        child: Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          elevation: 2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]!
                      : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.all_inclusive,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'AllInOne',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 32),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(mainTabs.length, (i) => AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 300 + (i * 100)),
                        child: InkWell(
                          onTap: () => setState(() { mainTabIndex = i; subTabIndex = 0; }),
                          child: Container(
                            height: 60,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: mainTabIndex == i ? AppTheme.primaryColor : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              color: mainTabIndex == i
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.primaryDarkColor.withOpacity(0.1)
                                      : AppTheme.primaryLightColor.withOpacity(0.1))
                                  : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  mainIcons[i],
                                  color: mainTabIndex == i ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  mainTabs[i],
                                  style: TextStyle(
                                    fontWeight: mainTabIndex == i ? FontWeight.bold : FontWeight.normal,
                                    color: mainTabIndex == i ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                    ),
                  ),
                ),
                Spacer(),
                // 搜索框
                Container(
                  margin: EdgeInsets.only(right: 16),
                  child: AppSearchBar(
                    width: 200,
                    searchType: _getSearchTypeForCurrentTab(),
                    onSearch: (keyword) {
                      // 打开搜索结果页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchResultsPage(
                            initialKeyword: keyword,
                            searchType: _getSearchTypeForCurrentTab(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 通知图标
                IconButton(
                  icon: Stack(
                    children: [
                      Icon(Icons.notifications_outlined, color: AppTheme.textSecondaryColor),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('通知功能开发中')),
                    );
                  },
                ),
                // 用户头像
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage()),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    child: AppAvatar(
                      name: _userInfo?.nickname ?? _userInfo?.account ?? '用户',
                      size: 36,
                      imageUrl: _userInfo?.avatar,
                      showBorder: true,
                      borderColor: AppTheme.primaryColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          // 左侧子导航
          Container(
            width: 90,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF1E1E1E)
                  : Colors.white,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]!
                      : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(height: 16),
                // 使用Expanded包裹子导航项列表，使其可滚动
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(subTabs[mainTabIndex].length, (i) => AppAnimations.fadeInScale(
                        duration: Duration(milliseconds: 300 + (i * 100)),
                        child: GestureDetector(
                          onTap: () => setState(() => subTabIndex = i),
                          child: Container(
                            width: 70,
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: subTabIndex == i
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.primaryDarkColor.withOpacity(0.2)
                                      : AppTheme.primaryLightColor.withOpacity(0.2))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Icon(
                                      subTabs[mainTabIndex][i]['icon'],
                                      color: subTabIndex == i ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                                      size: 24,
                                    ),
                                    // 显示好友请求徽章
                                    if (subTabs[mainTabIndex][i]['badge'] == true && _friendRequestCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            _friendRequestCount > 99 ? '99+' : _friendRequestCount.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Text(
                                  subTabs[mainTabIndex][i]['label'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subTabIndex == i ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                                    fontWeight: subTabIndex == i ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                    ),
                  ),
                ),
                // “我的”按钮固定左下
                GestureDetector(
                  onTap: () async {
                    final result = await showModalBottomSheet<String>(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (ctx) => SafeArea(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            Container(
                              width: 40,
                              height: 4,
                              margin: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  AppAvatar(
                                    name: _userInfo?.nickname ?? _userInfo?.account ?? '用户',
                                    size: 60,
                                    imageUrl: _userInfo?.avatar,
                                    showBorder: true,
                                    borderColor: AppTheme.primaryColor,
                                  ),
                                  SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userInfo?.nickname ?? _userInfo?.account ?? '用户',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _userInfo?.generatedEmail ?? _userInfo?.email ?? 'user@example.com',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Divider(),
                            ListTile(
                              leading: Icon(Icons.person_outline, color: AppTheme.primaryColor),
                              title: Text('个人资料'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProfilePage()),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor),
                              title: Text('我的钱包'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                setState(() {
                                  mainTabIndex = 0;
                                  subTabIndex = 5;
                                });
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.settings_outlined, color: AppTheme.primaryColor),
                              title: Text('设置'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Navigator.pushNamed(context, '/settings/theme');
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.cleaning_services_outlined, color: AppTheme.primaryColor),
                              title: Text('清理聊天消息'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                // 使用简单的清理聊天工具
                                SimpleCleanChat.cleanChat(context);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.switch_account_outlined, color: AppTheme.primaryColor),
                              title: Text('切换账号'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(ctx).pop('switch'),
                            ),
                            ListTile(
                              leading: Icon(Icons.logout_outlined, color: AppTheme.errorColor),
                              title: Text('注销账号', style: TextStyle(color: AppTheme.errorColor)),
                              onTap: () => Navigator.of(ctx).pop('logout'),
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                        ),
                      ),
                    );
                    if (result == 'logout' || result == 'switch') {
                      if (result == 'logout') {
                        // 注销：清除所有数据
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                      } else {
                        // 切换账号：只清除登录状态，保留账号历史
                        await Persistence.clearToken();
                        await Persistence.clearUserInfo();

                        // 设置切换账号标记，让登录页面知道是从切换账号进入的
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_switching_account', true);
                        debugPrint('[SocialPage] 已设置切换账号标记');

                        // 清除当前账号的自动登录设置
                        final currentAccount = prefs.getString('account');
                        if (currentAccount != null && currentAccount.isNotEmpty) {
                          final accountKey = 'account_settings_$currentAccount';
                          final settingsStr = prefs.getString(accountKey);
                          if (settingsStr != null && settingsStr.isNotEmpty) {
                            try {
                              final settings = jsonDecode(settingsStr);
                              settings['autoLogin'] = false;
                              await prefs.setString(accountKey, jsonEncode(settings));
                              debugPrint('[SocialPage] 已禁用账号 $currentAccount 的自动登录');
                            } catch (e) {
                              debugPrint('[SocialPage] 更新账号设置失败: $e');
                            }
                          }
                        }
                      }

                      // 跳转到登录页
                      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                    }
                  },
                  child: Container(
                    width: 70,
                    margin: EdgeInsets.only(bottom: 24, left: 10, right: 10),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        AppAvatar(
                          name: _userInfo?.nickname ?? _userInfo?.account ?? '我',
                          size: 36,
                          imageUrl: _userInfo?.avatar,
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        SizedBox(height: 6),
                        Text(
                          '我的',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 主内容区
          Expanded(
            child: _buildMainContent(),
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
                child: _buildMainContent(),
              ),
              // 悬浮主导航（可隐藏/展开）
              AnimatedPositioned(
                duration: Duration(milliseconds: 260),
                curve: Curves.ease,
                top: MediaQuery.of(context).size.height * 0.18,
                left: navOpen ? 0 : -64,
                child: MouseRegion(
                  child: Material(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E1E1E).withOpacity(0.95)
                        : Colors.white.withOpacity(0.95),
                    elevation: 4,
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
                    child: Container(
                      width: 60,
                      height: MediaQuery.of(context).size.height * 0.64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(mainTabs.length, (i) => AppAnimations.fadeIn(
                                  duration: Duration(milliseconds: 300 + (i * 100)),
                                  child: Container(
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: mainTabIndex == i
                                          ? (Theme.of(context).brightness == Brightness.dark
                                              ? AppTheme.primaryDarkColor.withOpacity(0.2)
                                              : AppTheme.primaryLightColor.withOpacity(0.2))
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        mainIcons[i],
                                        color: mainTabIndex == i ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                                        size: 24,
                                      ),
                                      onPressed: () => setState(() { mainTabIndex = i; subTabIndex = 0; }),
                                    ),
                                  ),
                                )),
                              ),
                            ),
                          ),
                          // 折叠按钮
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                navOpen ? Icons.chevron_left : Icons.chevron_right,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              onPressed: () => setStateSB(() => navOpen = !navOpen),
                            ),
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
                    color: AppTheme.primaryColor,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryLightColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.menu, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: BottomAppBar(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.white,
            elevation: 8,
            shape: AutomaticNotchedShape(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
              child: Row(
                children: [
                  ...List.generate(subTabs[mainTabIndex].length, (i) => Expanded(
                    child: InkWell(
                      onTap: () => setState(() => subTabIndex = i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: subTabIndex == i
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.primaryDarkColor.withOpacity(0.2)
                                      : AppTheme.primaryLightColor.withOpacity(0.2))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              children: [
                                Icon(
                                  subTabs[mainTabIndex][i]['icon'],
                                  color: subTabIndex == i ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                                  size: 20,
                                ),
                                // 显示好友请求徽章
                                if (subTabs[mainTabIndex][i]['badge'] == true && _friendRequestCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        _friendRequestCount > 99 ? '99+' : _friendRequestCount.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            subTabs[mainTabIndex][i]['label'],
                            style: TextStyle(
                              fontSize: 10,
                              color: subTabIndex == i ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                              fontWeight: subTabIndex == i ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )),
                  // “我的”按钮固定底部右侧
                  InkWell(
                    onTap: () async {
                      final result = await showModalBottomSheet<String>(
                        context: context,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF1E1E1E)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (ctx) => SafeArea(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              Container(
                                width: 40,
                                height: 4,
                                margin: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    AppAvatar(
                                      name: '用户',
                                      size: 60,
                                      showBorder: true,
                                      borderColor: AppTheme.primaryColor,
                                    ),
                                    SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '用户名',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'user@example.com',
                                          style: TextStyle(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Divider(),
                              ListTile(
                                leading: Icon(Icons.person_outline, color: AppTheme.primaryColor),
                                title: Text('个人资料'),
                                trailing: Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('个人资料功能开发中')),
                                  );
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor),
                                title: Text('我的钱包'),
                                trailing: Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  setState(() {
                                    mainTabIndex = 0;
                                    subTabIndex = 5;
                                  });
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.settings_outlined, color: AppTheme.primaryColor),
                                title: Text('设置'),
                                trailing: Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  Navigator.pushNamed(context, '/settings/theme');
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.cleaning_services_outlined, color: AppTheme.primaryColor),
                                title: Text('清理聊天消息'),
                                trailing: Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  // 使用简单的清理聊天工具
                                  SimpleCleanChat.cleanChat(context);
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.logout_outlined, color: AppTheme.errorColor),
                                title: Text('注销账号', style: TextStyle(color: AppTheme.errorColor)),
                                onTap: () {
                                  Navigator.of(ctx).pop('logout');
                                },
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                          ),
                        ),
                      );
                      if (result == 'logout') {
                        // 清除本地token并跳转登录页
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: AppAvatar(
                            name: '我',
                            size: 20,
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '我的',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildMainContent() {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // 社交模块
    if (mainTabIndex == 0) {
      switch (subTabIndex) {
        case 0: // 聊天
          return isMobile ? ChatPage() : TwoPanelChatPage();
        case 1: // 朋友圈
          return Center(child: Text('朋友圈功能开发中'));
        case 2: // 好友
          return FriendsPage();
        case 3: // 好友设置
          return FriendSettingsPage(
            onSettingsChanged: () {
              // 设置更改后的回调
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('好友设置已更新'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          );
        case 4: // 钱包
          return WalletPage();
        default:
          return Center(child: Text('未知社交子模块'));
      }
    }

    // 其他模块显示默认文本
    return Center(
      child: Text('${mainTabs[mainTabIndex]} - ${subTabs[mainTabIndex][subTabIndex]['label']}模块'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile ? buildMobile() : buildDesktop();
  }
}
