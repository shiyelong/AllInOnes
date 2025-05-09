import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 平台工具类
/// 用于判断当前平台、设置平台特定功能等
class PlatformUtils {
  /// 是否是移动平台（iOS或Android）
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// 是否是桌面平台（Windows、macOS或Linux）
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 是否是Web平台
  static bool get isWeb => kIsWeb;

  /// 获取平台名称
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'Unknown';
  }

  /// 初始化桌面窗口设置
  static Future<void> initDesktopWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      debugPrint('[PlatformUtils] 桌面窗口初始化成功');
    } catch (e) {
      debugPrint('[PlatformUtils] 桌面窗口初始化失败: $e');
    }
  }

  /// 设置窗口标题
  static Future<void> setWindowTitle(String title) async {
    if (!isDesktop) return;

    try {
      await windowManager.setTitle(title);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口标题失败: $e');
    }
  }

  /// 设置窗口大小
  static Future<void> setWindowSize(double width, double height) async {
    if (!isDesktop) return;

    try {
      await windowManager.setSize(Size(width, height));
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口大小失败: $e');
    }
  }

  /// 设置窗口最小大小
  static Future<void> setMinWindowSize(double width, double height) async {
    if (!isDesktop) return;

    try {
      await windowManager.setMinimumSize(Size(width, height));
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口最小大小失败: $e');
    }
  }

  /// 设置窗口最大大小
  static Future<void> setMaxWindowSize(double width, double height) async {
    if (!isDesktop) return;

    try {
      await windowManager.setMaximumSize(Size(width, height));
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口最大大小失败: $e');
    }
  }

  /// 设置窗口是否可调整大小
  static Future<void> setResizable(bool resizable) async {
    if (!isDesktop) return;

    try {
      await windowManager.setResizable(resizable);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口是否可调整大小失败: $e');
    }
  }

  /// 设置窗口是否可移动
  static Future<void> setMovable(bool movable) async {
    if (!isDesktop) return;

    try {
      await windowManager.setMovable(movable);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口是否可移动失败: $e');
    }
  }

  /// 设置窗口是否可最小化
  static Future<void> setMinimizable(bool minimizable) async {
    if (!isDesktop) return;

    try {
      await windowManager.setMinimizable(minimizable);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口是否可最小化失败: $e');
    }
  }

  /// 设置窗口是否可最大化
  static Future<void> setMaximizable(bool maximizable) async {
    if (!isDesktop) return;

    try {
      await windowManager.setMaximizable(maximizable);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口是否可最大化失败: $e');
    }
  }

  /// 设置窗口是否可关闭
  static Future<void> setClosable(bool closable) async {
    if (!isDesktop) return;

    try {
      await windowManager.setClosable(closable);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口是否可关闭失败: $e');
    }
  }

  /// 设置窗口是否总是在最前面
  static Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    if (!isDesktop) return;

    try {
      await windowManager.setAlwaysOnTop(alwaysOnTop);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口是否总是在最前面失败: $e');
    }
  }

  /// 设置窗口是否全屏
  static Future<void> setFullScreen(bool fullScreen) async {
    if (!isDesktop) return;

    try {
      await windowManager.setFullScreen(fullScreen);
    } catch (e) {
      debugPrint('[PlatformUtils] 设置窗口是否全屏失败: $e');
    }
  }

  /// 最小化窗口
  static Future<void> minimizeWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.minimize();
    } catch (e) {
      debugPrint('[PlatformUtils] 最小化窗口失败: $e');
    }
  }

  /// 最大化窗口
  static Future<void> maximizeWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.maximize();
    } catch (e) {
      debugPrint('[PlatformUtils] 最大化窗口失败: $e');
    }
  }

  /// 恢复窗口
  static Future<void> restoreWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.restore();
    } catch (e) {
      debugPrint('[PlatformUtils] 恢复窗口失败: $e');
    }
  }

  /// 关闭窗口
  static Future<void> closeWindow() async {
    if (!isDesktop) return;

    try {
      await windowManager.close();
    } catch (e) {
      debugPrint('[PlatformUtils] 关闭窗口失败: $e');
    }
  }
}
