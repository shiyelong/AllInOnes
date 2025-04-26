import 'package:flutter/material.dart';

class GroupChatInputBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(hintText: '输入群消息...'),
            ),
          ),
          IconButton(icon: Icon(Icons.send), onPressed: () {})
        ],
      ),
    );
  }
}
