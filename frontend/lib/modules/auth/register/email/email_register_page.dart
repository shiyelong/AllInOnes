import 'package:flutter/material.dart';
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
      appBar: AppBar(title: Text('邮箱注册')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(labelText: '邮箱'),
              onChanged: (v) => controller.email = v,
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
                  onPressed: () {
                    setState(() {
                      controller.sendCode();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('模拟邮箱验证码: ${controller.generatedCode}')),
                    );
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
                  controller.email = emailCtrl.text;
                  controller.code = codeCtrl.text;
                  controller.password = pwdCtrl.text;
                });
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
    );
  }
}
