class EmailRegisterService {
  static String generateLocalCode() {
    return List.generate(6, (index) => (index + 1).toString()).join();
  }
}
