import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// 通用本地存储操作封装
class Persistence {
  /// 打印所有 SharedPreferences 键值，便于调试本地存储
  static Future<void> debugPrintAllPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      debugPrint('[Persistence][AllPrefs] keys: $keys');
      for (var key in keys) {
        debugPrint('[Persistence][AllPrefs] $key = [32m${prefs.get(key)}[0m');
      }
    } catch (e, s) {
      debugPrint('[Persistence][Error] 枚举所有prefs异常: $e\n$s');
    }
  }
  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      debugPrint('[Persistence] 已保存token: $token');
    } catch (e, s) {
      debugPrint('[Persistence][Error] 保存token异常: $e\n$s');
    }
  }
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    debugPrint('[Persistence] 读取到token: $token');
    return token;
  }
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}
