import 'package:flutter/material.dart';

class SingleChatMessageList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: 消息列表实现
    return ListView(
      children: [
        ListTile(title: Text('对方: 你好')), 
        ListTile(title: Text('我: 你好！')), 
      ],
    );
  }
}
