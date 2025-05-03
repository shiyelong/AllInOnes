import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/animations.dart';
import 'package:frontend/common/recent_accounts.dart';

enum RegisterType { phone, email }

class NewRegisterPage extends StatefulWidget {
  @override
  State<NewRegisterPage> createState() => _NewRegisterPageState();
}

class _NewRegisterPageState extends State<NewRegisterPage> {
  // 基本状态
  bool _loading = false;
  String? _errorMessage;
  bool _registerSuccess = false;

  // 注册类型
  RegisterType _registerType = RegisterType.phone;

  // 控制器
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final verificationCodeCtrl = TextEditingController(); // 手机/邮箱验证码控制器
  final nicknameCtrl = TextEditingController(); // 昵称控制器
  final pwdCtrl = TextEditingController();
  final pwd2Ctrl = TextEditingController();

  // 开发环境验证码
  String _verificationCode = '';

  // 验证状态
  bool _isPhoneValid = false;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isPasswordMatch = false;

  // 验证手机号
  bool _validatePhone(String phone) {
    // 简单的手机号验证：11位数字，以1开头
    final RegExp phoneReg = RegExp(r'^1\d{10}$');
    _isPhoneValid = phoneReg.hasMatch(phone);
    return _isPhoneValid;
  }

  // 验证邮箱
  bool _validateEmail(String email) {
    // 简单的邮箱验证
    final RegExp emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    _isEmailValid = emailReg.hasMatch(email);
    return _isEmailValid;
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

  // 密码强度颜色
  Color _passwordStrengthColor(String pwd) {
    double s = _passwordStrength(pwd);
    if (s < 0.3) return Colors.red;
    if (s < 0.7) return Colors.orange;
    return Colors.green;
  }

  // 密码强度文本
  String _passwordStrengthText(String pwd) {
    double s = _passwordStrength(pwd);
    if (s < 0.3) return '弱';
    if (s < 0.7) return '中';
    return '强';
  }

  // 验证码相关
  String captchaId = '';
  String captchaImg = '';
  String captchaText = ''; // 验证码文本
  bool _isLoadingCaptcha = false;

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
    phoneCtrl.dispose();
    emailCtrl.dispose();
    codeCtrl.dispose();
    verificationCodeCtrl.dispose();
    nicknameCtrl.dispose();
    pwdCtrl.dispose();
    pwd2Ctrl.dispose();
    super.dispose();
  }

