import 'package:flutter/material.dart';
import 'phone_register_service.dart';
import 'phone_register_validator.dart';

class PhoneRegisterController extends ChangeNotifier {
  String phone = '';
  String code = '';
  String password = '';
  bool isLoading = false;
  String? error;
  String generatedCode = '';

  // 本地生成验证码逻辑
  void sendCode() {
    generatedCode = PhoneRegisterService.generateLocalCode();
    // 这里可以弹窗或打印模拟验证码
    debugPrint('模拟验证码: $generatedCode');
    notifyListeners();
  }

  bool validateAndRegister() {
    error = PhoneRegisterValidator.validate(phone, code, password, generatedCode);
    if (error != null) {
      notifyListeners();
      return false;
    }
    // 注册成功逻辑（本地模拟）
    isLoading = true;
    notifyListeners();
    Future.delayed(Duration(seconds: 1), () {
      isLoading = false;
      notifyListeners();
    });
    return true;
  }
}
