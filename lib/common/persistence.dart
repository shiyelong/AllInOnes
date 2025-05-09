import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 持久化存储工具类
/// 用于存储用户数据、设置等
class Persistence {
  static SharedPreferences? _prefs;

  // 键名常量
  static const String _keyToken = 'token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserInfo = 'user_info';
  static const String _keyDeviceId = 'device_id';
  static const String _keyRecentAccounts = 'recent_accounts';
  static const String _keyRememberPassword = 'remember_password';
  static const String _keyAutoLogin = 'auto_login';
  static const String _keyAccount = 'account';
  static const String _keyPassword = 'password';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLanguage = 'language';
  static const String _keyNotificationSettings = 'notification_settings';
  static const String _keyPrivacySettings = 'privacy_settings';
  static const String _keyLastLoginTime = 'last_login_time';

  /// 初始化
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // 生成设备ID（如果不存在）
    if (await getDeviceId() == null) {
      final deviceId = Uuid().v4();
      await setDeviceId(deviceId);
      debugPrint('[Persistence] 生成设备ID: $deviceId');
    }
  }

  /// 检查是否已登录
  static bool isLoggedIn() {
    final token = _prefs?.getString(_keyToken);
    return token != null && token.isNotEmpty;
  }

  /// 异步检查是否已登录
  static Future<bool> isLoggedInAsync() async {
    if (_prefs == null) {
      await init();
    }
    final token = _prefs?.getString(_keyToken);
    return token != null && token.isNotEmpty;
  }

  /// 保存登录信息
  static Future<void> saveLoginInfo({
    required String token,
    required String userId,
    required Map<String, dynamic> userInfo,
  }) async {
    await _prefs?.setString(_keyToken, token);
    await _prefs?.setString(_keyUserId, userId);
    await _prefs?.setString(_keyUserInfo, jsonEncode(userInfo));
    await _prefs?.setString(_keyLastLoginTime, DateTime.now().toIso8601String());

    debugPrint('[Persistence] 保存登录信息: userId=$userId');
  }

  /// 清除登录信息
  static Future<void> clearLoginInfo() async {
    await _prefs?.remove(_keyToken);
    await _prefs?.remove(_keyUserId);
    await _prefs?.remove(_keyUserInfo);

    // 如果不记住密码，也清除账号密码
    if (_prefs?.getBool(_keyRememberPassword) != true) {
      await _prefs?.remove(_keyAccount);
      await _prefs?.remove(_keyPassword);
    }

    debugPrint('[Persistence] 清除登录信息');
  }

  /// 获取Token
  static String? getToken() {
    return _prefs?.getString(_keyToken);
  }

  /// 获取用户ID
  static String? getUserId() {
    return _prefs?.getString(_keyUserId);
  }

  /// 获取用户信息
  static Map<String, dynamic>? getUserInfo() {
    final userInfoStr = _prefs?.getString(_keyUserInfo);
    if (userInfoStr == null || userInfoStr.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(userInfoStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Persistence] 解析用户信息失败: $e');
      return null;
    }
  }

  /// 更新用户信息
  static Future<void> updateUserInfo(Map<String, dynamic> userInfo) async {
    final oldUserInfo = getUserInfo() ?? {};
    final newUserInfo = {...oldUserInfo, ...userInfo};
    await _prefs?.setString(_keyUserInfo, jsonEncode(newUserInfo));

    debugPrint('[Persistence] 更新用户信息');
  }

  /// 获取设备ID
  static Future<String?> getDeviceId() async {
    return _prefs?.getString(_keyDeviceId);
  }

  /// 设置设备ID
  static Future<void> setDeviceId(String deviceId) async {
    await _prefs?.setString(_keyDeviceId, deviceId);
  }

  /// 保存最近登录账号
  static Future<void> saveRecentAccount({
    required String account,
    required String nickname,
    String? avatar,
  }) async {
    final recentAccountsStr = _prefs?.getString(_keyRecentAccounts);
    List<Map<String, dynamic>> recentAccounts = [];

    if (recentAccountsStr != null && recentAccountsStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(recentAccountsStr);
        recentAccounts = decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('[Persistence] 解析最近账号失败: $e');
      }
    }

    // 移除已存在的相同账号
    recentAccounts.removeWhere((item) => item['account'] == account);

    // 添加到最前面
    recentAccounts.insert(0, {
      'account': account,
      'nickname': nickname,
      'avatar': avatar,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // 最多保存5个
    if (recentAccounts.length > 5) {
      recentAccounts = recentAccounts.sublist(0, 5);
    }

    await _prefs?.setString(_keyRecentAccounts, jsonEncode(recentAccounts));

    debugPrint('[Persistence] 保存最近登录账号: $account');
  }

  /// 获取最近登录账号列表
  static List<Map<String, dynamic>> getRecentAccounts() {
    final recentAccountsStr = _prefs?.getString(_keyRecentAccounts);
    if (recentAccountsStr == null || recentAccountsStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(recentAccountsStr);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[Persistence] 解析最近账号失败: $e');
      return [];
    }
  }

  /// 移除最近登录账号
  static Future<void> removeRecentAccount(String account) async {
    final recentAccountsStr = _prefs?.getString(_keyRecentAccounts);
    if (recentAccountsStr == null || recentAccountsStr.isEmpty) {
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(recentAccountsStr);
      final recentAccounts = decoded.cast<Map<String, dynamic>>();

      recentAccounts.removeWhere((item) => item['account'] == account);

      await _prefs?.setString(_keyRecentAccounts, jsonEncode(recentAccounts));

      debugPrint('[Persistence] 移除最近登录账号: $account');
    } catch (e) {
      debugPrint('[Persistence] 移除最近账号失败: $e');
    }
  }

  /// 设置是否记住密码
  static Future<void> setRememberPassword(bool remember) async {
    await _prefs?.setBool(_keyRememberPassword, remember);
  }

  /// 获取是否记住密码
  static bool getRememberPassword() {
    return _prefs?.getBool(_keyRememberPassword) ?? false;
  }

  /// 设置是否自动登录
  static Future<void> setAutoLogin(bool auto) async {
    await _prefs?.setBool(_keyAutoLogin, auto);
  }

  /// 获取是否自动登录
  static bool getAutoLogin() {
    return _prefs?.getBool(_keyAutoLogin) ?? false;
  }

  /// 保存账号密码
  static Future<void> saveAccountPassword(String account, String password) async {
    await _prefs?.setString(_keyAccount, account);
    await _prefs?.setString(_keyPassword, password);

    debugPrint('[Persistence] 保存账号密码: $account');
  }

  /// 获取保存的账号
  static String? getSavedAccount() {
    return _prefs?.getString(_keyAccount);
  }

  /// 获取保存的密码
  static String? getSavedPassword() {
    return _prefs?.getString(_keyPassword);
  }

  /// 设置主题模式
  static Future<void> setThemeMode(String mode) async {
    await _prefs?.setString(_keyThemeMode, mode);
  }

  /// 获取主题模式
  static String getThemeMode() {
    return _prefs?.getString(_keyThemeMode) ?? 'system';
  }

  /// 设置语言
  static Future<void> setLanguage(String language) async {
    await _prefs?.setString(_keyLanguage, language);
  }

  /// 获取语言
  static String getLanguage() {
    return _prefs?.getString(_keyLanguage) ?? 'zh_CN';
  }

  /// 设置通知设置
  static Future<void> setNotificationSettings(Map<String, dynamic> settings) async {
    await _prefs?.setString(_keyNotificationSettings, jsonEncode(settings));
  }

  /// 获取通知设置
  static Map<String, dynamic> getNotificationSettings() {
    final settingsStr = _prefs?.getString(_keyNotificationSettings);
    if (settingsStr == null || settingsStr.isEmpty) {
      return {
        'message': true,
        'friend_request': true,
        'group_invitation': true,
        'voice_call': true,
        'video_call': true,
        'sound': true,
        'vibration': true,
      };
    }

    try {
      return jsonDecode(settingsStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Persistence] 解析通知设置失败: $e');
      return {
        'message': true,
        'friend_request': true,
        'group_invitation': true,
        'voice_call': true,
        'video_call': true,
        'sound': true,
        'vibration': true,
      };
    }
  }

  /// 设置隐私设置
  static Future<void> setPrivacySettings(Map<String, dynamic> settings) async {
    await _prefs?.setString(_keyPrivacySettings, jsonEncode(settings));
  }

  /// 获取隐私设置
  static Map<String, dynamic> getPrivacySettings() {
    final settingsStr = _prefs?.getString(_keyPrivacySettings);
    if (settingsStr == null || settingsStr.isEmpty) {
      return {
        'friend_verification': true,
        'show_online_status': true,
        'show_last_seen': true,
        'allow_stranger_message': false,
      };
    }

    try {
      return jsonDecode(settingsStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Persistence] 解析隐私设置失败: $e');
      return {
        'friend_verification': true,
        'show_online_status': true,
        'show_last_seen': true,
        'allow_stranger_message': false,
      };
    }
  }

  /// 获取最后登录时间
  static DateTime? getLastLoginTime() {
    final timeStr = _prefs?.getString(_keyLastLoginTime);
    if (timeStr == null || timeStr.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      debugPrint('[Persistence] 解析最后登录时间失败: $e');
      return null;
    }
  }

  /// 打印所有存储的偏好设置（调试用）
  static Future<void> debugPrintAllPrefs() async {
    if (_prefs == null) {
      debugPrint('[Persistence] SharedPreferences未初始化');
      return;
    }

    final keys = _prefs!.getKeys();
    debugPrint('[Persistence] 所有存储的偏好设置:');
    for (final key in keys) {
      final value = _prefs!.get(key);
      debugPrint('  $key: $value');
    }
  }
}
