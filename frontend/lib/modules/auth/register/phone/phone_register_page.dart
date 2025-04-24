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
                  onPressed: () {
                    setState(() {
                      controller.sendCode();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('模拟验证码: ${controller.generatedCode}')),
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
                  controller.phone = phoneCtrl.text;
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
