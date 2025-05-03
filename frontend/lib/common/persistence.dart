import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'api.dart';
import 'text_sanitizer.dart';

// ?????
class UserInfo {
  final int id;
  final String account;
  final String? nickname;
  final String? avatar;
  final String? email;
  final String? phone;
  final int? gender;
  final String? generatedEmail;
  final String? token; // ??token??

  UserInfo({
    required this.id,
    required this.account,
    this.nickname,
    this.avatar,
    this.email,
    this.phone,
    this.gender,
    this.generatedEmail,
    this.token, // ??token??
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    // ??ID?????
    int userId;
    if (json['id'] is String) {
      userId = int.tryParse(json['id']) ?? 0;
    } else {
      userId = json['id'] ?? 0;
    }

    // ??gender?????
    int? userGender;
    if (json['gender'] != null) {
      if (json['gender'] is String) {
        userGender = int.tryParse(json['gender']) ?? 0;
      } else {
        userGender = json['gender'];
      }
    }

    return UserInfo(
      id: userId,
      account: json['account'] ?? '',
      nickname: TextSanitizer.sanitize(json['nickname']),
      avatar: json['avatar'],
      email: json['email'],
      phone: json['phone'],
      gender: userGender,
      generatedEmail: json['generated_email'],
      token: json['token'], // ??token
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account': account,
      'nickname': TextSanitizer.sanitize(nickname),
      'avatar': avatar,
      'email': email,
      'phone': phone,
      'gender': gender,
      'generated_email': generatedEmail,
      'token': token, // ??token
    };
  }
}

// ????????
class Persistence {
  /// ??????? SharedPreferences ?????????
  static Future<void> debugPrintAllPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      debugPrint('[Persistence][AllPrefs] keys: $keys');
      for (var key in keys) {
        debugPrint('[Persistence][AllPrefs] $key = [32m${prefs.get(key)}[0m');
      }
    } catch (e, s) {
      debugPrint('[Persistence][Error] ????prefs??: $e\n$s');
    }
  }
  static Future<void> saveToken(String token) async {
    try {
      // ????
      _cachedToken = token;

      // ?????
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      debugPrint('[Persistence] ??token: $token');
    } catch (e, s) {
      debugPrint('[Persistence][Error] ??token??: $e\n$s');
    }
  }
  // ????token??????
  static String? _cachedToken;

  static String? getToken() {
    debugPrint('[Persistence] ??token????: $_cachedToken');
    return _cachedToken;
  }

  // ????token????????
  static Future<String?> getTokenAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      _cachedToken = token; // ????
      debugPrint('[Persistence] ??token????: $token');
      return token;
    } catch (e) {
      debugPrint('[Persistence] ??token??: $e');
      return null;
    }
  }
  static Future<void> clearToken() async {
    try {
      // ????
      _cachedToken = null;

      // ??????
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      debugPrint('[Persistence] ??token');
    } catch (e) {
      debugPrint('[Persistence] ??token??: $e');
    }
  }

  // ??????
  static UserInfo? _cachedUserInfo;

  // ??????
  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    try {
      // ???token????userInfo?
      if (_cachedToken != null) {
        userInfo['token'] = _cachedToken;
      }

      // ????????????
      if (userInfo.containsKey('nickname')) {
        userInfo['nickname'] = TextSanitizer.sanitize(userInfo['nickname']);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_info', jsonEncode(userInfo));
      debugPrint('[Persistence] ????????');

      // ????
      _cachedUserInfo = UserInfo.fromJson(userInfo);
    } catch (e, s) {
      debugPrint('[Persistence][Error] ????????: $e\n$s');
    }
  }

  // ??????????????
  static UserInfo? getUserInfo() {
    try {
      // ???????????????
      if (_cachedUserInfo != null) {
        return _cachedUserInfo;
      }

      // ???????SharedPreferences????????????????null
      // ????????????????????getUserInfoAsync??
      return null;
    } catch (e, s) {
      debugPrint('[Persistence][Error] ????????: $e\n$s');
      return null;
    }
  }

  // ????????
  static Future<UserInfo?> getUserInfoAsync() async {
    try {
      // ???????????????
      if (_cachedUserInfo != null) {
        return _cachedUserInfo;
      }

      // ?SharedPreferences???????
      final prefs = await SharedPreferences.getInstance();
      final userInfoStr = prefs.getString('user_info');
      if (userInfoStr != null && userInfoStr.isNotEmpty) {
        try {
          final userInfoJson = jsonDecode(userInfoStr);

          // ????????????
          if (userInfoJson.containsKey('nickname')) {
            userInfoJson['nickname'] = TextSanitizer.sanitize(userInfoJson['nickname']);
          }

          _cachedUserInfo = UserInfo.fromJson(userInfoJson);
          return _cachedUserInfo;
        } catch (e) {
          debugPrint('[Persistence][Error] ????????: $e');
        }
      }

      // ??????????????API??
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        try {
          final response = await Api.getUserInfo();
          if (response['success'] == true && response['data'] != null) {
            // ???????
            await saveUserInfo(response['data']);
            _cachedUserInfo = UserInfo.fromJson(response['data']);
            return _cachedUserInfo;
          }
        } catch (e) {
          debugPrint('[Persistence][Error] ?API????????: $e');
        }
      }

      return null;
    } catch (e, s) {
      debugPrint('[Persistence][Error] ????????: $e\n$s');
      return null;
    }
  }

  // ????????
  static void clearCachedUserInfo() {
    _cachedUserInfo = null;
  }

  // ??????
  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_info');
    clearCachedUserInfo();
  }

  // 保存聊天消息
  static Future<void> saveChatMessages(String userId, String targetId, List<Map<String, dynamic>> messages) async {
    final key = 'chat_messages_${userId}_${targetId}';
    final prefs = await SharedPreferences.getInstance();

    // 使用 TextSanitizer 清理消息内容
    final sanitizedMessages = messages.map((msg) {
      final sanitizedMsg = Map<String, dynamic>.from(msg);

      // 清理消息内容
      if (sanitizedMsg.containsKey('content')) {
        final content = sanitizedMsg['content'];
        if (content is String) {
          try {
            // 简单的清理方法，移除可能导致问题的字符
            sanitizedMsg['content'] = content
                .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '') // 控制字符
                .replaceAll(RegExp(r'[\uD800-\uDFFF]'), ''); // 代理对字符
          } catch (e) {
            sanitizedMsg['content'] = '无法显示的内容';
          }
        }
      }

      // 清理昵称
      if (sanitizedMsg.containsKey('from_nickname')) {
        final nickname = sanitizedMsg['from_nickname'];
        if (nickname is String) {
          try {
            sanitizedMsg['from_nickname'] = nickname
                .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
                .replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
          } catch (e) {
            sanitizedMsg['from_nickname'] = '用户';
          }
        }
      }

      return sanitizedMsg;
    }).toList();

    await prefs.setString(key, jsonEncode(sanitizedMessages));
  }

  // 获取聊天消息
  static Future<List<Map<String, dynamic>>> getChatMessages(String userId, String targetId) async {
    final key = 'chat_messages_${userId}_${targetId}';
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getString(key);
    if (messagesJson == null || messagesJson.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(messagesJson);
      final messages = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      // 再次清理消息内容，确保安全
      return messages.map((msg) {
        final sanitizedMsg = Map<String, dynamic>.from(msg);

        // 清理消息内容
        if (sanitizedMsg.containsKey('content')) {
          final content = sanitizedMsg['content'];
          if (content is String) {
            try {
              sanitizedMsg['content'] = content
                  .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
                  .replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
            } catch (e) {
              sanitizedMsg['content'] = '无法显示的内容';
            }
          }
        }

        // 清理昵称
        if (sanitizedMsg.containsKey('from_nickname')) {
          final nickname = sanitizedMsg['from_nickname'];
          if (nickname is String) {
            try {
              sanitizedMsg['from_nickname'] = nickname
                  .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
                  .replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
            } catch (e) {
              sanitizedMsg['from_nickname'] = '用户';
            }
          }
        }

        return sanitizedMsg;
      }).toList();
    } catch (e) {
      debugPrint('解析聊天消息失败: $e');
      return [];
    }
  }

  // 清理所有聊天消息
  static Future<void> cleanupChatMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('chat_messages_')) {
        try {
          final messagesJson = prefs.getString(key);
          if (messagesJson != null && messagesJson.isNotEmpty) {
            final List<dynamic> decoded = jsonDecode(messagesJson);
            final messages = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

            // 清理消息内容
            final sanitizedMessages = messages.map((msg) {
              final sanitizedMsg = Map<String, dynamic>.from(msg);

              // 清理消息内容
              if (sanitizedMsg.containsKey('content')) {
                final content = sanitizedMsg['content'];
                if (content is String) {
                  try {
                    sanitizedMsg['content'] = content
                        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
                        .replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
                  } catch (e) {
                    sanitizedMsg['content'] = '无法显示的内容';
                  }
                }
              }

              // 清理昵称
              if (sanitizedMsg.containsKey('from_nickname')) {
                final nickname = sanitizedMsg['from_nickname'];
                if (nickname is String) {
                  try {
                    sanitizedMsg['from_nickname'] = nickname
                        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
                        .replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
                  } catch (e) {
                    sanitizedMsg['from_nickname'] = '用户';
                  }
                }
              }

              return sanitizedMsg;
            }).toList();

            await prefs.setString(key, jsonEncode(sanitizedMessages));
          }
        } catch (e) {
          debugPrint('清理聊天消息失败: $key, $e');
          // 如果解析失败，直接删除该条目
          await prefs.remove(key);
        }
      }
    }
  }
}
