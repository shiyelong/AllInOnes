class PhoneRegisterValidator {
  static String? validate(String phone, String code, String password, String generatedCode) {
    if (phone.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) return '手机号格式不正确';
    if (code.isEmpty) return '请输入验证码';
    // 验证码验证由后端处理
    if (password.length < 6) return '密码至少6位';
    return null;
  }
}
