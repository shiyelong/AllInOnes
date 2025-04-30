import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';

class LoginFormService {
  static Future<Map<String, dynamic>> login(String account, String password) async {
    return await Api.login(account: account, password: password).timeout(const Duration(seconds: 10));
  }

  static Future<void> saveToken(String token) async {
    await Persistence.saveToken(token);
  }
}
