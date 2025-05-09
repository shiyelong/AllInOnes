import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'modules/auth/login/login_page.dart';
import 'modules/auth/register/register_page_new.dart' as register;
import 'modules/auth/register/new_register_page.dart';
import 'modules/social/social_main_page.dart';
import 'modules/social/chat/add_friend_dialog.dart';
import 'modules/wallet/wallet_page.dart';
import 'utils/auto_login.dart';
import 'common/theme.dart';
import 'common/theme_manager.dart';
import 'common/localization.dart';
import 'common/persistence.dart';
import 'common/platform_utils.dart';
import 'modules/profile/settings/theme_settings_page.dart';
import 'modules/social/chat/call/simplified/simplified_call_manager.dart';
import 'pages/data_cleanup_page.dart';
import 'common/network_monitor.dart';
import 'common/websocket_manager.dart';
import 'common/websocket_message_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏颜色
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // 初始化本地化
  AppLocalization.initialize();

  // 初始化主题管理器
  await ThemeManager.initialize();

  // 初始化token缓存
  await Persistence.getTokenAsync();

  // 初始化桌面窗口设置（仅在桌面平台）
  await PlatformUtils.initDesktopWindow();

  // 打印所有存储的偏好设置（调试用）
  await Persistence.debugPrintAllPrefs();

  // 打印当前平台信息
  debugPrint('当前平台: ${PlatformUtils.platformName}');
  debugPrint('是否是移动平台: ${PlatformUtils.isMobile}');
  debugPrint('是否是桌面平台: ${PlatformUtils.isDesktop}');
  debugPrint('是否是Web平台: ${PlatformUtils.isWeb}');

  // 初始化简化版通话管理器
  try {
    await SimplifiedCallManager().initialize();
    debugPrint('初始化简化版通话管理器成功');
  } catch (e) {
    debugPrint('初始化简化版通话管理器失败: $e');
  }

  // 初始化网络监控器
  try {
    NetworkMonitor().initialize();
    debugPrint('初始化网络监控器成功');
  } catch (e) {
    debugPrint('初始化网络监控器失败: $e');
  }

  // 初始化WebSocket消息处理器
  try {
    WebSocketMessageHandler().initialize();
    debugPrint('初始化WebSocket消息处理器成功');
  } catch (e) {
    debugPrint('初始化WebSocket消息处理器失败: $e');
  }

  // 初始化WebSocket连接
  try {
    // 如果用户已登录，则初始化WebSocket连接
    if (Persistence.isLoggedIn()) {
      WebSocketManager().initialize();
      debugPrint('初始化WebSocket连接成功');
    } else {
      debugPrint('用户未登录，跳过WebSocket连接初始化');
    }
  } catch (e) {
    debugPrint('初始化WebSocket连接失败: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // 释放网络监控器资源
    NetworkMonitor().dispose();

    // 释放WebSocket资源
    WebSocketManager().close();
    WebSocketMessageHandler().dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AllInOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeManager.getThemeData(),
      themeMode: ThemeMode.light, // 使用自定义主题
      navigatorKey: GlobalKey<NavigatorState>(), // 使用全局导航键
      initialRoute: '/login',
      routes: {
        '/login': (context) => AutoLoginGate(child: LoginPage()),
        '/register': (context) => register.RegisterPage(),
        '/register/new': (context) => NewRegisterPage(),
        '/social': (context) => SocialMainPage(),
        '/settings/theme': (context) => ThemeSettingsPage(
          onThemeChanged: () {
            // 强制重建应用以应用新主题
            setState(() {});
          },
        ),
        '/wallet': (context) => const WalletPage(),
        // 添加群聊页面路由
        '/group_chat': (context) => SocialMainPage(),
        // 数据清理页面路由
        '/data_cleanup': (context) => const DataCleanupPage(),
        // 添加好友页面路由
        '/add_friend': (context) => Scaffold(
          appBar: AppBar(title: Text('添加好友')),
          body: Builder(
            builder: (context) {
              // 使用Builder获取正确的context
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // 在下一帧显示添加好友对话框
                showDialog(
                  context: context,
                  builder: (ctx) => AddFriendDialog(
                    onAdd: (friendData) {
                      // 显示成功消息
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已发送好友请求'), backgroundColor: Colors.green),
                      );
                      // 返回上一页
                      Navigator.pop(context);
                    },
                  ),
                ).then((_) {
                  // 对话框关闭后返回上一页
                  Navigator.pop(context);
                });
              });

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载添加好友功能...'),
                  ],
                ),
              );
            },
          ),
        ),
      },
    );
  }
}


