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
                        SizedBox(height: 32),
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
                              onPressed: () {
                                controller.sendCode();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('模拟邮箱验证码: ${controller.generatedCode}')),
                                );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('注册成功')),
                              );
                            } else if (controller.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(controller.error!)),
                              );
                            }
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
