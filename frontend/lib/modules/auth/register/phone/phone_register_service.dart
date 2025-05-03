import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';

class PhoneRegisterService {
  // 本地生成6位验证码
  static String generateLocalCode() {
    final rand = List.generate(6, (index) => (DateTime.now().millisecondsSinceEpoch + index * 37) % 10);
    return rand.join();
  }

  // 检查手机号是否已注册
  static Future<Map<String, dynamic>> checkPhoneExists(String phone) async {
    debugPrint('检查手机号是否已注册: $phone');
    try {
      final response = await Api.checkExists(type: 'phone', target: phone);
      return response;
    } catch (e) {
      debugPrint('检查手机号是否已注册异常: $e');
      return {
        'success': false,
        'msg': '检查手机号失败，请检查网络连接',
        'data': {'exists': false}, // 默认返回不存在，避免阻止用户继续
      };
    }
  }

  // 发送验证码
  static Future<Map<String, dynamic>> sendVerificationCode(String phone) async {
    debugPrint('发送手机验证码: $phone');
    try {
      // 首先检查手机号是否已注册
      final checkResp = await checkPhoneExists(phone);
      if (checkResp['success'] == true && checkResp['data']['exists'] == true) {
        return {
          'success': false,
          'msg': '该手机号已被注册',
        };
      }

      // 发送验证码
      final response = await Api.getSMSVerificationCode(phone: phone);
      return response;
    } catch (e) {
      debugPrint('发送手机验证码异常: $e');
      return {
        'success': false,
        'msg': '发送验证码失败，请检查网络连接',
      };
    }
  }
}
