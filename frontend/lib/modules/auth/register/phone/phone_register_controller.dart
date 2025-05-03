import 'package:flutter/material.dart';
import 'phone_register_service.dart';
import 'phone_register_validator.dart';

class PhoneRegisterController extends ChangeNotifier {
  String phone = '';
  String code = '';
  String password = '';
  bool isLoading = false;
  bool isSendingCode = false;
  String? error;
  String generatedCode = '';

  // 检查手机号是否已注册
  Future<Map<String, dynamic>> checkPhoneExists() async {
    if (phone.isEmpty) {
      error = '请输入手机号';
      notifyListeners();
      return {'success': false, 'msg': '请输入手机号'};
    }

    // 验证手机号格式
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(phone)) {
      error = '手机号格式不正确';
      notifyListeners();
      return {'success': false, 'msg': '手机号格式不正确'};
    }

    return await PhoneRegisterService.checkPhoneExists(phone);
  }

  // 发送验证码
  Future<Map<String, dynamic>> sendCode() async {
    if (isSendingCode) return {'success': false, 'msg': '正在发送验证码，请稍候'};

    isSendingCode = true;
    error = null;
    notifyListeners();

    try {
      // 检查手机号是否已注册并发送验证码
      final response = await PhoneRegisterService.sendVerificationCode(phone);

      if (response['success'] == true) {
        // 如果后端返回了验证码（开发环境），保存它
        if (response['code'] != null) {
          generatedCode = response['code'];
        } else if (response['data']?['verification_code'] != null) {
          generatedCode = response['data']['verification_code'];
        } else {
          // 否则生成本地验证码（仅用于模拟）
          generatedCode = PhoneRegisterService.generateLocalCode();
        }
        debugPrint('手机验证码: $generatedCode');
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
