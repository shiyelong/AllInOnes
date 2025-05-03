import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResetAllData {
  /// 清除所有 SharedPreferences 数据
  static Future<void> resetAll(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 清除所有数据
      await prefs.clear();
      
      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理所有数据，请重新登录')),
      );
      
      // 延迟一秒后重启应用
      Future.delayed(Duration(seconds: 1), () {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      });
    } catch (e) {
      debugPrint('清理数据出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理数据失败: $e')),
      );
    }
  }
}
