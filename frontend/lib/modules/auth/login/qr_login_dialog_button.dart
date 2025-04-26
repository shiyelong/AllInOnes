import 'package:flutter/material.dart';
import 'desktop_qr_login_area.dart';

class QrLoginDialogButton extends StatelessWidget {
  const QrLoginDialogButton({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(Icons.qr_code, color: Colors.blueAccent),
        label: Text('扫码登录', style: TextStyle(color: Colors.blueAccent)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.blueAccent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () async {
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // 阻止点击内容关闭
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
                      ),
                      padding: EdgeInsets.all(28),
                      child: DesktopQrLoginArea(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
