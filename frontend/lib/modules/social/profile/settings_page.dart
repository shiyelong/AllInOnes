import 'package:flutter/material.dart';
import 'widgets/friend_add_mode_switcher.dart';

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
        children: [
          ListTile(
            leading: Icon(Icons.verified_user),
            title: Text('加好友方式'),
            subtitle: FriendAddModeSwitcher(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言/Language'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.devices_other),
            title: const Text('设备管理'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('隐私与安全'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
