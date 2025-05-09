import 'package:flutter/material.dart';
import '../common/persistence.dart';
import '../common/api.dart';
import '../common/platform_utils.dart';

/// 自动登录门户
/// 用于在应用启动时自动登录
class AutoLoginGate extends StatefulWidget {
  final Widget child;

  const AutoLoginGate({Key? key, required this.child}) : super(key: key);

  @override
  _AutoLoginGateState createState() => _AutoLoginGateState();
}

class _AutoLoginGateState extends State<AutoLoginGate> {
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    // 延迟执行，确保界面已经构建完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoLogin();
    });
  }

  /// 检查是否需要自动登录
  Future<void> _checkAutoLogin() async {
    // 如果已经登录，则不需要自动登录
    final token = Persistence.getToken();
    if (token != null && token.isNotEmpty) {
      debugPrint('[AutoLoginGate] 用户已登录，无需自动登录');
      return;
    }

    // 检查是否开启了自动登录
    final autoLogin = Persistence.getAutoLogin();
    if (!autoLogin) {
      debugPrint('[AutoLoginGate] 未开启自动登录');
      return;
    }

    // 检查是否记住了密码
    final rememberPassword = Persistence.getRememberPassword();
    if (!rememberPassword) {
      debugPrint('[AutoLoginGate] 未记住密码，无法自动登录');
      return;
    }

    // 获取保存的账号密码
    final account = Persistence.getSavedAccount();
    final password = Persistence.getSavedPassword();
    if (account == null || password == null || account.isEmpty || password.isEmpty) {
      debugPrint('[AutoLoginGate] 未保存账号密码，无法自动登录');
      return;
    }

    // 移动端总是自动登录，桌面端根据设置决定
    if (!PlatformUtils.isMobile && !autoLogin) {
      debugPrint('[AutoLoginGate] 桌面端未开启自动登录');
      return;
    }

    // 执行自动登录
    await _doAutoLogin(account, password);
  }

  /// 执行自动登录
  Future<void> _doAutoLogin(String account, String password) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      debugPrint('[AutoLoginGate] 正在执行自动登录: $account');

      // 调用登录API
      final response = await Api.login(account: account, password: password);

      if (response['success'] == true) {
        // 登录成功
        final token = response['data']['token'];
        final userId = response['data']['user_id'];
        final userInfo = response['data']['user_info'];

        // 保存登录信息
        await Persistence.saveLoginInfo(
          token: token,
          userId: userId.toString(),
          userInfo: userInfo,
        );

        // 保存最近登录账号
        await Persistence.saveRecentAccount(
          account: account,
          nickname: userInfo['nickname'] ?? '',
          avatar: userInfo['avatar'],
        );

        debugPrint('[AutoLoginGate] 自动登录成功: $account');

        // 跳转到主页
        Navigator.of(context).pushReplacementNamed('/social');
      } else {
        // 登录失败
        final errorMsg = response['msg'] ?? '自动登录失败';
        debugPrint('[AutoLoginGate] 自动登录失败: $errorMsg');

        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      debugPrint('[AutoLoginGate] 自动登录异常: $e');
      setState(() {
        _errorMessage = '自动登录异常: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在加载，显示加载界面
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在自动登录...'),
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 否则显示子组件
    return widget.child;
  }
}
