import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/api.dart';

/// 用于自动判断是否已登录并跳转到主界面
class AutoLoginGate extends StatefulWidget {
  final Widget child;
  const AutoLoginGate({required this.child});
  @override
  State<AutoLoginGate> createState() => _AutoLoginGateState();
}

class _AutoLoginGateState extends State<AutoLoginGate> {
  bool _checking = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    try {
      await Persistence.debugPrintAllPrefs();
      final splashMinTime = Future.delayed(const Duration(milliseconds: 600));

      // 不阻塞UI，token检查和动画并行
      final tokenFuture = Persistence.getToken();
      await splashMinTime;
      final token = await tokenFuture;
      debugPrint('[AutoLoginGate] token=$token');

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        // 验证token有效性
        debugPrint('[AutoLoginGate] 验证token有效性');
        final validationResult = await Api.validateToken(token);
        debugPrint('[AutoLoginGate] 验证结果: $validationResult');

        final isValid = validationResult['success'] == true;

        if (!mounted) return;

        setState(() {
          _token = isValid ? token : null;
          _checking = false;
        });

        if (isValid) {
          debugPrint('[AutoLoginGate] token有效，跳转/social');
          Future.microtask(() {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/social');
            }
          });
        } else {
          debugPrint('[AutoLoginGate] token无效，清除token并停留在登录页');
          await Persistence.clearToken();
        }
      } else {
        debugPrint('[AutoLoginGate] 未检测到token，停留在登录页');
        setState(() {
          _token = null;
          _checking = false;
        });
      }
    } catch (e, s) {
      debugPrint('[AutoLoginGate][Error] 自动登录检查异常: $e\n$s');
      if (mounted) {
        setState(() {
          _token = null;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 未登录，显示原始登录/注册页
    return widget.child;
  }
}
