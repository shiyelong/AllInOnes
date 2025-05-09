import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'config.dart';
import 'persistence.dart';

/// API工具类
/// 用于与后端API交互
class Api {
  // 基础URL
  static String get _base => Config.apiUrl;
  
  // 获取认证头
  static Map<String, String> _getAuthHeaders() {
    final token = Persistence.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }
  
  // 处理响应
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'code': response.statusCode,
          'msg': data['message'] ?? '请求失败',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'code': response.statusCode,
        'msg': '解析响应失败: $e',
      };
    }
  }
  
  // GET请求
  static Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? params}) async {
    try {
      // 构建URL
      var uri = Uri.parse('$_base$path');
      
      // 添加查询参数
      if (params != null && params.isNotEmpty) {
        uri = uri.replace(queryParameters: params.map((key, value) => MapEntry(key, value.toString())));
      }
      
      // 发送请求
      final response = await http.get(
        uri,
        headers: _getAuthHeaders(),
      ).timeout(Duration(milliseconds: Config.requestTimeout));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'msg': '请求失败: $e',
      };
    }
  }
  
  // POST请求
  static Future<Map<String, dynamic>> _post(String path, {Map<String, dynamic>? data}) async {
    try {
      // 构建URL
      final uri = Uri.parse('$_base$path');
      
      // 发送请求
      final response = await http.post(
        uri,
        headers: _getAuthHeaders(),
        body: data != null ? jsonEncode(data) : null,
      ).timeout(Duration(milliseconds: Config.requestTimeout));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'msg': '请求失败: $e',
      };
    }
  }
  
  // PUT请求
  static Future<Map<String, dynamic>> _put(String path, {Map<String, dynamic>? data}) async {
    try {
      // 构建URL
      final uri = Uri.parse('$_base$path');
      
      // 发送请求
      final response = await http.put(
        uri,
        headers: _getAuthHeaders(),
        body: data != null ? jsonEncode(data) : null,
      ).timeout(Duration(milliseconds: Config.requestTimeout));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'msg': '请求失败: $e',
      };
    }
  }
  
  // DELETE请求
  static Future<Map<String, dynamic>> _delete(String path, {Map<String, dynamic>? data}) async {
    try {
      // 构建URL
      final uri = Uri.parse('$_base$path');
      
      // 发送请求
      final response = await http.delete(
        uri,
        headers: _getAuthHeaders(),
        body: data != null ? jsonEncode(data) : null,
      ).timeout(Duration(milliseconds: Config.requestTimeout));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'msg': '请求失败: $e',
      };
    }
  }
  
  // 上传文件
  static Future<Map<String, dynamic>> _uploadFile(String path, String filePath, String field, {Map<String, String>? fields}) async {
    try {
      // 构建URL
      final uri = Uri.parse('$_base$path');
      
      // 创建multipart请求
      final request = http.MultipartRequest('POST', uri);
      
      // 添加认证头
      final headers = _getAuthHeaders();
      request.headers.addAll(headers);
      
      // 添加文件
      final file = File(filePath);
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      
      final multipartFile = http.MultipartFile(
        field,
        fileStream,
        fileLength,
        filename: p.basename(filePath),
      );
      
      request.files.add(multipartFile);
      
      // 添加其他字段
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      // 发送请求
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'msg': '上传文件失败: $e',
      };
    }
  }
  
  /// 登录
  static Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    return await _post('/auth/login', data: {
      'account': account,
      'password': password,
    });
  }
  
  /// 注册
  static Future<Map<String, dynamic>> register({
    required String account,
    required String password,
    required String nickname,
    required String verificationCode,
  }) async {
    return await _post('/auth/register', data: {
      'account': account,
      'password': password,
      'nickname': nickname,
      'verification_code': verificationCode,
    });
  }
  
  /// 发送验证码
  static Future<Map<String, dynamic>> sendVerificationCode({
    required String account,
    required String type, // 'register', 'reset_password', 'bind_email', 'bind_phone'
  }) async {
    return await _post('/auth/verification_code', data: {
      'account': account,
      'type': type,
    });
  }
  
  /// 重置密码
  static Future<Map<String, dynamic>> resetPassword({
    required String account,
    required String newPassword,
    required String verificationCode,
  }) async {
    return await _post('/auth/reset_password', data: {
      'account': account,
      'new_password': newPassword,
      'verification_code': verificationCode,
    });
  }
  
  /// 修改密码
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return await _post('/user/change_password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }
  
  /// 获取用户信息
  static Future<Map<String, dynamic>> getUserInfo() async {
    return await _get('/user/info');
  }
  
  /// 更新用户信息
  static Future<Map<String, dynamic>> updateUserInfo({
    String? nickname,
    String? avatar,
    String? gender,
    String? birthday,
    String? signature,
  }) async {
    final data = <String, dynamic>{};
    
    if (nickname != null) data['nickname'] = nickname;
    if (avatar != null) data['avatar'] = avatar;
    if (gender != null) data['gender'] = gender;
    if (birthday != null) data['birthday'] = birthday;
    if (signature != null) data['signature'] = signature;
    
    return await _post('/user/update', data: data);
  }
  
  /// 上传头像
  static Future<Map<String, dynamic>> uploadAvatar({
    required String filePath,
  }) async {
    return await _uploadFile('/user/avatar', filePath, 'avatar');
  }
  
  /// 获取好友列表
  static Future<Map<String, dynamic>> getFriends() async {
    return await _get('/friend/list');
  }
  
  /// 搜索用户
  static Future<Map<String, dynamic>> searchUser({
    required String keyword,
  }) async {
    return await _get('/user/search', params: {
      'keyword': keyword,
    });
  }
  
  /// 添加好友
  static Future<Map<String, dynamic>> addFriend({
    required String userId,
    String? verifyMessage,
  }) async {
    return await _post('/friend/add', data: {
      'user_id': userId,
      'verify_message': verifyMessage,
    });
  }
  
  /// 接受好友请求
  static Future<Map<String, dynamic>> acceptFriendRequest({
    required String requestId,
  }) async {
    return await _post('/friend/accept', data: {
      'request_id': requestId,
    });
  }
  
  /// 拒绝好友请求
  static Future<Map<String, dynamic>> rejectFriendRequest({
    required String requestId,
  }) async {
    return await _post('/friend/reject', data: {
      'request_id': requestId,
    });
  }
  
  /// 删除好友
  static Future<Map<String, dynamic>> deleteFriend({
    required String userId,
  }) async {
    return await _post('/friend/delete', data: {
      'user_id': userId,
    });
  }
  
  /// 获取好友请求列表
  static Future<Map<String, dynamic>> getFriendRequests() async {
    return await _get('/friend/requests');
  }
  
  /// 获取聊天记录
  static Future<Map<String, dynamic>> getChatHistory({
    required String targetId,
    String? lastMessageId,
    int? limit,
  }) async {
    final params = <String, dynamic>{
      'target_id': targetId,
    };
    
    if (lastMessageId != null) params['last_message_id'] = lastMessageId;
    if (limit != null) params['limit'] = limit;
    
    return await _get('/chat/history', params: params);
  }
  
  /// 发送消息
  static Future<Map<String, dynamic>> sendMessage({
    required String targetId,
    required String content,
    required String type, // 'text', 'image', 'video', 'file', 'voice', 'location'
  }) async {
    return await _post('/chat/send', data: {
      'target_id': targetId,
      'content': content,
      'type': type,
    });
  }
  
  /// 根据ID获取用户信息
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    return await _get('/user/$userId');
  }
}
