import 'package:flutter/material.dart';
import '../../../common/theme_manager.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final VoidCallback onSwitchAccount;
  const SettingsPage({Key? key, required this.onLogout, required this.onDeleteAccount, required this.onSwitchAccount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, '个性化'),
          ListTile(
            leading: Icon(Icons.color_lens),
            title: Text('主题设置'),
            subtitle: Text('自定义应用外观'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/settings/theme');
            },
          ),
          Divider(),

          _buildSectionHeader(context, '账户'),
          ListTile(
            leading: Icon(Icons.shopping_bag),
            title: Text('订单管理'),
            subtitle: Text('查看历史订单'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {/* 跳转订单页面 */},
          ),
          Divider(),

          _buildSectionHeader(context, '通讯'),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('通知设置'),
            subtitle: Text('管理消息提醒'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {/* 跳转通知设置页面 */},
          ),
          ListTile(
            leading: Icon(Icons.chat),
            title: Text('聊天设置'),
            subtitle: Text('管理聊天相关设置'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {/* 跳转聊天设置页面 */},
          ),
          Divider(),

          _buildSectionHeader(context, '隐私与安全'),
          ListTile(
            leading: Icon(Icons.security),
            title: Text('隐私设置'),
            subtitle: Text('管理个人信息和隐私'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {/* 跳转隐私设置页面 */},
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('账号安全'),
            subtitle: Text('修改密码和安全选项'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {/* 跳转账号安全页面 */},
          ),
          Divider(),

          _buildSectionHeader(context, '其他'),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('版本信息和法律声明'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {/* 跳转关于页面 */},
          ),
          ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('帮助与反馈'),
            subtitle: Text('获取帮助或提交反馈'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {/* 跳转帮助页面 */},
          ),
          Divider(),

          _buildSectionHeader(context, '账户操作'),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.orange),
            title: Text('退出登录', style: TextStyle(color: Colors.orange)),
            onTap: onLogout,
          ),
          ListTile(
            leading: Icon(Icons.switch_account, color: Colors.blue),
            title: Text('更换账号', style: TextStyle(color: Colors.blue)),
            onTap: onSwitchAccount,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text('注销账号', style: TextStyle(color: Colors.red)),
            subtitle: Text('此操作不可逆，将永久删除您的账号'),
            onTap: onDeleteAccount,
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: ThemeManager.currentTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
