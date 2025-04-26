import 'package:flutter/material.dart';

class QrScanPage extends StatelessWidget {
  final void Function(String code)? onScan;
  const QrScanPage({this.onScan, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('扫码（占位页）')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            onScan?.call('DEMO-CODE-1234');
            Navigator.pop(context);
          },
          child: Text('模拟扫码返回'),
        ),
      ),
    );
  }
}
