import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:frontend/modules/auth/login/login_form/login_form_service.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/animations.dart';
import 'package:frontend/common/recent_accounts.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);
  @override
  State<LoginForm> createState() => LoginFormState();
}

class LoginFormState extends State<LoginForm> with SingleTickerProviderStateMixin {
  bool get isPhone {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  // 控制器
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController pwdCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();

  // 焦点节点
  final FocusNode userFocusNode = FocusNode();
  final FocusNode pwdFocusNode = FocusNode();

  // 状态变量
  bool? rememberPwd;  // 将在_loadPrefs中初始化
  bool? autoLogin;    // 将在_loadPrefs中初始化
  bool _autoLoginCanceled = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _loginSuccess = false;

  // 最近注册的账号列表
  List<RecentAccount> _recentAccounts = [];

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _autoLoginCanceled = false;

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 先加载保存的设置
      await _loadPrefs();

      // 检查是否需要自动登录
      final mq = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      final double width = mq.width / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final bool isTabletOrDesktop = width >= 600;

      debugPrint('[LoginForm] 检查自动登录条件: isTabletOrDesktop=$isTabletOrDesktop, 账号=${userCtrl.text.isNotEmpty}, 密码=${pwdCtrl.text.isNotEmpty}, autoLogin=$autoLogin');

      // 只有当满足所有条件时才自动登录
      if (isTabletOrDesktop &&
          userCtrl.text.isNotEmpty &&
          pwdCtrl.text.isNotEmpty &&
          autoLogin == true &&
          !_autoLoginCanceled) {

        debugPrint('[LoginForm] 满足自动登录条件，准备自动登录');

        // 根据平台决定是否显示对话框
        if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform)) {
          if (mounted) {
            debugPrint('[LoginForm] 桌面平台，显示自动登录对话框');
            await _showAutoLoginDialog();
          }
        } else {
          if (mounted) {
            debugPrint('[LoginForm] 移动平台，直接自动登录');
            await _login();
          }
        }
      } else {
        debugPrint('[LoginForm] 不满足自动登录条件，不执行自动登录');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    userCtrl.dispose();
    pwdCtrl.dispose();
    codeCtrl.dispose();
    userFocusNode.dispose();
    pwdFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showAutoLoginDialog() async {
    if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform)) {
      _autoLoginCanceled = false;
      bool finished = false;
      bool dialogShown = false;

      if (!mounted) return;

      try {
        // 显示自动登录对话框
        dialogShown = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text('自动登录'),
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 18),
                      Expanded(child: Text('正在自动登录...')),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _autoLoginCanceled = true;
                        Navigator.of(context).pop();
                      },
                      child: Text('取消自动登录'),
                    ),
                  ],
                );
              },
            );
          },
        );

        // 短暂延迟，让用户有机会取消
        await Future.delayed(Duration(milliseconds: 1500));

        // 如果用户没有取消，则尝试登录
        if (!_autoLoginCanceled && mounted) {
          debugPrint('[AutoLogin] 开始自动登录');
          await _login();
          finished = true;
          debugPrint('[AutoLogin] 自动登录完成: $finished');
        } else {
          debugPrint('[AutoLogin] 自动登录已取消');
        }
      } catch (e, s) {
        debugPrint('[AutoLogin][Error] 自动登录异常: $e\n$s');
      } finally {
        // 确保对话框被关闭
        if (dialogShown && !finished && !_autoLoginCanceled && mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } else {
      // 移动设备直接登录，不显示对话框
      if (mounted) {
        debugPrint('[AutoLogin] 移动设备直接登录');
        await _login();
      }
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载最近注册的账号
    _recentAccounts = await RecentAccountsManager.getAccounts();
    debugPrint('[LoginForm] 加载到最近注册的账号: ${_recentAccounts.length}个');
    for (var account in _recentAccounts) {
      debugPrint('[LoginForm] 账号: ${account.account}, 邮箱: ${account.generatedEmail}, 注册时间: ${account.registeredAt}');
    }

    try {
      // 加载保存的账号
      final account = prefs.getString('account') ?? '';

      // 检查是否是从切换账号进入的登录页面
      final isSwitchingAccount = prefs.getBool('is_switching_account') ?? false;

      // 如果是切换账号，清除标记并禁用自动登录
      if (isSwitchingAccount) {
        await prefs.setBool('is_switching_account', false);
        debugPrint('[LoginForm] 检测到账号切换，禁用自动登录');
      }

      if (account.isNotEmpty) {
        // 尝试加载账号特定设置
        final accountKey = 'account_settings_$account';
        final settingsStr = prefs.getString(accountKey);

        if (settingsStr != null && settingsStr.isNotEmpty) {
          // 使用账号特定设置
          final settings = jsonDecode(settingsStr);
          final savedPassword = settings['password'] as String?;
          final savedRememberPwd = settings['rememberPwd'] as bool?;
          // 如果是切换账号，则禁用自动登录
          final savedAutoLogin = isSwitchingAccount ? false : (settings['autoLogin'] as bool?);

          debugPrint('[LoginForm] 加载账号特定设置: account=$account, rememberPwd=$savedRememberPwd, autoLogin=${isSwitchingAccount ? "false (切换账号)" : savedAutoLogin}');

          if (mounted) {
            setState(() {
              userCtrl.text = account;

              // 如果有保存的设置，使用保存的设置
              if (savedRememberPwd == true && savedPassword != null) {
                pwdCtrl.text = savedPassword;
                rememberPwd = true;
                // 如果是切换账号，则禁用自动登录
                autoLogin = isSwitchingAccount ? false : (savedAutoLogin ?? false);
                debugPrint('[LoginForm] 已加载账号特定的密码和自动登录设置');
              } else {
                pwdCtrl.text = '';
                rememberPwd = true;  // 默认勾选记住密码
                autoLogin = false;   // 默认不勾选自动登录
                debugPrint('[LoginForm] 账号特定设置中未保存密码');
              }
            });
          }
        } else {
          // 如果没有账号特定设置，尝试使用通用设置（向后兼容）
          final savedRememberPwd = prefs.getBool('rememberPwd');
          final savedPassword = savedRememberPwd == true ? (prefs.getString('password') ?? '') : '';
          // 如果是切换账号，则禁用自动登录
          final savedAutoLogin = isSwitchingAccount ? false : (savedRememberPwd == true ? (prefs.getBool('autoLogin') ?? false) : false);

          debugPrint('[LoginForm] 使用通用设置: account=$account, rememberPwd=$savedRememberPwd, autoLogin=${isSwitchingAccount ? "false (切换账号)" : savedAutoLogin}');

          if (mounted) {
            setState(() {
              userCtrl.text = account;

              // 根据平台设置默认值
              final isDesktop = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform);

              // 如果有保存的设置，使用保存的设置；否则使用默认值
              rememberPwd = savedRememberPwd ?? (isDesktop ? true : false);

              // 如果设置了"记住密码"，则加载保存的密码
              if (rememberPwd == true) {
                pwdCtrl.text = savedPassword;
                // 如果是切换账号，则禁用自动登录
                autoLogin = isSwitchingAccount ? false : (savedAutoLogin ?? false);
                debugPrint('[LoginForm] 已加载通用设置的密码和自动登录设置');
              } else {
                pwdCtrl.text = '';
                autoLogin = false;
                debugPrint('[LoginForm] 通用设置中未保存密码');
              }
            });
          }
        }
      } else {
        // 没有保存的账号，使用默认值
        if (mounted) {
          setState(() {
            final isDesktop = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform);
            rememberPwd = isDesktop ? true : false;
            autoLogin = false;
            debugPrint('[LoginForm] 没有保存的账号，使用默认设置');
          });
        }
      }
    } catch (e, s) {
      debugPrint('[LoginForm][Error] 加载设置异常: $e\n$s');
      // 出错时使用默认值
      if (mounted) {
        setState(() {
          final isDesktop = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform);
          rememberPwd = isDesktop ? true : false;
          autoLogin = false;
        });
      }
    }
  }

  Future<void> _login() async {
    // 清除之前的错误信息并显示加载状态
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _loginSuccess = false;
    });

    // 验证输入
    if (userCtrl.text.isEmpty || pwdCtrl.text.isEmpty) {
      setState(() {
        _errorMessage = '请输入账号和密码';
        _isLoading = false;
      });
      return;
    }

    // 按下按钮动画
    _animationController.forward();
    await Future.delayed(Duration(milliseconds: 150));
    _animationController.reverse();

    debugPrint('[DEBUG] 开始登录流程');
    Map<String, dynamic> resp = {};

    try {
      debugPrint('[DEBUG] 开始调用LoginFormService.login');
      resp = await LoginFormService.login(userCtrl.text, pwdCtrl.text);
      debugPrint('[DEBUG] LoginFormService.login返回: $resp');
    } catch (e, s) {
      debugPrint('[ERROR] LoginFormService.login异常: $e\n$s');
      if (mounted) {
        setState(() {
          _errorMessage = '网络异常，请稍后重试';
          _isLoading = false;
        });
      }
      return;
    }

    final token = resp['token'] ?? (resp['data'] != null ? resp['data']['token'] : null);
    final isSuccess = (resp['code'] == 0) || (resp['success'] == true);

    if (isSuccess && token != null && token.toString().isNotEmpty) {
      debugPrint('[Login][DEBUG] 登录API返回token: $token');
      try {
        // 保存token
        await LoginFormService.saveToken(token);
        debugPrint('[Login][DEBUG] LoginFormService.saveToken已执行');

        // 保存用户信息
        if (resp['data'] != null && resp['data']['user'] != null) {
          await LoginFormService.saveUserInfo(resp['data']['user']);
          debugPrint('[Login][DEBUG] 用户信息已保存');

          // 清除缓存的用户信息，确保下次获取时使用最新数据
          LoginFormService.clearCachedUserInfo();
        } else {
          debugPrint('[Login][WARN] 登录响应中没有用户信息');
        }
      } catch (e, s) {
        debugPrint('[Login][Error] 保存token或用户信息异常: $e\n$s');
        if (mounted) {
          setState(() {
            _errorMessage = '登录成功但保存状态失败';
            _isLoading = false;
          });
        }
        return;
      }

      debugPrint('[Login] 登录成功，token已保存: $token');
      debugPrint('[Login] autoLogin=$autoLogin');

      await _savePrefs();

      if (mounted) {
        // 显示成功状态（不使用弹窗）
        setState(() {
          _isLoading = false;
          _loginSuccess = true;
        });

        // 短暂延迟后跳转
        await Future.delayed(Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/social');
        }
      }
    } else {
      debugPrint('[Login][Error] 登录失败或未返回token, resp=$resp');
      if (mounted) {
        String msg = resp['msg']?.toString() ?? '登录失败';
        if (!(token != null && token.toString().isNotEmpty)) {
          msg += '，请检查账号密码';
        }

        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final account = userCtrl.text;

      // 保存账号 (无论是否记住密码，都保存账号以便下次自动填充)
      await prefs.setString('account', account);
      debugPrint('[Login] 已保存账号: $account');

      // 保存账号特定设置
      final accountKey = 'account_settings_$account';

      // 根据"记住密码"选项决定是否保存密码
      if (rememberPwd == true) {
        // 创建账号特定设置
        final accountSettings = {
          'password': pwdCtrl.text,
          'rememberPwd': true,
          'autoLogin': autoLogin == true,
          'lastLogin': DateTime.now().millisecondsSinceEpoch,
        };

        // 保存账号特定设置
        final maskedPassword = pwdCtrl.text.replaceAll(RegExp(r'.'), '*');
        debugPrint('[Login] 保存账号特定设置: $account, 密码: $maskedPassword, 自动登录: $autoLogin');
        await prefs.setString(accountKey, jsonEncode(accountSettings));

        // 同时保存到通用设置（向后兼容）
        await prefs.setString('password', pwdCtrl.text);
        await prefs.setBool('rememberPwd', true);
        await prefs.setBool('autoLogin', autoLogin == true);

        // 验证保存是否成功
        final savedSettings = prefs.getString(accountKey);
        debugPrint('[Login] 验证保存结果: 账号特定设置=${savedSettings != null}');
      } else {
        // 不保存密码，清除相关设置
        debugPrint('[Login] 不保存密码，清除账号特定设置: $account');
        await prefs.remove(accountKey);

        // 同时清除通用设置（向后兼容）
        await prefs.remove('password');
        await prefs.setBool('rememberPwd', false);
        await prefs.setBool('autoLogin', false);
      }
    } catch (e, s) {
      debugPrint('[Login][Error] 保存设置异常: $e\n$s');
    }
  }

  // 加载特定账号的设置
  Future<void> _loadAccountSettings(String account) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 检查是否有针对该账号的特定设置
      final accountKey = 'account_settings_$account';
      final settingsStr = prefs.getString(accountKey);

      if (settingsStr != null && settingsStr.isNotEmpty) {
        // 解析账号特定设置
        final settings = jsonDecode(settingsStr);
        final savedPassword = settings['password'] as String?;
        final savedRememberPwd = settings['rememberPwd'] as bool?;
        // 切换账号时不自动登录，即使之前设置了自动登录
        final savedAutoLogin = false;

        debugPrint('[LoginForm] 加载账号特定设置: account=$account, rememberPwd=$savedRememberPwd, autoLogin=false (切换账号时禁用自动登录)');

        if (mounted) {
          setState(() {
            if (savedRememberPwd == true && savedPassword != null) {
              pwdCtrl.text = savedPassword;
              rememberPwd = true;
              // 切换账号时，始终禁用自动登录
              autoLogin = false;
            } else {
              pwdCtrl.text = '';
              rememberPwd = false;
              autoLogin = false;
            }
          });
        }
      } else {
        // 如果没有特定设置，尝试使用通用设置
        final savedPassword = prefs.getString('password');
        final savedRememberPwd = prefs.getBool('rememberPwd');
        // 切换账号时不自动登录
        final savedAutoLogin = false;

        // 只有当保存的账号与当前账号匹配时，才使用通用设置
        final savedAccount = prefs.getString('account');
        if (savedAccount == account && savedRememberPwd == true) {
          if (mounted) {
            setState(() {
              pwdCtrl.text = savedPassword ?? '';
              rememberPwd = true;
              // 切换账号时，始终禁用自动登录
              autoLogin = false;
            });
          }
        } else {
          // 否则清空密码字段
          if (mounted) {
            setState(() {
              pwdCtrl.text = '';
              rememberPwd = true;  // 默认勾选记住密码
              autoLogin = false;   // 默认不勾选自动登录
            });
          }
        }
      }
    } catch (e, s) {
      debugPrint('[LoginForm][Error] 加载账号设置异常: $e\n$s');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题部分
        AppAnimations.fadeIn(
          duration: Duration(milliseconds: 600),
          child: Column(
            children: [
              Text(
                '欢迎回来',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '使用QQ号/手机号/邮箱登录',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
        if (_loginSuccess)
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
                      '登录成功，正在跳转...',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 最近注册的账号列表
        if (_recentAccounts.isNotEmpty)
          AppAnimations.fadeIn(
            duration: Duration(milliseconds: 650),
            child: Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '最近注册的账号',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _recentAccounts.length > 3 ? 3 : _recentAccounts.length,
                    itemBuilder: (context, index) {
                      final account = _recentAccounts[index];
                      return ListTile(
                        dense: true,
                        title: Text(account.account),
                        subtitle: Text(account.generatedEmail),
                        trailing: Icon(Icons.login, size: 16, color: AppTheme.primaryColor),
                        onTap: () async {
                          // 设置切换账号标记
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('is_switching_account', true);

                          setState(() {
                            userCtrl.text = account.account;

                            // 当切换账号时，尝试加载该账号的密码和自动登录设置
                            _loadAccountSettings(account.account);
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

        // 账号输入框
        AppAnimations.fadeIn(
          duration: Duration(milliseconds: 700),
          child: TextField(
            controller: userCtrl,
            focusNode: userFocusNode,
            enabled: !_isLoading && !_loginSuccess,
            // 添加文本输入操作，处理回车键
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              // 当按下回车键时，焦点移动到密码输入框
              FocusScope.of(context).requestFocus(pwdFocusNode);
            },
            decoration: InputDecoration(
              labelText: '账号/手机号/邮箱',
              hintText: '请输入账号/手机号/邮箱',
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
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        SizedBox(height: 16),

        // 密码输入框
        AppAnimations.fadeIn(
          duration: Duration(milliseconds: 800),
          child: TextField(
            controller: pwdCtrl,
            focusNode: pwdFocusNode,
            obscureText: _obscurePassword,
            enabled: !_isLoading && !_loginSuccess,
            // 添加文本输入操作，处理回车键
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              // 当按下回车键时，触发登录操作
              if (!_isLoading && !_loginSuccess) {
                _login();
              }
            },
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
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
              contentPadding: EdgeInsets.symmetric(vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
        ),
        SizedBox(height: 8),

        // 记住密码和自动登录选项
        if ([TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform))
          AppAnimations.fadeIn(
            duration: Duration(milliseconds: 900),
            child: Row(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    checkboxTheme: CheckboxThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  child: Checkbox(
                    value: rememberPwd ?? true,
                    activeColor: AppTheme.primaryColor,
                    onChanged: !_isLoading && !_loginSuccess
                        ? (val) {
                            setState(() {
                              rememberPwd = val;
                              // 如果取消"记住密码"，则自动取消"自动登录"
                              if (val == false) {
                                autoLogin = false;
                              }
                            });
                          }
                        : null,
                  ),
                ),
                Text(
                  '记住密码',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                SizedBox(width: 16),
                Theme(
                  data: Theme.of(context).copyWith(
                    checkboxTheme: CheckboxThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  child: Checkbox(
                    value: autoLogin ?? false,
                    activeColor: AppTheme.primaryColor,
                    // 只有在"记住密码"被勾选时，"自动登录"才可用
                    onChanged: ((rememberPwd ?? true) == true && !_isLoading && !_loginSuccess)
                        ? (val) {
                            setState(() {
                              // 设置自动登录状态
                              autoLogin = val;
                            });
                          }
                        : null,
                  ),
                ),
                Text(
                  '自动登录',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 24),

        // 登录按钮
        AppAnimations.fadeIn(
          duration: Duration(milliseconds: 1000),
          child: ScaleTransition(
            scale: _buttonAnimation,
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
                onPressed: !_isLoading && !_loginSuccess ? _login : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '登录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),

        // 底部链接
        AppAnimations.fadeIn(
          duration: Duration(milliseconds: 1100),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: !_isLoading && !_loginSuccess
                    ? () {
                        // 忘记密码
                      }
                    : null,
                child: Text(
                  '忘记密码?',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
