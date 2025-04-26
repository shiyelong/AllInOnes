import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:frontend/common/persistence.dart';

class QrLoginService {
  /// 校验二维码code并登录，成功则保存token，返回true，否则false。
  static Future<bool> loginWithQrCode(String code) async {
    try {
      // TODO: Replace with your actual backend API endpoint
      final url = Uri.parse('https://your-backend-api.com/api/qr-login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        if (token != null && token is String) {
          await Persistence.saveToken(token);
          debugPrint('[QrLoginService] 已保存token: $token');
          return true;
        }
      }
    } catch (e) {
      // Log or handle error
    }
    return false;
  }
}
