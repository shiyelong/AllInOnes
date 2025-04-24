import 'package:flutter/material.dart';
import 'register/phone/phone_register_page.dart';
import 'register/email/email_register_page.dart';
import 'login/third_party/third_party_login_page.dart';

class AuthEntryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('登录/注册入口')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PhoneRegisterPage()),
                );
              },
              child: Text('手机号注册'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EmailRegisterPage()),
                );
              },
              child: Text('邮箱注册'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ThirdPartyLoginPage()),
                );
              },
              child: Text('第三方登录'),
            ),
          ],
        ),
      ),
    );
  }
}
