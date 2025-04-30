import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';

enum AutoLoginResult { success, invalid, none }

Future<AutoLoginResult> autoLoginDebug(BuildContext context) async {
  final token = await Persistence.getToken();
  debugPrint('[AutoLoginDebug] token=$token');
  if (token != null && token.isNotEmpty) {
    final resp = await Api.validateToken(token);
    debugPrint('[AutoLoginDebug] validate resp=$resp');
    if (resp['success'] == true) {
      debugPrint('[AutoLoginDebug] token有效，进入主页面');
      return AutoLoginResult.success;
    } else {
      debugPrint('[AutoLoginDebug] token无效，跳转登录页');
      return AutoLoginResult.invalid;
    }
  } else {
    debugPrint('[AutoLoginDebug] 未检测到token，停留在登录页');
    return AutoLoginResult.none;
  }
}
