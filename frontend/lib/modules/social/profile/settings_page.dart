import 'package:flutter/material.dart';

/// 通用设置页，后续可扩展各端个性化设置项
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.language),
            title: Text('语言/Language'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.devices_other),
            title: Text('设备管理'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.security),
            title: Text('隐私与安全'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
