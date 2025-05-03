import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/modules/auth/login/login_form/login_form.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/animations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  bool get isDesktop => [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 登录表单的全局键，用于访问LoginForm的状态
  final GlobalKey<LoginFormState> _formKey = GlobalKey<LoginFormState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 获取路由参数
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      debugPrint('[LoginPage] 收到参数: $args');

      // 延迟一帧，确保LoginForm已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 通过全局键获取LoginForm的状态
        final formState = _formKey.currentState;
        if (formState != null) {
          // 设置账号和密码
          if (args.containsKey('account')) {
            formState.userCtrl.text = args['account'];
          }
          if (args.containsKey('password')) {
            formState.pwdCtrl.text = args['password'];
          }
          // 如果有forcePwdTab参数，则自动切换到密码登录标签
          if (args.containsKey('forcePwdTab') && args['forcePwdTab'] == true) {
            // 这里可以添加切换到密码登录标签的逻辑，如果有的话
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 渐变背景 - QQ风格
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
              ),
            ),
          ),

          // 装饰性气泡元素 - 增加视觉趣味性
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: MediaQuery.of(context).size.width * 0.1,
            child: FadeTransition(
              opacity: _fadeInAnimation,
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
            bottom: MediaQuery.of(context).size.height * 0.15,
            right: MediaQuery.of(context).size.width * 0.15,
            child: FadeTransition(
              opacity: _fadeInAnimation,
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
                      Hero(
                        tag: 'logo',
                        child: SvgPicture.asset('assets/imgs/logo.svg', width: 72, height: 72),
                      ),
                      SizedBox(height: 32),
                      LoginForm(key: _formKey),
                      SizedBox(height: 18),

                      // 注册链接
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '还没有账号？',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/register/new'),
                            child: Text(
                              '立即注册',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 18),
                      // 社交登录
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialLoginButton(
                            icon: Icons.wechat,
                            color: Color(0xFF07C160),
                            onTap: () {},
                          ),
                          SizedBox(width: 20),
                          _buildSocialLoginButton(
                            icon: Icons.chat_bubble,
                            color: Color(0xFF12B7F5),
                            onTap: () {},
                          ),
                        ],
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

  Widget _buildSocialLoginButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }
}
