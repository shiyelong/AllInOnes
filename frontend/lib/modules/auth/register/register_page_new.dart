import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/animations.dart';

class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 账号校验：只能英文开头，且只允许英文和数字
  bool _isAccountValid(String account) {
    final reg = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*');
    return reg.hasMatch(account);
  }

  // 密码强度：返回0.0~1.0
  double _passwordStrength(String pwd) {
    if (pwd.length < 8) return 0.1;
    int level = 0;
    if (RegExp(r'[a-z]').hasMatch(pwd)) level++;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) level++;
    if (RegExp(r'[0-9]').hasMatch(pwd)) level++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(pwd)) level++;
    return (level + (pwd.length > 12 ? 1 : 0)) / 5.0;
  }

  Color _passwordStrengthColor(String pwd) {
    double s = _passwordStrength(pwd);
    if (s < 0.3) return Colors.red;
    if (s < 0.7) return Colors.orange;
    return Colors.green;
  }

  String _passwordStrengthText(String pwd) {
    double s = _passwordStrength(pwd);
    if (s < 0.3) return '弱';
    if (s < 0.7) return '中';
    return '强';
  }

  bool _loading = false;
  final accountCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final pwd2Ctrl = TextEditingController();
  final codeCtrl = TextEditingController();

  // 账号正则：英文开头，只允许字母和数字
  final RegExp accountReg = RegExp(r'^[a-zA-Z][a-zA-Z0-9]{4,31} ?$'); // 5-32位

  // 验证码图片URL
  String captchaId = '';
  String captchaImg = '';
  bool _isLoadingCaptcha = false;
  String? _errorMessage;
  bool _registerSuccess = false;

  // 刷新验证码（对接后端）
  void getVerifyCodeFromBackend() async {
    if (_isLoadingCaptcha) return; // 防止重复请求

    setState(() {
      _isLoadingCaptcha = true;
      _errorMessage = null;
    });

    try {
      print('请求验证码...');
      var data = await Api.getCaptcha();
      print('收到验证码响应:');
      print(data);

      if (mounted) {
        setState(() {
          captchaId = data['id'] ?? '';
          captchaImg = data['img'] ?? '';
          _isLoadingCaptcha = false;
        });
      }
    } catch (e) {
      print('获取验证码失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '获取验证码失败，请点击刷新';
          _isLoadingCaptcha = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // 延迟一帧后请求验证码，避免在build过程中setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getVerifyCodeFromBackend();
    });
  }

  @override
  void dispose() {
    accountCtrl.dispose();
    pwdCtrl.dispose();
    pwd2Ctrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }

  Widget _buildCaptchaImage() {
    if (_isLoadingCaptcha) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          )
        )
      );
    }

    if (captchaImg.isEmpty) {
      return Center(
        child: Icon(Icons.refresh, color: Colors.grey)
      );
    }

    try {
      // 兼容带 data:image/png;base64, 前缀和无前缀
      String base64Str = captchaImg;
      if (captchaImg.startsWith('data:image')) {
        base64Str = captchaImg.split(',').last;
      }
      return Image.memory(base64Decode(base64Str), fit: BoxFit.contain);
    } catch (e) {
      return Center(
        child: IconButton(
          icon: Icon(Icons.refresh, color: Colors.red),
          onPressed: getVerifyCodeFromBackend,
          tooltip: '验证码加载失败，点击刷新',
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // QQ风格渐变背景
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        Color(0xFF1A237E),  // 深蓝色
                        Color(0xFF311B92),  // 深紫色
                        Color(0xFF4A148C),  // 紫色
                      ]
                    : [
                        Color(0xFF12B7F5),  // QQ蓝色
                        Color(0xFF1E88E5),  // 深蓝色
                        Color(0xFF0D73BB),  // 更深的蓝色
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 装饰性气泡元素
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            right: MediaQuery.of(context).size.width * 0.15,
            child: AppAnimations.fadeIn(
              duration: Duration(milliseconds: 800),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            left: MediaQuery.of(context).size.width * 0.1,
            child: AppAnimations.fadeIn(
              duration: Duration(milliseconds: 1000),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
            ),
          ),

          // 主内容
          Center(
            child: SingleChildScrollView(
              child: AppAnimations.fadeInScale(
                duration: Duration(milliseconds: 600),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey[900]!.withOpacity(0.85)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white,
                      width: 1,
                    ),
                  ),
                  width: MediaQuery.of(context).size.width < 480 ? double.infinity : 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 返回按钮
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new,
                            color: isDarkMode ? Colors.white70 : Colors.black87),
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: '返回',
                        ),
                      ),
                      SizedBox(height: 8),

                      // Logo
                      Hero(
                        tag: 'logo',
                        child: SvgPicture.asset('assets/imgs/logo.svg', width: 72, height: 72),
                      ),
                      SizedBox(height: 16),

                      // 标题
                      Text(
                        '创建账号',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '注册后将自动生成数字账号',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 24),

                      // 错误消息显示
                      if (_errorMessage != null)
                        AppAnimations.fadeIn(
                          duration: Duration(milliseconds: 300),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 成功消息显示
                      if (_registerSuccess)
                        AppAnimations.fadeIn(
                          duration: Duration(milliseconds: 300),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '注册成功，正在跳转...',
                                    style: TextStyle(color: Colors.green.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 账号输入框
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 700),
                        child: TextField(
                          controller: accountCtrl,
                          enabled: !_loading && !_registerSuccess,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z][a-zA-Z0-9]*')),
                          ],
                          decoration: InputDecoration(
                            labelText: '用户名',
                            hintText: '英文开头，仅英文和数字',
                            prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                            errorText: !_isAccountValid(accountCtrl.text) && accountCtrl.text.isNotEmpty
                                ? '账号只能英文开头，且只能包含英文和数字'
                                : null,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      SizedBox(height: 16),

                      // 密码输入框
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 800),
                        child: TextField(
                          controller: pwdCtrl,
                          obscureText: true,
                          enabled: !_loading && !_registerSuccess,
                          decoration: InputDecoration(
                            labelText: '密码',
                            hintText: '8-20位，包含字母和数字',
                            prefixIcon: Icon(Icons.lock, color: AppTheme.primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),

                      // 密码强度指示器
                      if (pwdCtrl.text.isNotEmpty)
                        AppAnimations.fadeIn(
                          duration: Duration(milliseconds: 300),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: _passwordStrength(pwdCtrl.text),
                                    backgroundColor: Colors.grey[300],
                                    color: _passwordStrengthColor(pwdCtrl.text),
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(_passwordStrengthText(pwdCtrl.text),
                                    style: TextStyle(color: _passwordStrengthColor(pwdCtrl.text), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: 16),

                      // 确认密码
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 900),
                        child: TextField(
                          controller: pwd2Ctrl,
                          obscureText: true,
                          enabled: !_loading && !_registerSuccess,
                          decoration: InputDecoration(
                            labelText: '确认密码',
                            hintText: '再次输入密码',
                            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                            errorText: pwd2Ctrl.text.isNotEmpty && pwdCtrl.text != pwd2Ctrl.text
                                ? '两次密码不一致'
                                : null,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      SizedBox(height: 16),

                      // 验证码
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 1000),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: codeCtrl,
                                enabled: !_loading && !_registerSuccess,
                                decoration: InputDecoration(
                                  labelText: '验证码',
                                  hintText: '请输入验证码',
                                  prefixIcon: Icon(Icons.security, color: AppTheme.primaryColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            GestureDetector(
                              onTap: !_isLoadingCaptcha && !_loading && !_registerSuccess
                                  ? getVerifyCodeFromBackend
                                  : null,
                              child: Container(
                                width: 100,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: _buildCaptchaImage(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // 注册按钮
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 1100),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF12B7F5), // QQ蓝色
                                Color(0xFF0D73BB), // 深蓝色
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: !_loading && !_registerSuccess ? _register : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    '注册',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // 底部提示
                      SizedBox(height: 16),
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 1200),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '已有账号？',
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            TextButton(
                              onPressed: !_loading && !_registerSuccess
                                  ? () => Navigator.of(context).pushReplacementNamed('/login')
                                  : null,
                              child: Text(
                                '立即登录',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 注册方法
  // 处理用户注册流程，包括:
  // 1. 验证用户输入的账号、密码和验证码
  // 2. 调用后端API进行注册
  // 3. 处理注册成功或失败的逻辑
  // 4. 注册成功后自动跳转到登录页面
  Future<void> _register() async {
    // 清除之前的错误信息
    setState(() {
      _errorMessage = null;
    });

    // 验证输入
    String account = accountCtrl.text.trim();
    String pwd = pwdCtrl.text;
    String pwd2 = pwd2Ctrl.text;
    String code = codeCtrl.text.trim();

    if (account.isEmpty || pwd.isEmpty || pwd2.isEmpty || code.isEmpty) {
      setState(() {
        _errorMessage = '请填写完整信息';
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9]{4,31} ?$').hasMatch(account)) {
      setState(() {
        _errorMessage = '账号需英文开头，仅支持字母和数字，5-32位';
      });
      return;
    }

    if (pwd != pwd2) {
      setState(() {
        _errorMessage = '两次密码不一致';
      });
      return;
    }

    if (_passwordStrength(pwd) < 0.3) {
      setState(() {
        _errorMessage = '密码强度太弱，请包含大小写字母、数字和特殊字符';
      });
      return;
    }

    // 开始注册
    setState(() {
      _loading = true;
    });

    try {
      var resp = await Api.register(
        account: account,
        password: pwd,
        nickname: account,
        verificationCode: code,
      );

      if (resp['success'] == true) {
        // 注册成功
        setState(() {
          _loading = false;
          _registerSuccess = true;
        });

        // 打印注册成功信息
        print('注册成功，账号信息: ${resp['data']}');

        // 打印详细的跳转信息
        print('准备跳转到登录页面，延迟1200毫秒');

        // 短暂延迟后跳转
        await Future.delayed(Duration(milliseconds: 1200));

        if (mounted) {
          // 获取注册返回的账号信息
          String account = resp['data']?['account'] ?? accountCtrl.text;
          print('跳转参数: account=$account, password=${pwdCtrl.text.replaceAll(RegExp(r'.'), '*')}');

          try {
            // 保存账号信息到最近账号列表
            await RecentAccountsManager.addAccount(
              account: account,
              generatedEmail: resp['data']?['generated_email'] ?? '',
            );
            print('已保存账号到最近账号列表');

            // 跳转到登录页并传递账号密码
            print('执行跳转: pushNamedAndRemoveUntil(/login)');
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false, arguments: {
              'forcePwdTab': true,
              'account': account,
              'password': pwdCtrl.text,
            });
            print('跳转命令已执行');
          } catch (e) {
            print('跳转过程中发生异常: $e');
            // 如果出现异常，尝试使用替代方法跳转
            Navigator.pushReplacementNamed(context, '/login', arguments: {
              'forcePwdTab': true,
              'account': account,
              'password': pwdCtrl.text,
            });
          }
        } else {
          print('组件已卸载，无法执行跳转');
        }
      } else {
        // 注册失败
        setState(() {
          _loading = false;
          _errorMessage = resp['msg'] ?? '注册失败';
        });
        getVerifyCodeFromBackend();
      }
    } catch (e) {
      print('注册异常: $e');
      setState(() {
        _loading = false;
        _errorMessage = '网络异常，请稍后重试';
      });
      getVerifyCodeFromBackend();
    }
  }
}
