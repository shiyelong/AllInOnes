import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DesktopQrLoginWidget extends StatelessWidget {
  final String qrData;
  final bool scanned;
  final VoidCallback? onRefresh;
  const DesktopQrLoginWidget({required this.qrData, this.scanned = false, this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: QrImageView(
            data: qrData,
            size: 160,
            backgroundColor: Colors.white,
          ),
        ),
        SizedBox(height: 12),
        scanned
            ? Text('已扫码，请在手机端确认', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            : Text('请使用移动端扫一扫登录'),
        if (onRefresh != null) ...[
          SizedBox(height: 8),
          TextButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('刷新二维码'),
            onPressed: onRefresh,
          ),
        ],
      ],
    );
  }
}
