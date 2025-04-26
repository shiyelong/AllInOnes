import 'package:flutter/material.dart';
import 'package:frontend/modules/auth/login/qr_login_widget.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class DesktopQrLoginArea extends StatefulWidget {
  const DesktopQrLoginArea({super.key});
  @override
  State<DesktopQrLoginArea> createState() => _DesktopQrLoginAreaState();
}

class _DesktopQrLoginAreaState extends State<DesktopQrLoginArea> {
  late String qrData;
  bool scanned = false;
  bool expired = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _genQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _genQr() {
    setState(() {
      qrData = const Uuid().v4();
      scanned = false;
      expired = false;
    });
    _timer?.cancel();
    _timer = Timer(Duration(minutes: 2), () {
      setState(() {
        expired = true;
      });
    });
    // TODO: 通知后端生成对应uuid会话
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          ignoring: expired,
          child: Opacity(
            opacity: expired ? 0.4 : 1.0,
            child: DesktopQrLoginWidget(
              qrData: qrData,
              scanned: scanned,
              onRefresh: expired ? _genQr : null,
            ),
          ),
        ),
        if (expired)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('二维码已过期，请点击刷新', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
