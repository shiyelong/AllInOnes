import 'package:flutter/material.dart';

/// 插件页面（假页面/骨架）
class PluginsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('插件')),
      body: Center(child: Text('插件功能敬请期待')), 
    );
  }
}
