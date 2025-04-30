import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final VoidCallback onSwitchAccount;
  const SettingsPage({Key? key, required this.onLogout, required this.onDeleteAccount, required this.onSwitchAccount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.shopping_bag),
            title: Text('订单管理'),
            onTap: () {/* 跳转订单页面 */},
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('退出登录'),
            onTap: onLogout,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever),
            title: Text('注销账号'),
            onTap: onDeleteAccount,
          ),
          ListTile(
            leading: Icon(Icons.switch_account),
            title: Text('更换账号'),
            onTap: onSwitchAccount,
          ),
        ],
      ),
    );
  }
}
