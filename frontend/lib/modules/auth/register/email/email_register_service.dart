class EmailRegisterService {
  static String generateLocalCode() {
    final rand = List.generate(6, (index) => (DateTime.now().millisecondsSinceEpoch + index * 43) % 10);
    return rand.join();
  }
}
