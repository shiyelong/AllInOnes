import 'package:flutter/material.dart';
import 'phone_register_controller.dart';

class PhoneRegisterPage extends StatefulWidget {
  @override
  State<PhoneRegisterPage> createState() => _PhoneRegisterPageState();
}

class _PhoneRegisterPageState extends State<PhoneRegisterPage> {
  final controller = PhoneRegisterController();
  final phoneCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('手机号注册')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: '手机号'),
              onChanged: (v) => controller.phone = v,
            ),
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
                    // 设置手机号
                    controller.phone = phoneCtrl.text;

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
                              Text('模拟手机验证码:'),
                              SizedBox(height: 10),
                              Text(
                                controller.generatedCode,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                // 自动填充验证码
                                codeCtrl.text = controller.generatedCode;
                                Navigator.pop(context);
                              },
                              child: Text('自动填充'),
                            ),
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
                              Text('手机号已注册'),
                            ],
                          ),
                          content: Text('该手机号已被注册，请使用其他手机号或直接登录。'),
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
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: '密码'),
              onChanged: (v) => controller.password = v,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  controller.phone = phoneCtrl.text;
                  controller.code = codeCtrl.text;
                  controller.password = pwdCtrl.text;
                });
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
                } else if (controller.error != null) {
                  // 显示错误对话框，而不是底部Snackbar
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Text('注册失败'),
                        ],
                      ),
                      content: Text(controller.error!),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('确定'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Text('注册'),
            ),
          ],
        ),
      ),
    );
  }
}
