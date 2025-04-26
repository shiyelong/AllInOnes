import 'package:flutter/material.dart';
import 'scan_page.dart';
import 'qr_login_service.dart';

class QrScanLoginButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(Icons.qr_code_scanner),
        label: Text('扫一扫登录'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => QrScanPage(
                onScan: (code) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => Center(child: CircularProgressIndicator()),
                  );
                  QrLoginService.loginWithQrCode(code).then((success) {
                    Navigator.of(context, rootNavigator: true).pop(); // 关闭loading
                    if (success) {
                      Navigator.of(context).pushReplacementNamed('/social');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('二维码登录失败，请重试'), backgroundColor: Colors.red),
                      );
                    }
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
