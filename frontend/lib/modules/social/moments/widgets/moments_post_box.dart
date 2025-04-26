import 'package:flutter/material.dart';

class MomentsPostBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(hintText: '发布新动态...'),
            ),
          ),
          IconButton(icon: Icon(Icons.send), onPressed: () {})
        ],
      ),
    );
  }
}
