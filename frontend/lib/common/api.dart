import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'persistence.dart';
import 'text_sanitizer.dart';

class Api {
  static const String _base = 'http://localhost:3001/api'; // 已确认正确的后端地址
  static const String baseUrl = 'http://localhost:3001'; // 基础URL，用于构建完整的资源URL

  // 公共方法
  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _get(path, queryParams: queryParams);
  }

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    return await _post(path, data: data);
  }

  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    return await _put(path, data: data);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    return await _delete(path);
  }

  // 是否使用模拟数据（在后端不可用时）
  static bool _useMock = false; // 始终使用真实API，不使用模拟数据

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
  static Future<Map<String, dynamic>> _delete(String path) async {
    final headers = _getAuthHeaders();
    final uri = Uri.parse('$_base$path');

    debugPrint('[API] 发送DELETE请求: $uri');

    try {
      final resp = await http.delete(uri, headers: headers);
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

  // 验证Token
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

  // 获取验证码图片
  static Future<Map<String, dynamic>> getCaptcha() async {
    try {
      debugPrint('正在请求真实验证码...');
      final resp = await _get('/captcha');
      if (resp['success'] == true && resp['data'] != null) {
        debugPrint('成功获取真实验证码');
        return resp;
      } else {
        debugPrint('验证码API返回错误: ${resp['msg']}');
      }
    } catch (e) {
      debugPrint('获取验证码失败: $e');
    }

    // 如果API调用失败，使用一个明显的错误图片，提示用户刷新
    debugPrint('使用错误提示验证码');

    // 这是一个简单的红色图片，表示验证码加载失败
    const base64Image = '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';

    return {
      'success': true,
      'data': {
        'captcha_id': 'error_captcha_id_${DateTime.now().millisecondsSinceEpoch}',
        'captcha_image': base64Image,
      }
    };
  }

  // 旧的注册方法（保留兼容）
  static Future<Map<String, dynamic>> register({
    required String account,
    required String password,
    required String captchaId,
    required String captchaValue,
  }) async {
    return await _post('/register', data: {
      'account': account,
      'password': password,
      'captcha_id': captchaId,
      'captcha_value': captchaValue,
    });
  }

  // 新的注册方法（支持手机号和邮箱）
  static Future<Map<String, dynamic>> registerNew({
    String? email,
    String? phone,
    required String password,
    required String captchaId,
    required String captchaValue,
    required String verificationCode, // 手机/邮箱验证码
    required String registerType, // "email" 或 "phone"
    String? nickname, // 昵称（可选）
  }) async {
    try {
      debugPrint('发送真实注册请求: $registerType, ${registerType == "email" ? email : phone}');
      final resp = await _post('/register/new', data: {
        'email': email,
        'phone': phone,
        'password': password,
        'captcha_id': captchaId,
        'captcha_value': captchaValue,
        'verification_code': verificationCode, // 添加手机/邮箱验证码
        'register_type': registerType,
        'nickname': nickname, // 添加昵称
      });

      debugPrint('注册响应: $resp');
      return resp; // 始终返回真实响应，无论成功与否
    } catch (e) {
      debugPrint('注册请求异常: $e');
      // 返回错误信息
      return {
        'success': false,
        'msg': '网络异常，请稍后重试',
      };
    }
  }

  // 检查邮箱/手机号是否已注册
  static Future<Map<String, dynamic>> checkExists({
    required String type, // "email" 或 "phone"
    required String target, // 邮箱或手机号
  }) async {
    try {
      debugPrint('检查是否已注册: $type, $target');

      final resp = await _post('/register/check', data: {
        'type': type,
        'target': target,
      });

      return resp;
    } catch (e) {
      debugPrint('检查是否已注册请求异常: $e');
      return {
        'success': false,
        'msg': '检查失败，请检查网络连接',
        'data': {'exists': false}, // 默认返回不存在，避免阻止用户继续
      };
    }
  }

  // 获取验证码
  static Future<Map<String, dynamic>> getVerificationCode({
    required String type, // "email" 或 "phone"
    required String target, // 邮箱或手机号
  }) async {
    try {
      debugPrint('正在请求发送真实验证码: $type, $target');

      // 首先检查是否已注册
      final checkResp = await checkExists(type: type, target: target);
      if (checkResp['success'] == true && checkResp['data']['exists'] == true) {
        debugPrint('$type $target 已被注册，无法发送验证码');
        return {
          'success': false,
          'msg': type == 'email' ? '该邮箱已被注册' : '该手机号已被注册',
        };
      }

      // 根据类型选择不同的API路径
      String apiPath = type == "phone" ? '/register/sms' : '/register/code';

      final resp = await _get(apiPath, queryParams: {
        'type': type,
        'target': target,
        'phone': type == "phone" ? target : null,
      });

      if (resp['success'] == true) {
        debugPrint('验证码发送成功');
        return resp;
      } else {
        debugPrint('验证码发送失败: ${resp['msg']}');
      }
    } catch (e) {
      debugPrint('发送验证码请求异常: $e');
    }

    // 如果API调用失败，返回错误信息
    debugPrint('验证码发送失败，返回错误信息');

    return {
      'success': false,
      'msg': '验证码发送失败，请检查网络连接或联系管理员',
    };
  }

  // 获取短信验证码（用户自己发送短信到运营商）
  static Future<Map<String, dynamic>> getSMSVerificationCode({
    required String phone, // 手机号
  }) async {
    try {
      debugPrint('正在请求短信验证码信息: $phone');
      final resp = await _get('/register/sms', queryParams: {
        'phone': phone,
      });

      if (resp['success'] == true) {
        debugPrint('短信验证码信息获取成功');
        return resp;
      } else {
        debugPrint('短信验证码信息获取失败: ${resp['msg']}');
      }
    } catch (e) {
      debugPrint('获取短信验证码信息异常: $e');
    }

    // 如果API调用失败，返回错误信息
    return {
      'success': false,
      'msg': '获取短信验证码信息失败，请检查网络连接或联系管理员',
    };
  }

  // 旧的登录方法（保留兼容）
  static Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    return await _post('/login', data: {
      'account': account,
      'password': password,
    });
  }

  // 新的登录方法（支持账号、手机号和邮箱）
  static Future<Map<String, dynamic>> loginNew({
    required String account,
    required String password,
  }) async {
    // 判断登录类型：账号、手机号或邮箱
    String loginType = 'account';

    // 检查是否是手机号（简单判断：11位数字，以1开头）
    if (RegExp(r'^1\d{10}$').hasMatch(account)) {
      loginType = 'phone';
    }
    // 检查是否是邮箱
    else if (RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(account)) {
      loginType = 'email';
    }

    // 使用新的登录API路径
    try {
      debugPrint('[Login] 尝试使用新登录API: /login/new');
      return await _post('/login/new', data: {
        'account': account,
        'password': password,
        'login_type': loginType, // 新API支持login_type参数
      });
    } catch (e) {
      debugPrint('[Login] 新登录API失败，尝试旧API: $e');
      try {
        // 尝试使用旧的登录API作为备选
        return await _post('/login', data: {
          'account': account,
          'password': password,
        });
      } catch (e2) {
        debugPrint('[Login] 登录失败: $e2');
        return {
          'success': false,
          'msg': '登录失败，请检查账号密码',
        };
      }
    }
  }

  // 获取用户信息
  static Future<Map<String, dynamic>> getUserInfo({String? userId}) async {
    if (userId != null) {
      return await _get('/user/$userId');
    } else {
      return await _get('/user/info');
    }
  }

  // 根据ID获取用户信息
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    return await _get('/user/${userId}');
  }

  // 更新用户信息
  static Future<Map<String, dynamic>> updateUserInfo(Map<String, dynamic> userInfo) async {
    return await _put('/user/info', data: userInfo);
  }

  // 获取聊天列表
  static Future<Map<String, dynamic>> getChatList() async {
    return await _get('/chat/list');
  }

  // 获取最近聊天列表
  static Future<Map<String, dynamic>> getRecentChats({
    required String userId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return await _get('/chat/recent', queryParams: {
      'user_id': userId,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // 语音通话相关API

  // 获取语音通话记录
  static Future<Map<String, dynamic>> getVoiceCallRecords({
    int page = 1,
    int pageSize = 20,
    String callType = 'all', // all, incoming, outgoing
  }) async {
    return await _get('/call/voice/records', queryParams: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'call_type': callType,
    });
  }

  // 获取语音通话详情
  static Future<Map<String, dynamic>> getVoiceCallDetail(String callId) async {
    return await _get('/call/voice/records/$callId');
  }

  // 发起语音通话
  static Future<Map<String, dynamic>> initiateVoiceCall({
    required String receiverId,
  }) async {
    return await _post('/call/voice/initiate', data: {
      'receiver_id': receiverId,
    });
  }

  // 接受语音通话
  static Future<Map<String, dynamic>> acceptVoiceCallById({
    required String callId,
  }) async {
    return await _post('/call/voice/accept', data: {
      'call_id': callId,
    });
  }

  // 拒绝语音通话
  static Future<Map<String, dynamic>> rejectVoiceCallById({
    required String callId,
  }) async {
    return await _post('/call/voice/reject', data: {
      'call_id': callId,
    });
  }

  // 结束语音通话
  static Future<Map<String, dynamic>> endVoiceCallById({
    required String callId,
  }) async {
    return await _post('/call/voice/end', data: {
      'call_id': callId,
    });
  }

  // 获取语音通话统计
  static Future<Map<String, dynamic>> getVoiceCallStats() async {
    return await _get('/call/voice/stats');
  }

  // 视频通话相关API

  // 获取视频通话记录
  static Future<Map<String, dynamic>> getVideoCallRecords({
    int page = 1,
    int pageSize = 20,
    String callType = 'all', // all, incoming, outgoing
  }) async {
    return await _get('/call/video/records', queryParams: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'call_type': callType,
    });
  }

  // 获取视频通话详情
  static Future<Map<String, dynamic>> getVideoCallDetail(String callId) async {
    return await _get('/call/video/records/$callId');
  }

  // 发起视频通话
  static Future<Map<String, dynamic>> initiateVideoCall({
    required String receiverId,
  }) async {
    return await _post('/call/video/initiate', data: {
      'receiver_id': receiverId,
    });
  }

  // 接受视频通话
  static Future<Map<String, dynamic>> acceptVideoCallById({
    required String callId,
  }) async {
    return await _post('/call/video/accept', data: {
      'call_id': callId,
    });
  }

  // 拒绝视频通话
  static Future<Map<String, dynamic>> rejectVideoCallById({
    required String callId,
  }) async {
    return await _post('/call/video/reject', data: {
      'call_id': callId,
    });
  }

  // 结束视频通话
  static Future<Map<String, dynamic>> endVideoCallById({
    required String callId,
  }) async {
    return await _post('/call/video/end', data: {
      'call_id': callId,
    });
  }

  // 获取视频通话统计
  static Future<Map<String, dynamic>> getVideoCallStats() async {
    return await _get('/call/video/stats');
  }

  // WebRTC相关API

  // 发起通话
  static Future<Map<String, dynamic>> startCall({
    required String fromId,
    required String toId,
    required String type,  // 'voice' 或 'video'
    required String sdp,
  }) async {
    return await _post('/call/start', data: {
      'from_id': fromId,
      'to_id': toId,
      'type': type,
      'sdp': sdp,
    });
  }

  // 接听通话
  static Future<Map<String, dynamic>> answerCall({
    required String callId,
  }) async {
    return await _post('/call/answer', data: {
      'call_id': callId,
    });
  }

  // 拒绝通话
  static Future<Map<String, dynamic>> rejectCall({
    required String callId,
  }) async {
    return await _post('/call/reject', data: {
      'call_id': callId,
    });
  }

  // 结束通话
  static Future<Map<String, dynamic>> endCall({
    required String callId,
  }) async {
    return await _post('/call/end', data: {
      'call_id': callId,
    });
  }

  // 获取聊天消息
  static Future<Map<String, dynamic>> getChatMessages(int chatId, {int page = 1, int pageSize = 20}) async {
    return await _get('/chat/messages/$chatId', queryParams: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // 发送聊天消息
  static Future<Map<String, dynamic>> sendChatMessage(int receiverId, String content, {String? type, String? extra}) async {
    return await _post('/chat/send', data: {
      'receiver_id': receiverId,
      'content': content,
      'type': type ?? 'text',
      if (extra != null) 'extra': extra,
    });
  }

  // 发送语音消息
  static Future<Map<String, dynamic>> sendVoiceMessage(int receiverId, String voiceUrl, int duration) async {
    return await _post('/chat/send', data: {
      'receiver_id': receiverId,
      'content': voiceUrl,
      'type': 'voice',
      'extra': jsonEncode({'duration': duration}),
    });
  }

  // 发送图片消息
  static Future<Map<String, dynamic>> sendImageMessage(int receiverId, String imageUrl) async {
    return await _post('/chat/send', data: {
      'receiver_id': receiverId,
      'content': imageUrl,
      'type': 'image',
    });
  }

  // 发送视频消息
  static Future<Map<String, dynamic>> sendVideoMessage(int receiverId, String videoUrl, String? thumbnailUrl) async {
    return await _post('/chat/send', data: {
      'receiver_id': receiverId,
      'content': videoUrl,
      'type': 'video',
      'extra': jsonEncode({'thumbnail': thumbnailUrl}),
    });
  }

  // 发送文件消息
  static Future<Map<String, dynamic>> sendFileMessage(int receiverId, String fileUrl, String fileName, int fileSize) async {
    return await _post('/chat/send', data: {
      'receiver_id': receiverId,
      'content': fileUrl,
      'type': 'file',
      'extra': jsonEncode({
        'file_name': fileName,
        'file_size': fileSize,
      }),
    });
  }

  // 发送位置消息
  static Future<Map<String, dynamic>> sendLocationMessage(int receiverId, double latitude, double longitude, String address) async {
    return await _post('/chat/send', data: {
      'receiver_id': receiverId,
      'content': address,
      'type': 'location',
      'extra': jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    });
  }

  // 发送红包
  static Future<Map<String, dynamic>> sendRedPacket({
    required String senderId,
    required String receiverId,
    required double amount,
    required int count,
    required String greeting,
  }) async {
    return await _post('/chat/redpacket/send', data: {
      'sender_id': int.parse(senderId),
      'receiver_id': int.parse(receiverId),
      'amount': amount,
      'count': count,
      'greeting': greeting,
    });
  }

  // 抢红包
  static Future<Map<String, dynamic>> grabRedPacket({
    required String redPacketId,
    required String userId,
  }) async {
    return await _post('/chat/redpacket/grab', data: {
      'red_packet_id': int.parse(redPacketId),
      'user_id': int.parse(userId),
    });
  }

  // 获取红包详情
  static Future<Map<String, dynamic>> getRedPacketDetail({
    required String redPacketId,
  }) async {
    debugPrint('[API] 获取红包详情: 红包ID=$redPacketId');

    try {
      // 尝试两个可能的API端点
      try {
        return await _get('/chat/redpacket/detail', queryParams: {
          'id': redPacketId,
        });
      } catch (e) {
        debugPrint('[API] 第一个红包详情API端点失败，尝试备用端点: $e');
        return await _get('/red-packet/$redPacketId');
      }
    } catch (e) {
      debugPrint('[API] 获取红包详情异常: $e');
      return {'success': false, 'msg': '获取红包详情失败: $e'};
    }
  }

  // 获取好友列表
  static Future<Map<String, dynamic>> getFriendList() async {
    return await _get('/friends/list');
  }

  // 添加好友
  static Future<Map<String, dynamic>> addFriend({
    required String userId,
    required String friendId,
    String message = '',
    String sourceType = 'search',
  }) async {
    return await _post('/friends/add', data: {
      'user_id': userId,
      'friend_id': friendId,
      'message': message,
      'source_type': sourceType,
    });
  }

  // 搜索用户
  static Future<Map<String, dynamic>> searchUsers({
    required String keyword,
    String? currentUserId,
  }) async {
    return await _get('/friends/search', queryParams: {
      'keyword': keyword,
      if (currentUserId != null) 'current_user_id': currentUserId,
    });
  }

  // 获取好友请求列表
  static Future<Map<String, dynamic>> getFriendRequests({
    required String userId,
    String type = 'received',
    String status = 'pending',
  }) async {
    return await _get('/friends/requests', queryParams: {
      'user_id': userId,
      'type': type,
      'status': status,
    });
  }

  // 同意好友请求
  static Future<Map<String, dynamic>> agreeFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    return await _post('/friends/agree', data: {
      'request_id': requestId,
      'user_id': userId,
    });
  }

  // 拒绝好友请求
  static Future<Map<String, dynamic>> rejectFriendRequest({
    required String requestId,
    required String userId,
  }) async {
    return await _post('/friends/reject', data: {
      'request_id': requestId,
      'user_id': userId,
    });
  }

  // 批量同意好友请求
  static Future<Map<String, dynamic>> batchAgreeFriendRequests({
    required String userId,
    required List<String> requestIds,
  }) async {
    return await _post('/friends/batch/agree', data: {
      'user_id': userId,
      'request_ids': requestIds,
    });
  }

  // 批量拒绝好友请求
  static Future<Map<String, dynamic>> batchRejectFriendRequests({
    required String userId,
    required List<String> requestIds,
  }) async {
    return await _post('/friends/batch/reject', data: {
      'user_id': userId,
      'request_ids': requestIds,
    });
  }

  // 屏蔽好友
  static Future<Map<String, dynamic>> blockFriend({
    required String userId,
    required String friendId,
  }) async {
    return await _post('/friends/block', data: {
      'user_id': userId,
      'friend_id': friendId,
    });
  }

  // 取消屏蔽好友
  static Future<Map<String, dynamic>> unblockFriend({
    required String userId,
    required String friendId,
  }) async {
    return await _post('/friends/unblock', data: {
      'user_id': userId,
      'friend_id': friendId,
    });
  }

  // 获取好友添加方式
  static Future<Map<String, dynamic>> getFriendAddMode({
    required String userId,
  }) async {
    return await _get('/friends/mode', queryParams: {
      'user_id': userId,
    });
  }

  // 设置好友添加方式
  static Future<Map<String, dynamic>> setFriendAddMode({
    required String userId,
    required int mode,
  }) async {
    return await _post('/friends/mode', data: {
      'user_id': int.parse(userId),
      'mode': mode,
    });
  }

  // 开始语音通话
  static Future<Map<String, dynamic>> startVoiceCallWithId(int receiverId) async {
    return await _post('/chat/call/voice/start', data: {
      'receiver_id': receiverId,
    });
  }

  // 开始语音通话（兼容旧版）
  static Future<Map<String, dynamic>> startVoiceCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/voice/start', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 结束语音通话
  static Future<Map<String, dynamic>> endVoiceCallWithId(int callId) async {
    return await _post('/chat/call/voice/end', data: {
      'call_id': callId,
    });
  }

  // 结束语音通话（兼容旧版）
  static Future<Map<String, dynamic>> endVoiceCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/voice/end', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 拒绝语音通话
  static Future<Map<String, dynamic>> rejectVoiceCallWithId(int callId) async {
    return await _post('/chat/call/voice/reject', data: {
      'call_id': callId,
    });
  }

  // 拒绝语音通话（兼容旧版）
  static Future<Map<String, dynamic>> rejectVoiceCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/voice/reject', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 接受语音通话
  static Future<Map<String, dynamic>> acceptVoiceCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/voice/accept', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 开始视频通话
  static Future<Map<String, dynamic>> startVideoCallWithId(int receiverId) async {
    return await _post('/chat/call/video/start', data: {
      'receiver_id': receiverId,
    });
  }

  // 开始视频通话（兼容旧版）
  static Future<Map<String, dynamic>> startVideoCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/video/start', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 结束视频通话
  static Future<Map<String, dynamic>> endVideoCallWithId(int callId) async {
    return await _post('/chat/call/video/end', data: {
      'call_id': callId,
    });
  }

  // 结束视频通话（兼容旧版）
  static Future<Map<String, dynamic>> endVideoCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/video/end', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 拒绝视频通话
  static Future<Map<String, dynamic>> rejectVideoCallWithId(int callId) async {
    return await _post('/chat/call/video/reject', data: {
      'call_id': callId,
    });
  }

  // 拒绝视频通话（兼容旧版）
  static Future<Map<String, dynamic>> rejectVideoCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/video/reject', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 接受视频通话
  static Future<Map<String, dynamic>> acceptVideoCall({
    required String fromId,
    required String toId,
  }) async {
    return await _post('/chat/call/video/accept', data: {
      'caller_id': int.parse(fromId),
      'receiver_id': int.parse(toId),
    });
  }

  // 获取通话历史
  static Future<Map<String, dynamic>> getCallHistory({String type = 'all'}) async {
    return await _get('/chat/call/history', queryParams: {
      'type': type,
    });
  }

  // 上传文件
  static Future<Map<String, dynamic>> uploadFile(String filePath, String fileType) async {
    var uri = Uri.parse('$_base/chat/upload');
    var request = http.MultipartRequest('POST', uri);

    // 添加认证头
    final headers = _getAuthHeaders();
    request.headers.addAll(headers);

    // 添加文件类型
    request.fields['type'] = fileType;

    // 添加文件
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    debugPrint('[API] 上传文件: $filePath, 类型: $fileType, URL: $uri');

    try {
      // 发送请求
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      debugPrint('[API] 上传文件响应状态码: ${response.statusCode}');
      debugPrint('[API] 上传文件响应数据: $responseData');

      try {
        return jsonDecode(responseData);
      } catch (e) {
        debugPrint('[API] 解析上传文件响应失败: $e');
        return {
          'success': false,
          'msg': '解析响应失败: $responseData',
        };
      }
    } catch (e) {
      debugPrint('[API] 上传文件异常: $e');
      return {
        'success': false,
        'msg': '上传文件失败: $e',
      };
    }
  }

  // 获取表情包列表
  static Future<Map<String, dynamic>> getEmoticonPackages() async {
    return await _get('/chat/emoticon/packages');
  }

  // 获取表情列表
  static Future<Map<String, dynamic>> getEmoticons({int? packageId}) async {
    return await _get('/chat/emoticon/list', queryParams: {
      if (packageId != null) 'package_id': packageId.toString(),
    });
  }



  // 获取钱包信息
  static Future<Map<String, dynamic>> getWalletInfo() async {
    debugPrint('[API] 获取钱包信息');

    try {
      // 尝试两个可能的API端点
      try {
        final response = await _get('/wallet/info');
        debugPrint('[API] 钱包信息响应: $response');
        return response;
      } catch (e) {
        debugPrint('[API] 第一个钱包信息API端点失败，尝试备用端点: $e');
        final response = await _get('/wallet');
        debugPrint('[API] 备用钱包信息响应: $response');
        return response;
      }
    } catch (e) {
      debugPrint('[API] 获取钱包信息异常: $e');
      return {'success': false, 'msg': '获取钱包信息失败: $e'};
    }
  }

  // 获取交易记录
  static Future<Map<String, dynamic>> getTransactions({int page = 1, int pageSize = 20}) async {
    debugPrint('[API] 获取交易记录: 页码=$page, 每页数量=$pageSize');

    try {
      // 尝试两个可能的API端点
      try {
        final response = await _get('/wallet/transactions', queryParams: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        });
        debugPrint('[API] 交易记录响应: $response');
        return response;
      } catch (e) {
        debugPrint('[API] 第一个交易记录API端点失败，尝试备用端点: $e');
        final response = await _get('/wallet/transaction/list', queryParams: {
          'page': page.toString(),
          'limit': pageSize.toString(),
        });
        debugPrint('[API] 备用交易记录响应: $response');
        return response;
      }
    } catch (e) {
      debugPrint('[API] 获取交易记录异常: $e');
      return {'success': false, 'msg': '获取交易记录失败: $e', 'data': []};
    }
  }

  // 转账
  static Future<Map<String, dynamic>> transfer({
    required int senderID,
    required int receiverID,
    required double amount,
    String message = '',
  }) async {
    debugPrint('[API] 转账: 发送者=$senderID, 接收者=$receiverID, 金额=$amount');

    try {
      final data = {
        'sender_id': senderID,
        'receiver_id': receiverID,
        'amount': amount,
        'message': message,
      };

      debugPrint('[API] 转账请求数据: $data');

      // 尝试两个可能的API端点
      try {
        final response = await _post('/wallet/transfer', data: data);
        debugPrint('[API] 转账响应: $response');
        return response;
      } catch (e) {
        debugPrint('[API] 第一个转账API端点失败，尝试备用端点: $e');
        final response = await _post('/wallet/transaction/transfer', data: data);
        debugPrint('[API] 备用转账响应: $response');
        return response;
      }
    } catch (e) {
      debugPrint('[API] 转账异常: $e');
      return {'success': false, 'msg': '转账失败: $e'};
    }
  }

  // 充值（模拟）
  static Future<Map<String, dynamic>> recharge({
    required int userID,
    required double amount,
  }) async {
    debugPrint('[API] 充值: 用户ID=$userID, 金额=$amount');

    try {
      final data = {
        'user_id': userID,
        'amount': amount,
      };

      debugPrint('[API] 充值请求数据: $data');

      // 尝试两个可能的API端点
      try {
        final response = await _post('/wallet/recharge', data: data);
        debugPrint('[API] 充值响应: $response');
        return response;
      } catch (e) {
        debugPrint('[API] 第一个充值API端点失败，尝试备用端点: $e');
        final response = await _post('/wallet/transaction/recharge', data: data);
        debugPrint('[API] 备用充值响应: $response');
        return response;
      }
    } catch (e) {
      debugPrint('[API] 充值异常: $e');
      return {'success': false, 'msg': '充值失败: $e'};
    }
  }

  // 发送红包（集成钱包系统）
  static Future<Map<String, dynamic>> sendRedPacketWithWallet({
    required String senderID,
    required String receiverID,
    required double amount,
    required int count,
    required String greeting,
    int? groupID,
  }) async {
    debugPrint('[API] 发送红包: 发送者=$senderID, 接收者=$receiverID, 金额=$amount, 数量=$count');

    try {
      final data = {
        'sender_id': int.parse(senderID),
        'receiver_id': int.parse(receiverID),
        'amount': amount,
        'count': count,
        'greeting': greeting,
        if (groupID != null) 'group_id': groupID,
      };

      debugPrint('[API] 发送红包请求数据: $data');

      // 尝试两个可能的API端点
      try {
        return await _post('/chat/redpacket/send/wallet', data: data);
      } catch (e) {
        debugPrint('[API] 第一个红包API端点失败，尝试备用端点: $e');
        return await _post('/chat/redpacket/send', data: data);
      }
    } catch (e) {
      debugPrint('[API] 发送红包异常: $e');
      return {'success': false, 'msg': '发送红包失败: $e'};
    }
  }

  // 抢红包（集成钱包系统）
  static Future<Map<String, dynamic>> grabRedPacketWithWallet({
    required String redPacketID,
    required String userID,
  }) async {
    debugPrint('[API] 抢红包: 红包ID=$redPacketID, 用户ID=$userID');

    try {
      final data = {
        'red_packet_id': int.parse(redPacketID),
        'user_id': int.parse(userID),
      };

      debugPrint('[API] 抢红包请求数据: $data');

      // 尝试两个可能的API端点
      try {
        return await _post('/chat/redpacket/grab/wallet', data: data);
      } catch (e) {
        debugPrint('[API] 第一个抢红包API端点失败，尝试备用端点: $e');
        return await _post('/chat/redpacket/grab', data: data);
      }
    } catch (e) {
      debugPrint('[API] 抢红包异常: $e');
      return {'success': false, 'msg': '抢红包失败: $e'};
    }
  }

  // 获取朋友圈动态
  static Future<Map<String, dynamic>> getMoments({int page = 1, int pageSize = 10}) async {
    return await _get('/moments', queryParams: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
  }

  // 发布朋友圈动态
  static Future<Map<String, dynamic>> postMoment(String content, List<String> images) async {
    return await _post('/moments/post', data: {
      'content': content,
      'images': images,
    });
  }

  // 点赞朋友圈动态
  static Future<Map<String, dynamic>> likeMoment(int momentId) async {
    return await _post('/moments/like/$momentId');
  }

  // 评论朋友圈动态
  static Future<Map<String, dynamic>> commentMoment(int momentId, String content) async {
    return await _post('/moments/comment/$momentId', data: {
      'content': content,
    });
  }

  // WebRTC相关API

  // 发送WebRTC信令
  static Future<Map<String, dynamic>> sendSignal({
    required String fromId,
    required String toId,
    required String type,
    required String signal,
    required String callType, // 'voice' 或 'video'
  }) async {
    debugPrint('[API] 发送WebRTC信令: 发送者=$fromId, 接收者=$toId, 类型=$type');

    try {
      final response = await _post('/webrtc/signal', data: {
        'from': fromId,
        'to': toId,
        'type': type,
        'signal': signal,
        'call_type': callType,
      });

      return response;
    } catch (e) {
      debugPrint('[API] 发送WebRTC信令异常: $e');
      return {'success': false, 'msg': '发送信令失败: $e'};
    }
  }

  // 开始WebRTC语音通话
  static Future<Map<String, dynamic>> startVoiceCallWebRTC({
    required String fromId,
    required String toId,
  }) async {
    debugPrint('[API] 开始WebRTC语音通话: 发起者=$fromId, 接收者=$toId');

    try {
      final response = await _post('/webrtc/voice/start', data: {
        'caller_id': int.parse(fromId),
        'receiver_id': int.parse(toId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 开始WebRTC语音通话异常: $e');
      return {'success': false, 'msg': '开始语音通话失败: $e'};
    }
  }

  // 结束WebRTC语音通话
  static Future<Map<String, dynamic>> endVoiceCallWebRTC({
    required String callId,
  }) async {
    debugPrint('[API] 结束WebRTC语音通话: 通话ID=$callId');

    try {
      final response = await _post('/webrtc/voice/end', data: {
        'call_id': int.parse(callId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 结束WebRTC语音通话异常: $e');
      return {'success': false, 'msg': '结束语音通话失败: $e'};
    }
  }

  // 接受WebRTC语音通话
  static Future<Map<String, dynamic>> acceptVoiceCallWebRTC({
    required String callId,
  }) async {
    debugPrint('[API] 接受WebRTC语音通话: 通话ID=$callId');

    try {
      final response = await _post('/webrtc/voice/accept', data: {
        'call_id': int.parse(callId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 接受WebRTC语音通话异常: $e');
      return {'success': false, 'msg': '接受语音通话失败: $e'};
    }
  }

  // 拒绝WebRTC语音通话
  static Future<Map<String, dynamic>> rejectVoiceCallWebRTC({
    required String callId,
  }) async {
    debugPrint('[API] 拒绝WebRTC语音通话: 通话ID=$callId');

    try {
      final response = await _post('/webrtc/voice/reject', data: {
        'call_id': int.parse(callId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 拒绝WebRTC语音通话异常: $e');
      return {'success': false, 'msg': '拒绝语音通话失败: $e'};
    }
  }

  // 开始WebRTC视频通话
  static Future<Map<String, dynamic>> startVideoCallWebRTC({
    required String fromId,
    required String toId,
  }) async {
    debugPrint('[API] 开始WebRTC视频通话: 发起者=$fromId, 接收者=$toId');

    try {
      final response = await _post('/webrtc/video/start', data: {
        'caller_id': int.parse(fromId),
        'receiver_id': int.parse(toId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 开始WebRTC视频通话异常: $e');
      return {'success': false, 'msg': '开始视频通话失败: $e'};
    }
  }

  // 结束WebRTC视频通话
  static Future<Map<String, dynamic>> endVideoCallWebRTC({
    required String callId,
  }) async {
    debugPrint('[API] 结束WebRTC视频通话: 通话ID=$callId');

    try {
      final response = await _post('/webrtc/video/end', data: {
        'call_id': int.parse(callId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 结束WebRTC视频通话异常: $e');
      return {'success': false, 'msg': '结束视频通话失败: $e'};
    }
  }

  // 接受WebRTC视频通话
  static Future<Map<String, dynamic>> acceptVideoCallWebRTC({
    required String callId,
  }) async {
    debugPrint('[API] 接受WebRTC视频通话: 通话ID=$callId');

    try {
      final response = await _post('/webrtc/video/accept', data: {
        'call_id': int.parse(callId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 接受WebRTC视频通话异常: $e');
      return {'success': false, 'msg': '接受视频通话失败: $e'};
    }
  }

  // 拒绝WebRTC视频通话
  static Future<Map<String, dynamic>> rejectVideoCallWebRTC({
    required String callId,
  }) async {
    debugPrint('[API] 拒绝WebRTC视频通话: 通话ID=$callId');

    try {
      final response = await _post('/webrtc/video/reject', data: {
        'call_id': int.parse(callId),
      });

      return response;
    } catch (e) {
      debugPrint('[API] 拒绝WebRTC视频通话异常: $e');
      return {'success': false, 'msg': '拒绝视频通话失败: $e'};
    }
  }

  // 获取WebRTC通话历史
  static Future<Map<String, dynamic>> getCallHistoryWebRTC({String type = 'all'}) async {
    debugPrint('[API] 获取WebRTC通话历史: 类型=$type');

    try {
      final response = await _get('/webrtc/history', queryParams: {
        'type': type,
      });

      return response;
    } catch (e) {
      debugPrint('[API] 获取WebRTC通话历史异常: $e');
      return {'success': false, 'msg': '获取通话历史失败: $e'};
    }
  }

  // 获取与特定用户的聊天消息
  static Future<Map<String, dynamic>> getMessagesByUser({
    required String userId,
    required String targetId,
    int page = 1,
    int pageSize = 50,
  }) async {
    debugPrint('[API] 获取聊天消息: userId=$userId, targetId=$targetId');

    try {
      final result = await _get('/chat/messages', queryParams: {
        'user_id': userId,
        'target_id': targetId,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      });

      // 打印响应结果
      debugPrint('[API] 获取聊天消息响应: success=${result['success']}, msg=${result['msg']}');
      if (result['success'] == true) {
        debugPrint('[API] 获取到 ${(result['data'] as List?)?.length ?? 0} 条消息');
      }

      return result;
    } catch (e) {
      debugPrint('[API] 获取聊天消息异常: $e');
      return {'success': false, 'msg': '获取消息失败: $e'};
    }
  }

  // 发送消息
  static Future<Map<String, dynamic>> sendMessage({
    required String fromId,
    required String toId,
    required String content,
    String type = 'text',
  }) async {
    debugPrint('[API] 发送消息: 发送者=$fromId, 接收者=$toId, 类型=$type');

    try {
      final data = {
        'from_id': fromId,
        'to_id': toId,
        'content': content,
        'type': type,
      };

      if (type != 'text') {
        debugPrint('[API] 发送非文本消息: $type, 内容=$content');
      }

      final response = await _post('/chat/send', data: data);
      debugPrint('[API] 发送消息响应: $response');
      return response;
    } catch (e) {
      debugPrint('[API] 发送消息异常: $e');
      return {'success': false, 'msg': '发送消息失败: $e'};
    }
  }
}
