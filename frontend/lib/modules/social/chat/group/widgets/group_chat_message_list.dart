import 'package:flutter/material.dart';

class GroupChatMessageList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: 群聊消息列表实现
    return ListView(
      children: [
        ListTile(title: Text('群成员A: 大家好')), 
        ListTile(title: Text('我: 欢迎！')), 
      ],
    );
  }
}
