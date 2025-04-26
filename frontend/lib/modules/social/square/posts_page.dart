import 'package:flutter/material.dart';

/// 帖子页面（假页面/骨架）
class PostsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('帖子')),
      body: Center(child: Text('帖子功能敬请期待')), 
    );
  }
}
