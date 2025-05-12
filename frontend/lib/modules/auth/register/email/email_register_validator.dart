class EmailRegisterValidator {
  static String? validate(String email, String code, String password, String generatedCode) {
    if (email.isEmpty) return '请输入邮箱';
    if (!RegExp(r'^[\w-.]+@[\w-]+\.[a-zA-Z]{2,4}$').hasMatch(email)) return '邮箱格式不正确';
    if (code.isEmpty) return '请输入验证码';
    // 验证码验证由后端处理
    if (password.length < 6) return '密码至少6位';
    return null;
  }
}
