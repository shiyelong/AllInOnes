import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/modules/auth/login/login_form/login_form.dart';
import 'package:frontend/modules/auth/login/video/video_widget.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  bool get isDesktop => [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(defaultTargetPlatform);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          VideoWidget(),
          Center(
            child: SingleChildScrollView(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]!.withOpacity(0.92)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 32,
                      offset: Offset(0, 16),
                    ),
                  ],
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
                    LoginForm(),
                    SizedBox(height: 18),
                    // 社交登录
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
