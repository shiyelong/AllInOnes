import 'package:flutter/material.dart';
import 'email_register_service.dart';
import 'email_register_validator.dart';

class EmailRegisterController extends ChangeNotifier {
  String email = '';
  String code = '';
  String password = '';
  bool isLoading = false;
  bool isSendingCode = false;
  String? error;
  String generatedCode = '';

  // 检查邮箱是否已注册
  Future<Map<String, dynamic>> checkEmailExists() async {
    if (email.isEmpty) {
      error = '请输入邮箱';
      notifyListeners();
      return {'success': false, 'msg': '请输入邮箱'};
    }

    // 验证邮箱格式
    final emailRegex = RegExp(r'^[\w-.]+@[\w-]+\.[a-zA-Z]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      error = '邮箱格式不正确';
      notifyListeners();
      return {'success': false, 'msg': '邮箱格式不正确'};
    }

    return await EmailRegisterService.checkEmailExists(email);
  }

  // 发送验证码
  Future<Map<String, dynamic>> sendCode() async {
    if (isSendingCode) return {'success': false, 'msg': '正在发送验证码，请稍候'};

    isSendingCode = true;
    error = null;
    notifyListeners();

    try {
      // 检查邮箱是否已注册并发送验证码
      final response = await EmailRegisterService.sendVerificationCode(email);

      if (response['success'] == true) {
        // 如果后端返回了验证码（开发环境），保存它
        if (response['code'] != null) {
          generatedCode = response['code'];
        } else {
          // 否则生成本地验证码（仅用于模拟）
          generatedCode = EmailRegisterService.generateLocalCode();
        }
        debugPrint('邮箱验证码: $generatedCode');
      } else {
        error = response['msg'] ?? '发送验证码失败';
      }

      isSendingCode = false;
      notifyListeners();
      return response;
    } catch (e) {
      debugPrint('发送验证码异常: $e');
      error = '网络异常，请稍后重试';
      isSendingCode = false;
      notifyListeners();
      return {'success': false, 'msg': '网络异常，请稍后重试'};
    }
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
