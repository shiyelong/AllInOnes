import 'package:flutter/material.dart';
import 'dart:ui';
import 'email_register_controller.dart';

class EmailRegisterPage extends StatefulWidget {
  @override
  State<EmailRegisterPage> createState() => _EmailRegisterPageState();
}

class _EmailRegisterPageState extends State<EmailRegisterPage> {
  final controller = EmailRegisterController();
  final emailCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 渐变+毛玻璃背景
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  curve: Curves.fastOutSlowIn,
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
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width < 480 ? double.infinity : 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('邮箱注册', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        SizedBox(height: 16),
                        // 错误消息显示
                        AnimatedBuilder(
                          animation: controller,
                          builder: (context, child) {
                            if (controller.error != null) {
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        controller.error!,
                                        style: TextStyle(color: Colors.red.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return SizedBox(height: 0);
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: emailCtrl,
                          decoration: InputDecoration(labelText: '邮箱'),
                          onChanged: (v) => controller.email = v,
                        ),
                        SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: codeCtrl,
                                decoration: InputDecoration(labelText: '验证码'),
                                onChanged: (v) => controller.code = v,
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                // 设置邮箱
                                controller.email = emailCtrl.text;

                                // 发送验证码
                                final response = await controller.sendCode();

                                if (response['success'] == true) {
                                  // 显示验证码对话框，而不是底部Snackbar
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('验证码已发送'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('验证码已发送到您的邮箱'),
                                          SizedBox(height: 10),
                                          Text(
                                            '请查看邮箱',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [

                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('关闭'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (response['msg']?.contains('已被注册') == true) {
                                  // 显示已注册提示对话框
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red),
                                          SizedBox(width: 10),
                                          Text('邮箱已注册'),
                                        ],
                                      ),
                                      content: Text('该邮箱已被注册，请使用其他邮箱或直接登录。'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text('确定'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.of(context).pushReplacementNamed('/login');
                                          },
                                          child: Text('去登录'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              child: Text('获取验证码'),
                            ),
                          ],
                        ),
                        SizedBox(height: 18),
                        TextField(
                          controller: pwdCtrl,
                          obscureText: true,
                          decoration: InputDecoration(labelText: '密码'),
                          onChanged: (v) => controller.password = v,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            controller.email = emailCtrl.text;
                            controller.code = codeCtrl.text;
                            controller.password = pwdCtrl.text;
                            bool ok = controller.validateAndRegister();
                            if (ok) {
                              // 注册成功，显示成功对话框
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green),
                                      SizedBox(width: 10),
                                      Text('注册成功'),
                                    ],
                                  ),
                                  content: Text('您已成功注册，即将跳转到登录页面...'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.of(context).pushReplacementNamed('/login');
                                      },
                                      child: Text('确定'),
                                    ),
                                  ],
                                ),
                              );

                              // 3秒后自动关闭对话框并跳转
                              Future.delayed(Duration(seconds: 3), () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.pop(context);
                                  Navigator.of(context).pushReplacementNamed('/login');
                                }
                              });
                            }
                            // 错误信息已经在上方显示，不需要额外的Snackbar
                          },
                          child: Text('注册'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
