import 'package:flutter/material.dart';

class ThirdPartyLoginPage extends StatelessWidget {
  void _simulateLogin(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('模拟第三方登录: $provider')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('第三方登录')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _simulateLogin(context, 'wechat'),
              child: Text('微信登录'),
            ),
            ElevatedButton(
              onPressed: () => _simulateLogin(context, 'qq'),
              child: Text('QQ登录'),
            ),
            ElevatedButton(
              onPressed: () => _simulateLogin(context, 'apple'),
              child: Text('Apple登录'),
            ),
            ElevatedButton(
              onPressed: () => _simulateLogin(context, 'google'),
              child: Text('Google登录'),
            ),
          ],
        ),
      ),
    );
  }
}
