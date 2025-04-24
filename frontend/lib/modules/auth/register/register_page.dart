import 'package:flutter/material.dart';
// import 'phone/phone_register_controller.dart';
// import 'email/email_register_controller.dart';

import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
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

class _RegisterPageState extends State<RegisterPage> {
  // 手机号和邮箱相关逻辑已注释，后续后端完成再恢复
  // bool isPhone = true;
  // final phoneCtrl = TextEditingController();
  // final phoneCodeCtrl = TextEditingController();
  // final phonePwdCtrl = TextEditingController();
  // final emailCtrl = TextEditingController();
  // final emailCodeCtrl = TextEditingController();
  // final emailPwdCtrl = TextEditingController();
  // final phoneController = PhoneRegisterController();
  // final emailController = EmailRegisterController();

  final accountCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final pwd2Ctrl = TextEditingController();
  final codeCtrl = TextEditingController();

  // 刷新验证码（对接后端）
  void getVerifyCodeFromBackend() async {
    // TODO: 调用后端API获取验证码并展示
    // 示例：var code = await Api.getRegisterCode(accountCtrl.text);
    // setState(() { ... });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已请求新验证码（请对接后端）')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景视频（全局唯一）
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
                    // 返回按钮
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: '返回',
                      ),
                    ),
                    SizedBox(height: 8),
                    SvgPicture.asset('assets/imgs/logo.svg', width: 72, height: 72),
                    SizedBox(height: 24),
                    TextField(
                      controller: accountCtrl,
                      decoration: InputDecoration(labelText: '账号'),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: pwdCtrl,
                      obscureText: true,
                      decoration: InputDecoration(labelText: '密码'),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: pwd2Ctrl,
                      obscureText: true,
                      decoration: InputDecoration(labelText: '再次输入密码'),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            decoration: InputDecoration(labelText: '验证码（后端提供）'),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: getVerifyCodeFromBackend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            minimumSize: Size(48, 40),
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Icon(Icons.refresh, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {
                        if (accountCtrl.text.isEmpty || pwdCtrl.text.isEmpty || pwd2Ctrl.text.isEmpty || codeCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请填写所有字段')));
                          return;
                        }
                        if (pwdCtrl.text != pwd2Ctrl.text) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('两次输入密码不一致')));
                          return;
                        }
                        if (codeCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请输入验证码')));
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('注册成功（模拟）')));
                      },
                      child: Text('注册', style: TextStyle(fontSize: 18)),
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
