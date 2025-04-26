import 'package:flutter/material.dart';
import '../../../auth/login/scan_page.dart';

class ChatScanAction extends StatelessWidget {
  const ChatScanAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
      tooltip: '扫一扫',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => QrScanPage(
              onScan: (code) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('扫码结果: $code'), backgroundColor: Colors.green),
                );
                // TODO: 可在此处处理加好友/登录等逻辑
              },
            ),
          ),
        );
      },
    );
  }
}
