import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';

class EmailRegisterService {
  static String generateLocalCode() {
    final rand = List.generate(6, (index) => (DateTime.now().millisecondsSinceEpoch + index * 43) % 10);
    return rand.join();
  }

  // 检查邮箱是否已注册
  static Future<Map<String, dynamic>> checkEmailExists(String email) async {
    debugPrint('检查邮箱是否已注册: $email');
    try {
      final response = await Api.checkExists(type: 'email', target: email);
      return response;
    } catch (e) {
      debugPrint('检查邮箱是否已注册异常: $e');
      return {
        'success': false,
        'msg': '检查邮箱失败，请检查网络连接',
        'data': {'exists': false}, // 默认返回不存在，避免阻止用户继续
      };
    }
  }

  // 发送验证码
  static Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    debugPrint('发送邮箱验证码: $email');
    try {
      // 首先检查邮箱是否已注册
      final checkResp = await checkEmailExists(email);
      if (checkResp['success'] == true && checkResp['data']['exists'] == true) {
        return {
          'success': false,
          'msg': '该邮箱已被注册',
        };
      }

      // 发送验证码
      final response = await Api.getVerificationCode(type: 'email', target: email);
      return response;
    } catch (e) {
      debugPrint('发送邮箱验证码异常: $e');
      return {
        'success': false,
        'msg': '发送验证码失败，请检查网络连接',
      };
    }
  }
}
