import 'package:flutter/material.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: EdgeInsets.all(0),
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(Icons.camera_alt),
                              title: Text('拍照更换头像'),
                              onTap: () {
                                Navigator.pop(ctx);
                                // TODO: 实现拍照换头像
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.photo_library),
                              title: Text('从相册选择'),
                              onTap: () {
                                Navigator.pop(ctx);
                                // TODO: 实现相册换头像
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.blueAccent,
                    child: Text('A', style: TextStyle(fontSize: 40, color: Colors.white)),
                  ),
                ),
                SizedBox(height: 16),
                Text('ALL 用户', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('ID: 10001', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          SizedBox(height: 12),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.shopping_bag, color: Colors.deepOrange),
                  title: Text('我的订单'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.color_lens, color: Colors.purple),
                  title: Text('主题商城'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: 跳转主题商城页面
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.location_on, color: Colors.green),
                  title: Text('收货地址'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.favorite, color: Colors.pink),
                  title: Text('我的收藏'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet, color: Colors.blue),
                  title: Text('我的钱包'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.grey),
                  title: Text('设置'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
