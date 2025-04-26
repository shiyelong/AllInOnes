import 'package:flutter/material.dart';
import 'package:frontend/modules/auth/login/qr_login_dialog_button.dart';
import 'package:frontend/modules/auth/login/qr_scan_login_button.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/common/api.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/common/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 自动登录调试逻辑

Future<void> autoLoginDebug(BuildContext context) async {
  final token = await Persistence.getToken();
  debugPrint('[AutoLoginDebug] token=$token');
  if (token != null && token.isNotEmpty) {
    final resp = await Api.validateToken(token);
    debugPrint('[AutoLoginDebug] validate resp=$resp');
    if (resp['success'] == true) {
      // TODO: 跳转主页面
      debugPrint('[AutoLoginDebug] token有效，进入主页面');
    } else {
      debugPrint('[AutoLoginDebug] token无效，跳转登录页');
      // TODO: 跳转登录页
    }
  } else {
    debugPrint('[AutoLoginDebug] 未检测到token，停留在登录页');
    // TODO: 跳转登录页
  }
}


class LoginPage extends StatelessWidget {
  // 判断平台
  bool get isDesktop => [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 毛玻璃渐变背景
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F4FCB), Color(0xFF9B26B6), Color(0xFF3AC1E6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withOpacity(0.08)),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]!.withOpacity(0.92)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 32,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                width: MediaQuery.of(context).size.width < 480 ? double.infinity : 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'logo',
                      child: SvgPicture.asset('assets/imgs/logo.svg', width: 72, height: 72),
                    ),
                    SizedBox(height: 32),
                    _LoginForm(),
                    SizedBox(height: 18),
                    // 社交登录
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialLoginBtn(icon: Icons.wechat, color: Color(0xFF1AAD19), onTap: () {}),
                        SizedBox(width: 18),
                        _SocialLoginBtn(icon: Icons.telegram, color: Color(0xFF229ED9), onTap: () {}),
                        SizedBox(width: 18),
                        _SocialLoginBtn(icon: Icons.alternate_email, color: Color(0xFF1DA1F2), onTap: () {}),
                      ],
                    ),
                    SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final platform = Theme.of(context).platform;
                        final isDesktop = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(platform);
                        final isTabletOrMobile = [TargetPlatform.android, TargetPlatform.iOS].contains(platform);
                        if (isDesktop) {
                          return QrLoginDialogButton();
                        } else if (isTabletOrMobile) {
                          return QrScanLoginButton();
                        }
                        return SizedBox.shrink();
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('或', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () async {
                        Navigator.pushNamed(context, '/register');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      child: Text('没有账号？注册'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoWidget extends StatefulWidget {
  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/background.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        _controller.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? VideoPlayer(_controller)
        : Container(color: Colors.black);
  }
}

class _LoginForm extends StatefulWidget {
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _SocialLoginBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SocialLoginBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}

class _LoginFormState extends State<_LoginForm> {
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
    _loginMethodLoaded = false;
    _loadLoginMethod().then((_) async {
      await _loadPrefs();
      final mq = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      final double width = mq.width / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final bool isTabletOrDesktop = width >= 600;
      // 只有桌面端且勾选了自动登录才自动登录
      if (isTabletOrDesktop && userCtrl.text.isNotEmpty && pwdCtrl.text.isNotEmpty && autoLogin == true && !_autoLoginCanceled) {
        // 仅桌面端弹出可取消的loading
        if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform)) {
          await _showAutoLoginDialog();
        } else {
          await _login();
        }
      }
      // 移动端不自动登录
    });
  }

  Future<void> _showAutoLoginDialog() async {
    // 仅桌面端弹窗并允许取消，移动端直接登录无loading
    if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform)) {
      _autoLoginCanceled = false;
      bool finished = false;
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
      // 给用户2秒时间取消自动登录
      await Future.delayed(Duration(seconds: 2));
      if (!_autoLoginCanceled) {
        await _login();
        finished = true;
      }
      if (!finished && !_autoLoginCanceled && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      // 移动端直接登录，无loading无延迟
      await _login();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // 只在桌面端且账号密码登录时记住账号
    if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform) && !isPhone) {
      setState(() {
        final account = prefs.getString('account') ?? '';
        userCtrl.text = account;
        pwdCtrl.text = prefs.getString('password') ?? '';
        rememberPwd = prefs.getBool('rememberPwd') ?? true;
        autoLogin = prefs.getBool('autoLogin') ?? false;
      });
    } else {
      // 移动端只记住账号，不记住密码
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
    // 登录API
    Map<String, dynamic> resp = {};
    try {
      debugPrint('[DEBUG] 开始调用Api.login');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('正在请求登录...')));
      }
      resp = await Api.login(account: userCtrl.text, password: pwdCtrl.text).timeout(Duration(seconds: 10));
      debugPrint('[DEBUG] Api.login返回: ' + resp.toString());
    } catch (e, s) {
      debugPrint('[ERROR] Api.login异常: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络异常: $e'), backgroundColor: Colors.red));
      }
      return;
    }
    // 兼容多种返回结构
    final token = resp['token'] ?? (resp['data'] != null ? resp['data']['token'] : null);
    final isSuccess = (resp['code'] == 0) || (resp['success'] == true);
    if (isSuccess && token != null && token.toString().isNotEmpty) {
      debugPrint('[Login][DEBUG] 登录API返回token: $token');
      try {
        await Persistence.saveToken(token);
        debugPrint('[Login][DEBUG] Persistence.saveToken已执行');
      } catch (e, s) {
        debugPrint('[Login][Error] 保存token异常: $e\n$s');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存token异常: $e'), backgroundColor: Colors.red));
        }
        return;
      }
      debugPrint('[Login] 登录成功，token已保存: $token');
      // 2. autoLogin 只影响自动登录流程，不影响token写入
      debugPrint('[Login] autoLogin=$autoLogin');
      // Only show success SnackBar on desktop
      if (mounted && [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(Theme.of(context).platform)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
        );
      }
      await _savePrefs(); // 仅桌面端保存账号密码等
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
    // 仅桌面端且账号密码登录时保存
    if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform) && !isPhone) {
      await prefs.setString('account', userCtrl.text);
      await prefs.setString('password', pwdCtrl.text);
      await prefs.setBool('rememberPwd', rememberPwd == true);
      await prefs.setBool('autoLogin', autoLogin == true);
    } else {
      // 移动端只保存账号
      await prefs.setString('account', userCtrl.text);
      await prefs.remove('password');
      await prefs.remove('rememberPwd');
      await prefs.remove('autoLogin');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('forcePwdTab') && args['forcePwdTab'] == true) {
      isPhone = false;
    }
    if (args is Map && args.containsKey('account')) {
      userCtrl.text = args['account'] ?? '';
    }
    if (args is Map && args.containsKey('password')) {
      pwdCtrl.text = args['password'] ?? '';
    }
  }
  bool isPhone = true; // true: 手机号一键登录，false: 账号密码登录
  bool _loginMethodLoaded = false;

  static const String loginMethodKey = 'login_method'; // 用于持久化登录方式

  final String backendCode = '123456';

  bool canRequestCode = true;
  int codeCountdown = 0;
  String codeBtnText = '获取验证码';

  // 保存当前登录方式到SharedPreferences
  Future<void> _saveLoginMethod() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(loginMethodKey, isPhone ? 'phone' : 'password');
  }

  // 加载上次选择的登录方式
  Future<void> _loadLoginMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final method = prefs.getString(loginMethodKey);
    setState(() {
      isPhone = method == null ? true : method == 'phone';
      _loginMethodLoaded = true;
    });
  }

  void getCodeFromBackend() async {
    setState(() {
      canRequestCode = false;
      codeCountdown = 60;
      codeBtnText = '60s';
    });
    // TODO: 调用后端API获取验证码
    // await Api.getSmsCode(userCtrl.text);
    // 模拟倒计时
    for (int i = 59; i >= 0; i--) {
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        codeCountdown = i;
        codeBtnText = i > 0 ? '${i}s' : '获取验证码';
        canRequestCode = i == 0;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (!_loginMethodLoaded) {
      // 优化移动端首屏体验：显示Logo+进度条而非纯白屏
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'logo',
              child: SvgPicture.asset('assets/imgs/logo.svg', width: 72, height: 72),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('载入中...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 350),
      child: Column(
        key: ValueKey(isPhone),
        children: [
          TextField(
            controller: userCtrl,
            decoration: InputDecoration(
              labelText: isPhone ? '手机号' : '手机号/邮箱/账号',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              prefixIcon: Icon(isPhone ? Icons.phone : Icons.email),
              suffixIcon: IconButton(
                icon: AnimatedRotation(
                  duration: Duration(milliseconds: 300),
                  turns: isPhone ? 0 : 0.5,
                  child: Icon(Icons.swap_horiz, color: Colors.blueAccent),
                ),
                tooltip: isPhone ? '切换账号密码登录' : '切换手机号一键登录',
                onPressed: () async {
                  setState(() {
                    isPhone = !isPhone;
                  });
                  await _saveLoginMethod(); // 切换登录方式时保存
                },
              ),
            ),
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          ),
          SizedBox(height: 16),
          if (isPhone) 
            ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: '验证码',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: Icon(Icons.verified_user),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: canRequestCode ? getCodeFromBackend : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: Size(96, 40),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(codeBtnText, style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () async {
                  if (userCtrl.text.isEmpty || codeCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('请填写手机号和验证码')),
                    );
                    return;
                  }
                  // 校验手机号格式
                  if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(userCtrl.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('请输入正确的手机号')),
                    );
                    return;
                  }
                  // TODO: 调用后端接口校验验证码并登录/注册
                  // Only show success SnackBar on desktop
                   if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(Theme.of(context).platform)) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
                     );
                   }
                   Navigator.of(context).pushNamedAndRemoveUntil('/social', (route) => false);
                },
                child: Text('一键登录/注册', style: TextStyle(fontSize: 18)),
              ),
            ] 
          else 
            ...[
              TextField(
                controller: pwdCtrl,
                decoration: InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(Theme.of(context).platform)) ...[
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: rememberPwd == true,
                        onChanged: (v) {
                          setState(() {
                            rememberPwd = v!;
                            if (rememberPwd == false) autoLogin = false;
                          });
                        },
                        activeColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        visualDensity: VisualDensity.compact,
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            rememberPwd = !(rememberPwd == true);
                            if (rememberPwd == false) autoLogin = false;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 18, color: Colors.blueAccent),
                            SizedBox(width: 4),
                            Text('记住密码', style: TextStyle(fontSize: 15)),
                          ],
                        ),
                      ),
                      SizedBox(width: 18),
                      Checkbox(
                        value: autoLogin == true,
                        onChanged: (v) {
                          setState(() {
                            autoLogin = v!;
                            if (autoLogin == true) rememberPwd = true;
                          });
                        },
                        activeColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        visualDensity: VisualDensity.compact,
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            autoLogin = !(autoLogin == true);
                            if (autoLogin == true) rememberPwd = true;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(Icons.login, size: 18, color: Colors.blueAccent),
                            SizedBox(width: 4),
                            Text('自动登录', style: TextStyle(fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () async {
                  if (userCtrl.text.isEmpty || pwdCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('请填写手机号/邮箱/账号和密码')),
                    );
                    return;
                  }
                  await _savePrefs();
                  // 统一走 _login()，保证token写入和日志
                  await _login();
                },
                child: Text('登录', style: TextStyle(fontSize: 18)),
              ),
            ],
        ],
      ),
    );
  }
}
