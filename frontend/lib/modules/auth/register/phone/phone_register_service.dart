class PhoneRegisterService {
  // 本地生成6位验证码
  static String generateLocalCode() {
    return List.generate(6, (index) => (index + 1).toString()).join();
  }
}
