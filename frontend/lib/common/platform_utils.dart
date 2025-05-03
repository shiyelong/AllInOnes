import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:window_manager/window_manager.dart';

/// 平台工具类，用于检测当前平台并提供平台特定的功能
class PlatformUtils {
  /// 是否是Web平台
  static bool get isWeb => kIsWeb;

  /// 是否是移动平台（iOS或Android）
  static bool get isMobile => !isWeb && (Platform.isIOS || Platform.isAndroid);

  /// 是否是桌面平台（Windows、macOS或Linux）
  static bool get isDesktop => !isWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// 是否是iOS平台
  static bool get isIOS => !isWeb && Platform.isIOS;

  /// 是否是Android平台
  static bool get isAndroid => !isWeb && Platform.isAndroid;

  /// 是否是Windows平台
  static bool get isWindows => !isWeb && Platform.isWindows;

  /// 是否是macOS平台
  static bool get isMacOS => !isWeb && Platform.isMacOS;

  /// 是否是Linux平台
  static bool get isLinux => !isWeb && Platform.isLinux;

  /// 获取当前平台名称
  static String get platformName {
    if (isWeb) return 'Web';
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  /// 初始化桌面窗口设置
  static Future<void> initDesktopWindow() async {
    if (!isDesktop) return;

    try {
      // 初始化窗口管理器
      await windowManager.ensureInitialized();

      // 设置窗口标题
      await windowManager.setTitle('AllInOne');

      // 设置窗口大小
      await windowManager.setSize(Size(1200, 800));

      // 设置窗口最小大小
      await windowManager.setMinimumSize(Size(800, 600));

      // 设置窗口居中
      await windowManager.center();

      // 显示窗口
      await windowManager.show();

      // 设置窗口可调整大小
      await windowManager.setResizable(true);
    } catch (e) {
      debugPrint('初始化桌面窗口失败: $e');
    }
  }

  /// 设置桌面窗口大小
  static Future<void> setWindowSize(Size size) async {
    if (!isDesktop) return;

    try {
      await DesktopWindow.setWindowSize(size);
    } catch (e) {
      debugPrint('设置窗口大小失败: $e');
    }
  }

  /// 设置桌面窗口最小大小
  static Future<void> setMinWindowSize(Size size) async {
    if (!isDesktop) return;

    try {
      await DesktopWindow.setMinWindowSize(size);
    } catch (e) {
      debugPrint('设置窗口最小大小失败: $e');
    }
  }

  /// 设置桌面窗口最大大小
  static Future<void> setMaxWindowSize(Size size) async {
    if (!isDesktop) return;

    try {
      await DesktopWindow.setMaxWindowSize(size);
    } catch (e) {
      debugPrint('设置窗口最大大小失败: $e');
    }
  }

  /// 切换全屏模式
  static Future<void> toggleFullScreen() async {
    if (!isDesktop) return;

    try {
      final isFullScreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFullScreen);
    } catch (e) {
      debugPrint('切换全屏模式失败: $e');
    }
  }

  /// 最小化窗口
  static Future<void> minimizeWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.minimize();
    } catch (e) {
      debugPrint('最小化窗口失败: $e');
    }
  }

  /// 最大化窗口
  static Future<void> maximizeWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.maximize();
    } catch (e) {
      debugPrint('最大化窗口失败: $e');
    }
  }

  /// 关闭窗口
  static Future<void> closeWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.close();
    } catch (e) {
      debugPrint('关闭窗口失败: $e');
    }
  }

  /// 获取平台特定的边距
  static EdgeInsets get platformPadding {
    if (isMobile) {
      return EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    } else if (isDesktop) {
      return EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    } else {
      return EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    }
  }

  /// 获取平台特定的圆角半径
  static double get platformBorderRadius {
    if (isMobile) {
      return 12.0;
    } else if (isDesktop) {
      return 8.0;
    } else {
      return 10.0;
    }
  }

  /// 获取平台特定的动画时长
  static Duration get platformAnimationDuration {
    if (isMobile) {
      return Duration(milliseconds: 300);
    } else {
      return Duration(milliseconds: 200);
    }
  }

  /// 获取平台特定的字体大小
  static double getPlatformFontSize(double baseFontSize) {
    if (isMobile) {
      return baseFontSize;
    } else if (isDesktop) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize * 1.05;
    }
  }
}
