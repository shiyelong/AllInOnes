class LoginFormModel {
  String account;
  String password;
  bool? rememberPwd;
  bool? autoLogin;

  LoginFormModel({
    required this.account,
    required this.password,
    this.rememberPwd,
    this.autoLogin,
  });
}
