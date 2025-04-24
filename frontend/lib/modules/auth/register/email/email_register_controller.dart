import 'package:flutter/material.dart';
import 'email_register_service.dart';
import 'email_register_validator.dart';

class EmailRegisterController extends ChangeNotifier {
  String email = '';
  String code = '';
  String password = '';
  bool isLoading = false;
  String? error;
  String generatedCode = '';

  void sendCode() {
    generatedCode = EmailRegisterService.generateLocalCode();
    debugPrint('模拟邮箱验证码: $generatedCode');
    notifyListeners();
  }

  bool validateAndRegister() {
    error = EmailRegisterValidator.validate(email, code, password, generatedCode);
    if (error != null) {
      notifyListeners();
      return false;
    }
    isLoading = true;
    notifyListeners();
    Future.delayed(Duration(seconds: 1), () {
      isLoading = false;
      notifyListeners();
    });
    return true;
  }
}
