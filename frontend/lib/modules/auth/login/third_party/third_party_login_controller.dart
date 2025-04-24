import 'package:flutter/material.dart';

class ThirdPartyLoginController extends ChangeNotifier {
  // 支持多种第三方（微信、QQ、Apple、Google等）
  void loginWithProvider(String provider) {
    // 目前本地模拟，后续可接入API
    debugPrint('模拟第三方登录: $provider');
    notifyListeners();
  }
}
