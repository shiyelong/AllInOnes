import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 全局统一背景视频
          Positioned.fill(child: VideoWidget()),
          Center(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                ),
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/imgs/logo.svg', width: 72, height: 72),
                    SizedBox(height: 32),
                    _LoginForm(),
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
                    SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: Icon(Icons.qr_code, color: Colors.blueAccent),
                      label: Text('扫码登录', style: TextStyle(color: Colors.blueAccent)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {
                        // TODO: 跳转到扫码登录页面
                      },
                    ),
                    SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text('没有账号？注册', style: TextStyle(color: Colors.blueAccent)),
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

class _LoginFormState extends State<_LoginForm> {
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController pwdCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();
  bool isPhone = true;
  final String backendCode = '123456';

  bool canRequestCode = true;
  int codeCountdown = 0;
  String codeBtnText = '获取验证码';

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
    return Column(
      children: [
        TextField(
          controller: userCtrl,
          decoration: InputDecoration(
            labelText: isPhone ? '手机号' : '邮箱/账号',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            prefixIcon: Icon(isPhone ? Icons.phone : Icons.email),
            suffixIcon: IconButton(
              icon: Icon(Icons.swap_horiz),
              tooltip: isPhone ? '切换邮箱/账号登录' : '切换手机号验证码登录',
              onPressed: () {
                setState(() {
                  isPhone = !isPhone;
                  userCtrl.clear();
                  pwdCtrl.clear();
                  codeCtrl.clear();
                });
              },
            ),
          ),
          keyboardType: isPhone ? TextInputType.phone : TextInputType.emailAddress,
        ),
        SizedBox(height: 16),
        if (isPhone) ...[
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
            onPressed: () {
              if (userCtrl.text.isEmpty || codeCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请填写手机号和验证码')),
                );
                return;
              }
              if (codeCtrl.text != backendCode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('验证码错误')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('登录/注册成功（模拟）')),
              );
            },
            child: Text('一键登录/注册', style: TextStyle(fontSize: 18)),
          ),
        ] else ...[
          TextField(
            controller: pwdCtrl,
            decoration: InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 48),
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: () {
              if (userCtrl.text.isEmpty || pwdCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请填写账号/邮箱和密码')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('登录成功（模拟）')),
              );
            },
            child: Text('登录', style: TextStyle(fontSize: 18)),
          ),
        ],
      ],
    );
  }
}