  // 获取图形验证码
  void getVerifyCodeFromBackend() async {
    if (_isLoadingCaptcha) return; // 防止重复请求

    setState(() {
      _isLoadingCaptcha = true;
      _errorMessage = null;
    });

    try {
      print('请求验证码...');

      // 调用API获取验证码
      var response = await Api.getCaptcha();
      print('验证码响应: $response');

      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            captchaId = response['data']['captcha_id'] ?? '';
            captchaImg = response['data']['captcha_image'] ?? '';
            captchaText = response['data']['captcha_text'] ?? '验证码';
            _isLoadingCaptcha = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = response['msg'] ?? '获取验证码失败';
            _isLoadingCaptcha = false;
          });
        }
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

  // 构建验证码图片
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

    // 显示后端返回的验证码文本
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(captchaText, style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppTheme.primaryColor,
          )),
          Text('(验证码)', style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
          )),
        ],
      ),
    );
  }

  // 手机/邮箱验证码发送状态
  bool _isSendingVerificationCode = false;
  String? _verificationCodeSent;
  // 分离手机号和邮箱验证码的倒计时
  int _phoneCountDown = 0;
  int _emailCountDown = 0;

  // 获取当前验证码倒计时
  int get _countDown => _registerType == RegisterType.phone ? _phoneCountDown : _emailCountDown;

  // 发送手机/邮箱验证码
  void _sendVerificationCode() async {
    // 检查当前类型的倒计时是否在进行中
    if (_isSendingVerificationCode || _countDown > 0) return;

    // 验证输入
    String target = '';
    String type = '';

    if (_registerType == RegisterType.phone) {
      target = phoneCtrl.text.trim();
      type = 'phone';
      if (!_validatePhone(target)) {
        setState(() {
          _errorMessage = '请输入正确的手机号';
        });
        return;
      }
    } else {
      target = emailCtrl.text.trim();
      type = 'email';
      if (!_validateEmail(target)) {
        setState(() {
          _errorMessage = '请输入正确的邮箱';
        });
        return;
      }
    }

    setState(() {
      _isSendingVerificationCode = true;
      _errorMessage = null;
    });

    try {
      // 首先检查邮箱/手机号是否已注册
      final checkResp = await Api.checkExists(type: type, target: target);

      if (checkResp['success'] == true && checkResp['data']['exists'] == true) {
        // 已注册，显示错误提示
        setState(() {
          _isSendingVerificationCode = false;
          _errorMessage = type == 'email' ? '该邮箱已被注册' : '该手机号已被注册';
        });

        // 显示已注册提示对话框
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 10),
                Text(type == 'email' ? '邮箱已注册' : '手机号已注册'),
              ],
            ),
            content: Text(
              type == 'email'
                ? '该邮箱已被注册，请使用其他邮箱或直接登录。'
                : '该手机号已被注册，请使用其他手机号或直接登录。'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: Text('去登录'),
              ),
            ],
          ),
        );
        return;
      }

      // 根据注册类型选择不同的API调用
      Map<String, dynamic> response;

      if (_registerType == RegisterType.phone) {
        // 手机号注册 - 获取短信验证码信息
        response = await Api.getSMSVerificationCode(phone: target);

        if (response['success'] == true && response['data'] != null) {
          // 显示用户需要发送的短信内容和目标号码
          final smsContent = response['data']['sms_content'] ?? '';
          final targetNumber = response['data']['target_number'] ?? '';

          // 开始手机验证码倒计时
          setState(() {
            _isSendingVerificationCode = false;
            _verificationCodeSent = '请发送短信获取验证码';
            _phoneCountDown = 60; // 手机验证码60秒倒计时
          });

          // 倒计时
          _startPhoneCountDown();

          // 显示短信发送指引
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('发送短信获取验证码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('请发送以下内容到 $targetNumber:'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      smsContent,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('发送后，您将收到验证码短信，请输入短信中的验证码完成注册。'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('我知道了'),
                ),
              ],
            ),
          );

          // 在开发环境下，自动填充验证码
          if (response['data']['verification_code'] != null) {
            setState(() {
              _verificationCode = response['data']['verification_code'];
            });

            // 显示验证码对话框，而不是底部Snackbar
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('验证码已生成'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('开发环境验证码:'),
                    SizedBox(height: 10),
                    Text(
                      _verificationCode,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // 自动填充验证码
                      verificationCodeCtrl.text = _verificationCode;
                      Navigator.pop(context);
                    },
                    child: Text('自动填充'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('关闭'),
                  ),
                ],
              ),
            );
          } else if (response['code'] != null) {
            // 如果验证码在顶层返回
            setState(() {
              _verificationCode = response['code'];
            });

            // 显示验证码对话框，而不是底部Snackbar
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('验证码已生成'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('开发环境验证码:'),
                    SizedBox(height: 10),
                    Text(
                      _verificationCode,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // 自动填充验证码
                      verificationCodeCtrl.text = _verificationCode;
                      Navigator.pop(context);
                    },
                    child: Text('自动填充'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('关闭'),
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            _isSendingVerificationCode = false;
            _errorMessage = response['msg'] ?? '获取短信验证码信息失败';
          });
        }
      } else {
        // 邮箱注册 - 发送邮箱验证码
        response = await Api.getVerificationCode(
          type: type,
          target: target,
        );

        print('验证码发送响应: $response');

        if (response['success'] == true) {
          // 开始邮箱验证码倒计时
          setState(() {
            _isSendingVerificationCode = false;
            _verificationCodeSent = '验证码已发送';
            _emailCountDown = 60; // 邮箱验证码60秒倒计时
          });

          // 倒计时
          _startEmailCountDown();

          // 不显示底部提示，因为我们会在上方显示验证码对话框

          // 在开发环境下，显示验证码（如果后端返回了）
          if (response['code'] != null) {
            print('开发环境验证码: ${response['code']}');

            // 保存验证码，用于自动填充（仅开发环境）
            setState(() {
              _verificationCode = response['code'];
            });

            // 显示验证码对话框，而不是底部Snackbar
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('验证码已发送'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('开发环境验证码:'),
                    SizedBox(height: 10),
                    Text(
                      response['code'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // 自动填充验证码
                      verificationCodeCtrl.text = response['code'];
                      Navigator.pop(context);
                    },
                    child: Text('自动填充'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('关闭'),
                  ),
                ],
              ),
            );
          } else {
            // 真实环境下，显示对话框提示用户查看邮箱
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('验证码已发送'),
                content: Text('请查看您的邮箱收件箱和垃圾邮件文件夹，输入收到的验证码完成注册。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('确定'),
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            _isSendingVerificationCode = false;
            _errorMessage = response['msg'] ?? '发送验证码失败';
          });
        }
      }
    } catch (e) {
      print('发送验证码异常: $e');
      setState(() {
        _isSendingVerificationCode = false;
        _errorMessage = '网络异常，请稍后重试';
      });
    }
  }

  // 手机验证码倒计时
  void _startPhoneCountDown() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _phoneCountDown > 0) {
        setState(() {
          _phoneCountDown--;
        });
        _startPhoneCountDown();
      }
    });
  }

  // 邮箱验证码倒计时
  void _startEmailCountDown() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _emailCountDown > 0) {
        setState(() {
          _emailCountDown--;
        });
        _startEmailCountDown();
      }
    });
  }

  // 注册方法
  Future<void> _register() async {
    // 清除之前的错误信息
    setState(() {
      _errorMessage = null;
    });

    // 验证输入
    String? email;
    String? phone;
    String password = pwdCtrl.text;
    String password2 = pwd2Ctrl.text;
    String captchaCode = codeCtrl.text.trim(); // 图形验证码
    String verificationCode = verificationCodeCtrl.text.trim(); // 手机/邮箱验证码
    String nickname = nicknameCtrl.text.trim(); // 昵称
    String registerType = _registerType == RegisterType.phone ? 'phone' : 'email';

    if (_registerType == RegisterType.phone) {
      phone = phoneCtrl.text.trim();
      if (!_validatePhone(phone)) {
        setState(() {
          _errorMessage = '请输入正确的手机号';
        });
        return;
      }
    } else {
      email = emailCtrl.text.trim();
      if (!_validateEmail(email)) {
        setState(() {
          _errorMessage = '请输入正确的邮箱';
        });
        return;
      }
    }

    if (password.isEmpty || password2.isEmpty || captchaCode.isEmpty || verificationCode.isEmpty) {
      setState(() {
        _errorMessage = '请填写完整信息';
      });
      return;
    }

    if (password != password2) {
      setState(() {
        _errorMessage = '两次密码不一致';
      });
      return;
    }

    if (_passwordStrength(password) < 0.3) {
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
      // 调用API注册
      var resp = await Api.registerNew(
        email: email,
        phone: phone,
        password: password,
        captchaId: captchaId,
        captchaValue: captchaCode,
        verificationCode: verificationCode, // 添加手机/邮箱验证码
        registerType: registerType,
        nickname: nickname, // 添加昵称
      );

      print('注册响应: $resp');

      if (resp['success'] == true) {
        // 注册成功
        setState(() {
          _loading = false;
          _registerSuccess = true;
        });

        // 显示生成的账号信息
        String account = resp['data']?['account'] ?? '';
        String generatedEmail = resp['data']?['generated_email'] ?? '';
        String nickname = resp['data']?['nickname'] ?? account; // 使用返回的昵称，如果没有则使用账号

        // 保存最近注册的账号
        debugPrint('[Register] 保存最近注册的账号: $account, $generatedEmail');
        await RecentAccountsManager.saveAccount(account, generatedEmail);

        // 验证是否保存成功
        final savedAccounts = await RecentAccountsManager.getAccounts();
        debugPrint('[Register] 保存后的账号列表: ${savedAccounts.length}个');
        for (var acc in savedAccounts) {
          debugPrint('[Register] 已保存账号: ${acc.account}, ${acc.generatedEmail}, ${acc.registeredAt}');
        }

        // 显示成功信息（更明显的对话框）
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text('注册成功'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('您的账号信息：'),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('账号: $account', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        Text('昵称: $nickname', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        Text('邮箱: $generatedEmail'),
                      ],
                    ),
                  ),
                  SizedBox(height: 15),
                  Text('请记住您的账号和密码，即将跳转到登录页面...'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // 跳转到登录页并传递账号
                    debugPrint('[Register] 用户点击立即登录按钮，跳转到登录页面并传递参数: account=$account, password=***');
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false, arguments: {
                      'forcePwdTab': true,
                      'account': account,
                      'password': password,
                    });
                  },
                  child: Text('立即登录'),
                ),
              ],
            ),
          );

          // 3秒后自动关闭对话框并跳转
          Future.delayed(Duration(milliseconds: 3000), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.pop(context);
              // 跳转到登录页并传递账号
              debugPrint('[Register] 跳转到登录页面并传递参数: account=$account, password=***');
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false, arguments: {
                'forcePwdTab': true,
                'account': account,
                'password': password,
              });
            }
          });
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

                      // 注册类型切换
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_registerType != RegisterType.phone && !_loading) {
                                    setState(() {
                                      _registerType = RegisterType.phone;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _registerType == RegisterType.phone
                                        ? AppTheme.primaryColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '手机号注册',
                                      style: TextStyle(
                                        color: _registerType == RegisterType.phone
                                            ? Colors.white
                                            : isDarkMode ? Colors.white70 : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_registerType != RegisterType.email && !_loading) {
                                    setState(() {
                                      _registerType = RegisterType.email;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _registerType == RegisterType.email
                                        ? AppTheme.primaryColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '邮箱注册',
                                      style: TextStyle(
                                        color: _registerType == RegisterType.email
                                            ? Colors.white
                                            : isDarkMode ? Colors.white70 : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 手机号/邮箱输入框
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 700),
                        child: _registerType == RegisterType.phone
                            ? TextField(
                                controller: phoneCtrl,
                                enabled: !_loading && !_registerSuccess,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: '手机号',
                                  hintText: '请输入手机号',
                                  prefixIcon: Icon(Icons.phone_android, color: AppTheme.primaryColor),
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
                                onChanged: (v) {
                                  setState(() {
                                    _validatePhone(v);
                                  });
                                },
                              )
                            : TextField(
                                controller: emailCtrl,
                                enabled: !_loading && !_registerSuccess,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: '邮箱',
                                  hintText: '请输入邮箱',
                                  prefixIcon: Icon(Icons.email, color: AppTheme.primaryColor),
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
                                onChanged: (v) {
                                  setState(() {
                                    _validateEmail(v);
                                  });
                                },
                              ),
                      ),
                      SizedBox(height: 16),

                      // 昵称输入框
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 800),
                        child: TextField(
                          controller: nicknameCtrl,
                          enabled: !_loading && !_registerSuccess,
                          decoration: InputDecoration(
                            labelText: '昵称',
                            hintText: '请输入昵称（可选）',
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
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // 手机/邮箱验证码输入框
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 850),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: verificationCodeCtrl,
                                enabled: !_loading && !_registerSuccess,
                                decoration: InputDecoration(
                                  labelText: _registerType == RegisterType.phone ? '手机验证码' : '邮箱验证码',
                                  hintText: '请输入验证码',
                                  prefixIcon: Icon(Icons.message, color: AppTheme.primaryColor),
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
                              onTap: !_isLoadingCaptcha && !_loading && !_registerSuccess && (_registerType == RegisterType.phone ? _isPhoneValid : _isEmailValid)
                                  ? _sendVerificationCode
                                  : null,
                              child: Container(
                                width: 120,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _countDown > 0 || _isSendingVerificationCode || !(_registerType == RegisterType.phone ? _isPhoneValid : _isEmailValid)
                                      ? Colors.grey.shade300
                                      : AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: _isSendingVerificationCode
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppTheme.primaryColor,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _countDown > 0
                                              ? '${_countDown}s后重发'
                                              : '获取验证码',
                                          style: TextStyle(
                                            color: _countDown > 0 || !(_registerType == RegisterType.phone ? _isPhoneValid : _isEmailValid)
                                                ? Colors.grey.shade700
                                                : Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),

                      // 图形验证码
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 900),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: codeCtrl,
                                enabled: !_loading && !_registerSuccess,
                                decoration: InputDecoration(
                                  labelText: '图形验证码',
                                  hintText: '请输入图形验证码',
                                  prefixIcon: Icon(Icons.verified_user, color: AppTheme.primaryColor),
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
                      SizedBox(height: 16),

                      // 密码输入框
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 1000),
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
                        duration: Duration(milliseconds: 1100),
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
                      SizedBox(height: 24),

                      // 注册按钮
                      AppAnimations.fadeIn(
                        duration: Duration(milliseconds: 1200),
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
                        duration: Duration(milliseconds: 1300),
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
}
