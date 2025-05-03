import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';

class LoginFormService {
  static Future<Map<String, dynamic>> login(String account, String password) async {
    // 使用新的登录API，支持账号、手机号和邮箱
    return await Api.loginNew(account: account, password: password).timeout(const Duration(seconds: 10));
  }

  static Future<void> saveToken(String token) async {
    await Persistence.saveToken(token);
  }

  // 保存用户信息
  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    await Persistence.saveUserInfo(userInfo);
  }

  // 清除缓存的用户信息
  static void clearCachedUserInfo() {
    Persistence.clearCachedUserInfo();
  }

  // 获取用户信息
  static Future<UserInfo?> getUserInfo() async {
    return await Persistence.getUserInfoAsync();
  }
}
