import 'package:flutter/material.dart';

class MiniAppIcon extends StatelessWidget {
  final String title;
  const MiniAppIcon({required this.title, super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 28, backgroundColor: Colors.blue, child: Icon(Icons.apps, color: Colors.white)),
        SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 14)),
      ],
    );
  }
}
