class PhoneRegisterService {
  // 本地生成6位验证码
  static String generateLocalCode() {
    final rand = List.generate(6, (index) => (DateTime.now().millisecondsSinceEpoch + index * 37) % 10);
    return rand.join();
  }
}
