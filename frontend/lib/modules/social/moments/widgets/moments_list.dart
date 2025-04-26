import 'package:flutter/material.dart';

class MomentsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: 动态流实现
    return ListView(
      children: [
        ListTile(title: Text('用户A 发布了一条动态')), 
      ],
    );
  }
}
