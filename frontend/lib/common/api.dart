import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const String _base = 'http://localhost:3001/api';

  // 获取验证码图片
  static Future<Map<String, dynamic>> getCaptcha() async {
    final resp = await http.get(Uri.parse('$_base/captcha'));
    return jsonDecode(resp.body);
  }

  // 注册
  static Future<Map<String, dynamic>> register({
    required String account,
    required String password,
    required String captchaId,
    required String captchaValue,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'account': account,
        'password': password,
        'captcha_id': captchaId,
        'captcha_value': captchaValue,
      }),
    );
    return jsonDecode(resp.body);
  }

  // 登录
  static Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'account': account,
        'password': password,
      }),
    );
    return jsonDecode(resp.body);
  }
}
