import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/modules/auth/login/login_form/login_form_service.dart';


class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);
  @override
  State<LoginForm> createState() => LoginFormState();
}

class LoginFormState extends State<LoginForm> {
  bool get isPhone {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController pwdCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();

  bool? rememberPwd = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform) ? true : null;
  bool? autoLogin = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform) ? false : null;

  bool _autoLoginCanceled = false;

  @override
  void initState() {
    super.initState();
    _autoLoginCanceled = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPrefs();
      final mq = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      final double width = mq.width / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final bool isTabletOrDesktop = width >= 600;
      if (isTabletOrDesktop && userCtrl.text.isNotEmpty && pwdCtrl.text.isNotEmpty && autoLogin == true && !_autoLoginCanceled) {
        if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform)) {
          if (mounted) await _showAutoLoginDialog();
        } else {
          if (mounted) await _login();
        }
      }
    });
  }

  Future<void> _showAutoLoginDialog() async {
    if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform)) {
      _autoLoginCanceled = false;
      bool finished = false;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 18),
                    Expanded(child: Text('正在自动登录...')),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _autoLoginCanceled = true;
                      Navigator.of(context).pop();
                    },
                    child: Text('取消自动登录'),
                  ),
                ],
              );
            },
          );
        },
      );
      await Future.delayed(Duration(seconds: 2));
      if (!_autoLoginCanceled && mounted) {
        await _login();
        finished = true;
      }
      if (!finished && !_autoLoginCanceled && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) await _login();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform) && !isPhone) {
      setState(() {
        final account = prefs.getString('account') ?? '';
        userCtrl.text = account;
        pwdCtrl.text = prefs.getString('password') ?? '';
        rememberPwd = prefs.getBool('rememberPwd') ?? true;
        autoLogin = prefs.getBool('autoLogin') ?? false;
      });
    } else {
      setState(() {
        userCtrl.text = prefs.getString('account') ?? '';
        pwdCtrl.text = '';
        rememberPwd = null;
        autoLogin = null;
      });
    }
  }

  Future<void> _login() async {
    debugPrint('[DEBUG] _login() 被调用');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('_login() 被调用')));
    }
    Map<String, dynamic> resp = {};
    try {
      debugPrint('[DEBUG] 开始调用LoginFormService.login');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('正在请求登录...')));
      }
      resp = await LoginFormService.login(userCtrl.text, pwdCtrl.text);
      debugPrint('[DEBUG] LoginFormService.login返回: $resp');
    } catch (e, s) {
      debugPrint('[ERROR] LoginFormService.login异常: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络异常: $e'), backgroundColor: Colors.red));
      }
      return;
    }
    final token = resp['token'] ?? (resp['data'] != null ? resp['data']['token'] : null);
    final isSuccess = (resp['code'] == 0) || (resp['success'] == true);
    if (isSuccess && token != null && token.toString().isNotEmpty) {
      debugPrint('[Login][DEBUG] 登录API返回token: $token');
      try {
        await LoginFormService.saveToken(token);
        debugPrint('[Login][DEBUG] LoginFormService.saveToken已执行');
      } catch (e, s) {
        debugPrint('[Login][Error] 保存token异常: $e\n$s');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存token异常: $e'), backgroundColor: Colors.red));
        }
        return;
      }
      debugPrint('[Login] 登录成功，token已保存: $token');
      debugPrint('[Login] autoLogin=$autoLogin');
      if (mounted && [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(Theme.of(context).platform)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
        );
      }
      await _savePrefs();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/social');
      }
    } else {
      debugPrint('[Login][Error] 登录失败或未返回token, resp=$resp');
      if (mounted) {
        String msg = resp['msg']?.toString() ?? '登录失败';
        if (!(token != null && token.toString().isNotEmpty)) {
          msg += '\n(未返回token，无法自动登录)';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform) && !isPhone) {
      await prefs.setString('account', userCtrl.text);
      await prefs.setString('password', pwdCtrl.text);
      await prefs.setBool('rememberPwd', rememberPwd == true);
      await prefs.setBool('autoLogin', autoLogin == true);
    } else {
      await prefs.setString('account', userCtrl.text);
      await prefs.remove('password');
      await prefs.remove('rememberPwd');
      await prefs.remove('autoLogin');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // ...原有表单UI内容，这里省略，实际迁移时需全部保留...
    return Container();
  }
}
