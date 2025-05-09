import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'persistence.dart';
import 'text_sanitizer.dart';

/// API工具类
/// 用于与后端API交互
class Api {
  // 基础URL
  static const String _base = 'http://localhost:3001/api';
  static const String baseUrl = 'http://localhost:3001';

  /// 获取完整的资源URL
  static String getFullUrl(String url) {
    if (url.isEmpty) return url;

    // 如果已经是完整URL，直接返回
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // 如果是相对路径，添加baseUrl前缀
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }

    // 其他情况，添加baseUrl和/前缀
    return '$baseUrl/$url';
  }

  // 获取带有认证的请求头
  static Map<String, String> _getAuthHeaders() {
    final token = Persistence.getToken();
    debugPrint('[API] 获取认证头，token: $token');

    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    debugPrint('[API] 认证头: $headers');
    return headers;
  }

  // 清理响应数据中的文本字段
  static void _sanitizeResponseData(dynamic data) {
    if (data == null) return;

    if (data is Map) {
      // 处理 Map 类型的数据
      for (var key in data.keys.toList()) {
        var value = data[key];

        if (value is String) {
          // 清理字符串值
          data[key] = TextSanitizer.sanitize(value);
        } else if (value is Map || value is List) {
          // 递归处理嵌套的 Map 或 List
          _sanitizeResponseData(value);
        }
      }
    } else if (data is List) {
      // 处理 List 类型的数据
      for (int i = 0; i < data.length; i++) {
        var item = data[i];

        if (item is String) {
          // 清理字符串值
          data[i] = TextSanitizer.sanitize(item);
        } else if (item is Map || item is List) {
          // 递归处理嵌套的 Map 或 List
          _sanitizeResponseData(item);
        }
      }
    }
  }

  // 通用GET请求
  static Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? queryParams}) async {
    final headers = _getAuthHeaders();
    final uri = Uri.parse('$_base$path').replace(queryParameters: queryParams);

    debugPrint('[API] 发送GET请求: $uri');

    try {
      final resp = await http.get(uri, headers: headers);
      return _handleResponse(resp);
    } catch (e) {
      debugPrint('[API] GET请求失败: $path, 错误: $e');
      return {'success': false, 'msg': '网络请求失败: $e'};
    }
  }

  // 通用POST请求
  static Future<Map<String, dynamic>> _post(String path, {Map<String, dynamic>? data}) async {
    final headers = _getAuthHeaders();
    final uri = Uri.parse('$_base$path');

    debugPrint('[API] 发送POST请求: $uri, 数据: $data');

    try {
      final resp = await http.post(
        uri,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      return _handleResponse(resp);
    } catch (e) {
      debugPrint('[API] POST请求失败: $path, 错误: $e');
      return {'success': false, 'msg': '网络请求失败: $e'};
    }
  }

  // 通用PUT请求
  static Future<Map<String, dynamic>> _put(String path, {Map<String, dynamic>? data}) async {
    final headers = _getAuthHeaders();
    final uri = Uri.parse('$_base$path');

    debugPrint('[API] 发送PUT请求: $uri, 数据: $data');

    try {
      final resp = await http.put(
        uri,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      return _handleResponse(resp);
    } catch (e) {
      debugPrint('[API] PUT请求失败: $path, 错误: $e');
      return {'success': false, 'msg': '网络请求失败: $e'};
    }
  }

  // 通用DELETE请求
  static Future<Map<String, dynamic>> _delete(String path, {Map<String, dynamic>? data}) async {
    final headers = _getAuthHeaders();
    final uri = Uri.parse('$_base$path');

    debugPrint('[API] 发送DELETE请求: $uri, 数据: $data');

    try {
      final resp = await http.delete(
        uri,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      return _handleResponse(resp);
    } catch (e) {
      debugPrint('[API] DELETE请求失败: $path, 错误: $e');
      return {'success': false, 'msg': '网络请求失败: $e'};
    }
  }

  // 处理响应
  static Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('[API] 处理响应: 状态码=${response.statusCode}, 内容长度=${response.body.length}');

    try {
      // 检查状态码
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 成功的响应
        final data = jsonDecode(response.body);

        // 清理响应数据中的文本字段
        _sanitizeResponseData(data);

        debugPrint('[API] 响应解析成功: $data');
        return data;
      } else if (response.statusCode == 401) {
        // 处理401未授权错误
        debugPrint('[API] 未授权错误 (401)');
        Persistence.clearToken();

        try {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'msg': data['msg'] ?? '未授权，请重新登录',
            'status': 401,
          };
        } catch (e) {
          return {
            'success': false,
            'msg': '未授权，请重新登录',
            'status': 401,
          };
        }
      } else if (response.statusCode == 404) {
        // 处理404未找到错误
        debugPrint('[API] 资源未找到 (404): ${response.request?.url}');
        return {
          'success': false,
          'msg': '请求的资源不存在',
          'status': 404,
        };
      } else {
        // 其他错误
        debugPrint('[API] HTTP错误: ${response.statusCode}');
        try {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'msg': data['msg'] ?? '请求失败: ${response.statusCode}',
            'status': response.statusCode,
          };
        } catch (e) {
          return {
            'success': false,
            'msg': '请求失败: ${response.statusCode}',
            'status': response.statusCode,
          };
        }
      }
    } catch (e) {
      debugPrint('[API] 响应解析失败: $e');
      return {
        'success': false,
        'msg': '解析响应失败: ${response.body}',
        'status': response.statusCode,
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

  /// 验证Token
  static Future<Map<String, dynamic>> validateToken(String token) async {
    try {
      debugPrint('[API] 验证token: $token');
      // 使用通用的POST方法，它会自动处理错误和响应
      final resp = await _post('/validate-token', data: {});
      debugPrint('[API] 验证token响应: $resp');
      return resp;
    } catch (e) {
      debugPrint('[API] 验证token异常: $e');
      return {'success': false, 'msg': '网络请求失败: $e'};
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

  /// 登录（兼容旧版本）
  static Future<Map<String, dynamic>> loginNew({
    required String account,
    required String password,
  }) async {
    return await login(account: account, password: password);
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

  /// 注册（兼容旧版本）
  static Future<Map<String, dynamic>> registerNew({
    required String account,
    required String password,
    required String nickname,
    required String verificationCode,
    String? captchaId,
    String? captchaCode,
  }) async {
    final data = {
      'account': account,
      'password': password,
      'nickname': nickname,
      'verification_code': verificationCode,
    };

    if (captchaId != null) data['captcha_id'] = captchaId;
    if (captchaCode != null) data['captcha_code'] = captchaCode;

    return await _post('/auth/register', data: data);
  }

  /// 获取图形验证码
  static Future<Map<String, dynamic>> getCaptcha() async {
    return await _get('/auth/captcha');
  }

  /// 检查账号是否存在
  static Future<Map<String, dynamic>> checkExists({
    required String type, // 'email' 或 'phone'
    required String target,
  }) async {
    return await _get('/auth/check_exists', queryParams: {
      'type': type,
      'target': target,
    });
  }

  /// 获取短信验证码
  static Future<Map<String, dynamic>> getSMSVerificationCode({
    required String phone,
  }) async {
    return await _post('/auth/sms_code', data: {
      'phone': phone,
    });
  }

  /// 获取邮箱验证码
  static Future<Map<String, dynamic>> getVerificationCode({
    required String email,
    String? type,
  }) async {
    final data = {
      'email': email,
    };

    if (type != null) data['type'] = type;

    return await _post('/auth/email_code', data: data);
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

  /// 获取用户信息
  static Future<Map<String, dynamic>> getUserInfo() async {
    return await _get('/user/info');
  }

  /// 更新用户信息
  static Future<Map<String, dynamic>> updateUserInfo(Map<String, dynamic> data) async {
    return await _post('/user/update', data: data);
  }

  /// 根据ID获取用户信息
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    return await _get('/user/$userId');
  }

  /// 搜索用户
  static Future<Map<String, dynamic>> searchUser({
    required String keyword,
  }) async {
    return await _get('/user/search', queryParams: {
      'keyword': keyword,
    });
  }

  /// 搜索用户（兼容旧版本）
  static Future<Map<String, dynamic>> searchUsers({
    required String keyword,
    int? page,
    int? pageSize,
  }) async {
    final params = <String, dynamic>{
      'keyword': keyword,
    };

    if (page != null) params['page'] = page.toString();
    if (pageSize != null) params['page_size'] = pageSize.toString();

    return await _get('/user/search', queryParams: params);
  }

  /// 获取好友列表
  static Future<Map<String, dynamic>> getFriends() async {
    return await _get('/friend/list');
  }

  /// 获取好友列表（兼容旧版本）
  static Future<Map<String, dynamic>> getFriendList() async {
    return await getFriends();
  }

  /// 获取好友列表（兼容旧版本2）
  static Future<Map<String, dynamic>> getFriendsList({String? userId}) async {
    return await getFriends();
  }

  /// 添加好友
  static Future<Map<String, dynamic>> addFriend({
    required String targetId,
    String? message,
  }) async {
    final data = <String, dynamic>{
      'target_id': targetId,
    };

    if (message != null) {
      data['message'] = message;
    }

    return await _post('/friend/add', data: data);
  }

  /// 同意好友请求
  static Future<Map<String, dynamic>> agreeFriendRequest({
    required String requestId,
  }) async {
    return await _post('/friend/request/agree', data: {
      'request_id': requestId,
    });
  }

  /// 拒绝好友请求
  static Future<Map<String, dynamic>> rejectFriendRequest({
    required String requestId,
  }) async {
    return await _post('/friend/request/reject', data: {
      'request_id': requestId,
    });
  }

  /// 批量同意好友请求
  static Future<Map<String, dynamic>> batchAgreeFriendRequests({
    required List<String> requestIds,
  }) async {
    return await _post('/friend/request/batch/agree', data: {
      'request_ids': requestIds,
    });
  }

  /// 批量拒绝好友请求
  static Future<Map<String, dynamic>> batchRejectFriendRequests({
    required List<String> requestIds,
  }) async {
    return await _post('/friend/request/batch/reject', data: {
      'request_ids': requestIds,
    });
  }

  /// 拉黑好友
  static Future<Map<String, dynamic>> blockFriend({
    required String friendId,
  }) async {
    return await _post('/friend/block', data: {
      'friend_id': friendId,
    });
  }

  /// 取消拉黑好友
  static Future<Map<String, dynamic>> unblockFriend({
    required String friendId,
  }) async {
    return await _post('/friend/unblock', data: {
      'friend_id': friendId,
    });
  }

  /// 获取好友添加方式
  static Future<Map<String, dynamic>> getFriendAddMode({
    String? userId,
  }) async {
    final params = <String, dynamic>{};

    if (userId != null) {
      params['user_id'] = userId;
    }

    return await _get('/friend/add/mode', queryParams: params);
  }

  /// 设置好友添加方式
  static Future<Map<String, dynamic>> setFriendAddMode({
    required String mode, // 'all', 'verify', 'none'
  }) async {
    return await _post('/friend/add/mode', data: {
      'mode': mode,
    });
  }

  /// 获取推荐好友
  static Future<Map<String, dynamic>> getRecommendedFriends({
    int? page,
    int? pageSize,
    String? gender,
  }) async {
    final params = <String, dynamic>{};

    if (page != null) params['page'] = page.toString();
    if (pageSize != null) params['page_size'] = pageSize.toString();
    if (gender != null) params['gender'] = gender;

    return await _get('/friend/recommend', queryParams: params);
  }

  /// 获取好友请求列表
  static Future<Map<String, dynamic>> getFriendRequests({String? userId, int page = 1, int pageSize = 20}) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (userId != null) {
      params['user_id'] = userId;
    }

    return await _get('/friend/requests', queryParams: params);
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

    return await _get('/chat/history', queryParams: params);
  }

  /// 获取聊天记录（兼容旧版本）
  static Future<Map<String, dynamic>> getMessagesByUser({
    required String targetId,
    String? userId,
    String? lastMessageId,
    int? limit,
  }) async {
    return await getChatHistory(
      targetId: targetId,
      lastMessageId: lastMessageId,
      limit: limit,
    );
  }

  /// 发送消息
  static Future<Map<String, dynamic>> sendMessage({
    required String targetId,
    required String content,
    required String type, // 'text', 'image', 'video', 'file', 'voice', 'location'
    String? fromId,
  }) async {
    final data = {
      'target_id': targetId,
      'content': content,
      'type': type,
    };

    if (fromId != null) {
      data['from_id'] = fromId;
    }

    return await _post('/chat/send', data: data);
  }

  /// 标记消息为已读
  static Future<Map<String, dynamic>> markMessagesAsRead({
    required String targetId,
    required String lastMessageId,
  }) async {
    return await _post('/chat/read', data: {
      'target_id': targetId,
      'last_message_id': lastMessageId,
    });
  }

  /// 撤回消息
  static Future<Map<String, dynamic>> recallMessage({
    required String messageId,
  }) async {
    return await _post('/chat/recall', data: {
      'message_id': messageId,
    });
  }

  /// 转发消息
  static Future<Map<String, dynamic>> forwardMessage({
    required String messageId,
    required String targetId,
    required String type, // "user" 或 "group"
  }) async {
    return await _post('/chat/forward', data: {
      'message_id': messageId,
      'target_id': targetId,
      'type': type,
    });
  }

  /// 获取会话列表
  static Future<Map<String, dynamic>> getConversations() async {
    return await _get('/chat/conversations');
  }

  /// 删除会话
  static Future<Map<String, dynamic>> deleteConversation({
    required String targetId,
  }) async {
    return await _post('/chat/conversation/delete', data: {
      'target_id': targetId,
    });
  }

  /// 删除消息
  static Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
  }) async {
    return await _post('/message/delete', data: {
      'message_id': messageId,
    });
  }

  /// 获取群组列表
  static Future<Map<String, dynamic>> getGroups() async {
    return await _get('/group/list');
  }

  /// 获取群组列表（兼容旧版本）
  static Future<Map<String, dynamic>> getGroupList({String? userId}) async {
    return await getGroups();
  }

  /// 获取群聊记录
  static Future<Map<String, dynamic>> getGroupChatHistory({
    required String groupId,
    String? lastMessageId,
    int? limit,
  }) async {
    final params = <String, dynamic>{
      'group_id': groupId,
    };

    if (lastMessageId != null) params['last_message_id'] = lastMessageId;
    if (limit != null) params['limit'] = limit;

    return await _get('/group/chat/history', queryParams: params);
  }

  /// 获取群聊记录（兼容旧版本）
  static Future<Map<String, dynamic>> getGroupMessages({
    required String groupId,
    String? lastMessageId,
    int? limit,
    String? offset,
  }) async {
    return await getGroupChatHistory(
      groupId: groupId,
      lastMessageId: lastMessageId,
      limit: limit,
    );
  }

  /// 发送群聊消息
  static Future<Map<String, dynamic>> sendGroupMessage({
    required String groupId,
    required String content,
    required String type,
    List<String>? mentionedUsers,
    String? extra,
  }) async {
    final data = {
      'group_id': groupId,
      'content': content,
      'type': type,
    };

    if (mentionedUsers != null && mentionedUsers.isNotEmpty) {
      data['mentioned_users'] = mentionedUsers.join(',');
    }

    if (extra != null && extra.isNotEmpty) {
      data['extra'] = extra;
    }

    return await _post('/group/chat/send', data: data);
  }

  /// 标记群聊消息为已读
  static Future<Map<String, dynamic>> markGroupMessagesAsRead({
    required String groupId,
    required String lastMessageId,
  }) async {
    return await _post('/group/chat/read', data: {
      'group_id': groupId,
      'last_message_id': lastMessageId,
    });
  }

  /// 撤回群聊消息
  static Future<Map<String, dynamic>> recallGroupMessage({
    required String messageId,
  }) async {
    return await _post('/group/chat/recall', data: {
      'message_id': messageId,
    });
  }

  /// 获取群成员列表
  static Future<Map<String, dynamic>> getGroupMembers({
    required String groupId,
  }) async {
    return await _get('/group/members', queryParams: {
      'group_id': groupId,
    });
  }

  /// 创建群组
  static Future<Map<String, dynamic>> createGroup({
    required String name,
    required String avatar,
    required List<String> memberIds,
    String? ownerId,
  }) async {
    final data = {
      'name': name,
      'avatar': avatar,
      'member_ids': memberIds,
    };

    if (ownerId != null) {
      data['owner_id'] = ownerId;
    }

    return await _post('/group/create', data: data);
  }

  /// 添加群成员
  static Future<Map<String, dynamic>> addGroupMember({
    required String groupId,
    required String userId,
  }) async {
    return await _post('/group/member/add', data: {
      'group_id': groupId,
      'user_id': userId,
    });
  }

  /// 移除群成员
  static Future<Map<String, dynamic>> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    return await _post('/group/member/remove', data: {
      'group_id': groupId,
      'user_id': userId,
    });
  }

  /// 退出群组
  static Future<Map<String, dynamic>> quitGroup({
    required String groupId,
  }) async {
    return await _post('/group/quit', data: {
      'group_id': groupId,
    });
  }

  /// 解散群组
  static Future<Map<String, dynamic>> dismissGroup({
    required String groupId,
  }) async {
    return await _post('/group/dismiss', data: {
      'group_id': groupId,
    });
  }

  /// 上传图片
  static Future<Map<String, dynamic>> uploadImage({
    required String filePath,
    required String targetId,
    String? fromId,
  }) async {
    final fields = <String, String>{
      'target_id': targetId,
    };

    if (fromId != null) {
      fields['from_id'] = fromId;
    }

    return await _uploadFile('/message/image', filePath, 'image', fields: fields);
  }

  /// 上传视频
  static Future<Map<String, dynamic>> uploadVideo({
    required String filePath,
    required String targetId,
    int duration = 0,
    String? thumbnailPath,
    String? fromId,
  }) async {
    final fields = <String, String>{
      'target_id': targetId,
      'duration': duration.toString(),
    };

    if (thumbnailPath != null) {
      fields['thumbnail_path'] = thumbnailPath;
    }

    if (fromId != null) {
      fields['from_id'] = fromId;
    }

    return await _uploadFile('/message/video', filePath, 'video', fields: fields);
  }

  /// 上传文件
  static Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    required String targetId,
    required String fileName,
    String? fileType,
    String? fromId,
  }) async {
    final fields = <String, String>{
      'target_id': targetId,
      'file_name': fileName,
    };

    if (fileType != null) {
      fields['file_type'] = fileType;
    }

    if (fromId != null) {
      fields['from_id'] = fromId;
    }

    return await _uploadFile('/message/file', filePath, 'file', fields: fields);
  }

  /// 上传文件（兼容旧版本）
  static Future<Map<String, dynamic>> uploadFileCompat(String filePath, String fileType) async {
    return await uploadFile(filePath: filePath, targetId: '0', fileName: 'file', fileType: fileType);
  }

  /// 上传文件（兼容旧版本2）
  static Future<Map<String, dynamic>> uploadFileOld(String filePath, String fileType) async {
    return await uploadFile(filePath: filePath, targetId: '0', fileName: 'file', fileType: fileType);
  }

  /// 上传语音消息
  static Future<Map<String, dynamic>> uploadVoiceMessage({
    required String filePath,
    required int duration,
  }) async {
    return await _uploadFile('/message/voice', filePath, 'voice', fields: {
      'duration': duration.toString(),
    });
  }

  /// 获取语音消息
  static Future<Map<String, dynamic>> getVoiceMessage({
    required String messageId,
  }) async {
    return await _get('/message/voice', queryParams: {
      'message_id': messageId,
    });
  }

  /// 发起语音通话
  static Future<Map<String, dynamic>> initiateVoiceCall({
    required String targetId,
  }) async {
    return await _post('/call/voice/initiate', data: {
      'target_id': targetId,
    });
  }

  /// 发起语音通话（兼容旧版本）
  static Future<Map<String, dynamic>> startVoiceCallWithId({
    required String targetId,
  }) async {
    return await initiateVoiceCall(targetId: targetId);
  }

  /// 接受语音通话
  static Future<Map<String, dynamic>> acceptVoiceCall({
    required String callId,
    String? fromId,
  }) async {
    final data = {
      'call_id': callId,
    };

    if (fromId != null) {
      data['from_id'] = fromId;
    }

    return await _post('/call/voice/accept', data: data);
  }

  /// 拒绝语音通话
  static Future<Map<String, dynamic>> rejectVoiceCall({
    required String callId,
  }) async {
    return await _post('/call/voice/reject', data: {
      'call_id': callId,
    });
  }

  /// 拒绝语音通话（兼容旧版本）
  static Future<Map<String, dynamic>> rejectVoiceCallWithId({
    required String callId,
  }) async {
    return await rejectVoiceCall(callId: callId);
  }

  /// 结束语音通话
  static Future<Map<String, dynamic>> endVoiceCall({
    required String callId,
  }) async {
    return await _post('/call/voice/end', data: {
      'call_id': callId,
    });
  }

  /// 结束语音通话（兼容旧版本）
  static Future<Map<String, dynamic>> endVoiceCallWithId({
    required String callId,
  }) async {
    return await endVoiceCall(callId: callId);
  }

  /// 发起视频通话
  static Future<Map<String, dynamic>> initiateVideoCall({
    required String targetId,
  }) async {
    return await _post('/call/video/initiate', data: {
      'target_id': targetId,
    });
  }

  /// 发起视频通话（兼容旧版本）
  static Future<Map<String, dynamic>> startVideoCallWithId({
    required String targetId,
  }) async {
    return await initiateVideoCall(targetId: targetId);
  }

  /// 接受视频通话
  static Future<Map<String, dynamic>> acceptVideoCall({
    required String callId,
    String? fromId,
  }) async {
    final data = {
      'call_id': callId,
    };

    if (fromId != null) {
      data['from_id'] = fromId;
    }

    return await _post('/call/video/accept', data: data);
  }

  /// 拒绝视频通话
  static Future<Map<String, dynamic>> rejectVideoCall({
    required String callId,
  }) async {
    return await _post('/call/video/reject', data: {
      'call_id': callId,
    });
  }

  /// 拒绝视频通话（兼容旧版本）
  static Future<Map<String, dynamic>> rejectVideoCallWithId({
    required String callId,
  }) async {
    return await rejectVideoCall(callId: callId);
  }

  /// 结束视频通话
  static Future<Map<String, dynamic>> endVideoCall({
    required String callId,
  }) async {
    return await _post('/call/video/end', data: {
      'call_id': callId,
    });
  }

  /// 结束视频通话（兼容旧版本）
  static Future<Map<String, dynamic>> endVideoCallWithId({
    required String callId,
  }) async {
    return await endVideoCall(callId: callId);
  }

  /// 获取WebSocket连接URL
  static Future<Map<String, dynamic>> getWebSocketUrl() async {
    return await _get('/websocket/token');
  }

  /// 通用GET请求
  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _get(path, queryParams: queryParams);
  }

  /// 通用POST请求
  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    return await _post(path, data: data ?? {});
  }

  /// 通用PUT请求
  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    return await _put(path, data: data ?? {});
  }

  /// 通用DELETE请求
  static Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? data}) async {
    return await _delete(path, data: data ?? {});
  }

  /// 获取钱包信息
  static Future<Map<String, dynamic>> getWalletInfo() async {
    return await _get('/wallet/info');
  }

  /// 获取红包详情
  static Future<Map<String, dynamic>> getRedPacketDetail({required String redPacketId}) async {
    return await _get('/wallet/red-packet/$redPacketId');
  }

  /// 抢红包
  static Future<Map<String, dynamic>> grabRedPacketWithWallet({required String redPacketId}) async {
    return await _post('/wallet/red-packet/$redPacketId/receive');
  }

  /// 发红包
  static Future<Map<String, dynamic>> sendRedPacketWithWallet({
    required String targetId,
    required double amount,
    required String greeting,
  }) async {
    return await _post('/wallet/red-packet', data: {
      'target_id': targetId,
      'amount': amount,
      'greeting': greeting,
    });
  }
}
