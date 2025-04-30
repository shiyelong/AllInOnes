class LoginFormValidator {
  static String? validateAccount(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入账号';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    return null;
  }
}
