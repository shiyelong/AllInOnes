import 'package:flutter/material.dart';
import 'scan_page.dart';
import 'enhanced_scan_page.dart';
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
              builder: (ctx) => EnhancedQrScanPage(
                title: '扫一扫登录',
                description: '扫描二维码登录，无需输入账号密码',
                onScan: (code, position) {
                  // 显示加载对话框
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('正在登录...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  // 调用登录服务
                  QrLoginService.loginWithQrCode(code).then((success) {
                    Navigator.of(context, rootNavigator: true).pop(); // 关闭loading
                    if (success) {
                      // 登录成功，跳转到社交页面
                      Navigator.of(context).pushReplacementNamed('/social');
                    } else {
                      // 登录失败，显示错误消息
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('二维码登录失败，请重试'),
                          backgroundColor: Colors.red,
                          action: SnackBarAction(
                            label: '重试',
                            textColor: Colors.white,
                            onPressed: () {
                              Navigator.pop(context); // 关闭当前页面
                              // 重新打开扫码页面
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => EnhancedQrScanPage(
                                    title: '扫一扫登录',
                                    description: '扫描二维码登录，无需输入账号密码',
                                    onScan: (code, position) {
                                      // 递归调用，处理重试逻辑
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) => Center(child: CircularProgressIndicator()),
                                      );
                                      QrLoginService.loginWithQrCode(code).then((success) {
                                        Navigator.of(context, rootNavigator: true).pop();
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
                        ),
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
