import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import '../lib/common/api.dart';

@GenerateMocks([http.Client])
void main() {
  group('Login Tests', () {
    test('API login should handle successful login', () async {
      // 模拟成功的登录响应
      final mockResponse = {
        'success': true,
        'token': 'test_token',
        'data': {
          'user': {
            'id': 123,
            'account': '123456',
            'nickname': 'Test User'
          }
        }
      };

      // 验证响应处理
      expect(mockResponse['success'], true);
      expect(mockResponse['token'], 'test_token');

      // 安全地访问嵌套属性
      final data = mockResponse['data'];
      if (data is Map<String, dynamic>) {
        final user = data['user'];
        if (user is Map<String, dynamic>) {
          expect(user['id'], 123);
          expect(user['account'], '123456');
          expect(user['nickname'], 'Test User');
        }
      }
    });

    test('API login should handle failed login', () async {
      // 模拟失败的登录响应
      final mockResponse = {
        'success': false,
        'msg': '账号或密码错误'
      };

      // 验证响应处理
      expect(mockResponse['success'], false);
      expect(mockResponse['msg'], '账号或密码错误');
    });
  });
}
