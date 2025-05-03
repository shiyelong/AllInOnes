import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ThemeManager {
  static const String _themeKey = 'app_theme';
  static const String _customThemeKey = 'custom_theme';

  // 单例实例
  static final ThemeManager instance = ThemeManager._internal();

  // 私有构造函数
  ThemeManager._internal();

  // 判断是否是桌面平台
  bool get isDesktop {
    // 在 macOS, Windows, Linux 上返回 true
    return true; // 简化处理，始终返回 true
  }

  // 预定义的主题
  static final List<AppThemeData> predefinedThemes = [
    AppThemeData(
      id: 'default_light',
      name: '默认浅色',
      primaryColor: Color(0xFF12B7F5),
      backgroundColor: Color(0xFFF5F5F5),
      cardColor: Colors.white,
      textColor: Color(0xFF212121),
      selfMessageBubbleColor: Color(0xFF12B7F5),
      otherMessageBubbleColor: Color(0xFFE0E0E0),
      selfMessageTextColor: Colors.white,
      otherMessageTextColor: Color(0xFF212121),
      isDark: false,
    ),
    AppThemeData(
      id: 'default_dark',
      name: '默认深色',
      primaryColor: Color(0xFF0D73BB),
      backgroundColor: Color(0xFF121212),
      cardColor: Color(0xFF1E1E1E),
      textColor: Colors.white,
      selfMessageBubbleColor: Color(0xFF0D73BB),
      otherMessageBubbleColor: Color(0xFF2C2C2C),
      selfMessageTextColor: Colors.white,
      otherMessageTextColor: Colors.white,
      isDark: true,
    ),
    AppThemeData(
      id: 'green_light',
      name: '绿色主题',
      primaryColor: Color(0xFF4CAF50),
      backgroundColor: Color(0xFFF5F5F5),
      cardColor: Colors.white,
      textColor: Color(0xFF212121),
      selfMessageBubbleColor: Color(0xFF4CAF50),
      otherMessageBubbleColor: Color(0xFFE0E0E0),
      selfMessageTextColor: Colors.white,
      otherMessageTextColor: Color(0xFF212121),
      isDark: false,
    ),
    AppThemeData(
      id: 'purple_light',
      name: '紫色主题',
      primaryColor: Color(0xFF9C27B0),
      backgroundColor: Color(0xFFF5F5F5),
      cardColor: Colors.white,
      textColor: Color(0xFF212121),
      selfMessageBubbleColor: Color(0xFF9C27B0),
      otherMessageBubbleColor: Color(0xFFE0E0E0),
      selfMessageTextColor: Colors.white,
      otherMessageTextColor: Color(0xFF212121),
      isDark: false,
    ),
    AppThemeData(
      id: 'orange_light',
      name: '橙色主题',
      primaryColor: Color(0xFFFF9800),
      backgroundColor: Color(0xFFF5F5F5),
      cardColor: Colors.white,
      textColor: Color(0xFF212121),
      selfMessageBubbleColor: Color(0xFFFF9800),
      otherMessageBubbleColor: Color(0xFFE0E0E0),
      selfMessageTextColor: Colors.white,
      otherMessageTextColor: Color(0xFF212121),
      isDark: false,
    ),
  ];

  // 当前主题
  static AppThemeData _currentTheme = predefinedThemes[0];

  // 获取当前主题
  static AppThemeData get currentTheme => _currentTheme;

  // 初始化主题
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final themeId = prefs.getString(_themeKey);

    if (themeId != null) {
      // 查找预定义主题
      final theme = predefinedThemes.firstWhere(
        (theme) => theme.id == themeId,
        orElse: () => predefinedThemes[0],
      );
      _currentTheme = theme;
    } else {
      // 使用默认主题
      _currentTheme = predefinedThemes[0];
    }

    // 检查是否有自定义主题
    final customThemeJson = prefs.getString(_customThemeKey);
    if (customThemeJson != null) {
      try {
        final customTheme = AppThemeData.fromJson(json.decode(customThemeJson));
        if (customTheme.id == themeId) {
          _currentTheme = customTheme;
        }
      } catch (e) {
        print('加载自定义主题失败: $e');
      }
    }
  }

  // 设置主题
  static Future<void> setTheme(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeId);

    // 查找预定义主题
    final theme = predefinedThemes.firstWhere(
      (theme) => theme.id == themeId,
      orElse: () {
        // 检查是否有自定义主题
        final customThemeJson = prefs.getString(_customThemeKey);
        if (customThemeJson != null) {
          try {
            final customTheme = AppThemeData.fromJson(json.decode(customThemeJson));
            if (customTheme.id == themeId) {
              return customTheme;
            }
          } catch (e) {
            print('加载自定义主题失败: $e');
          }
        }
        return predefinedThemes[0];
      },
    );

    _currentTheme = theme;
  }

  // 保存自定义主题
  static Future<void> saveCustomTheme(AppThemeData theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customThemeKey, json.encode(theme.toJson()));
    await prefs.setString(_themeKey, theme.id);
    _currentTheme = theme;
  }

  // 获取主题数据
  static ThemeData getThemeData() {
    return ThemeData(
      primaryColor: _currentTheme.primaryColor,
      scaffoldBackgroundColor: _currentTheme.backgroundColor,
      cardColor: _currentTheme.cardColor,
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: _currentTheme.textColor),
        bodyMedium: TextStyle(color: _currentTheme.textColor),
      ),
      colorScheme: ColorScheme(
        primary: _currentTheme.primaryColor,
        secondary: _currentTheme.primaryColor,
        surface: _currentTheme.cardColor,
        background: _currentTheme.backgroundColor,
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _currentTheme.textColor,
        onBackground: _currentTheme.textColor,
        onError: Colors.white,
        brightness: _currentTheme.isDark ? Brightness.dark : Brightness.light,
      ),
      brightness: _currentTheme.isDark ? Brightness.dark : Brightness.light,
    );
  }
}

class AppThemeData {
  final String id;
  final String name;
  final Color primaryColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color textColor;
  final Color selfMessageBubbleColor;
  final Color otherMessageBubbleColor;
  final Color selfMessageTextColor;
  final Color otherMessageTextColor;
  final bool isDark;

  AppThemeData({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
    required this.selfMessageBubbleColor,
    required this.otherMessageBubbleColor,
    required this.selfMessageTextColor,
    required this.otherMessageTextColor,
    required this.isDark,
  });

  // 从JSON创建主题
  factory AppThemeData.fromJson(Map<String, dynamic> json) {
    return AppThemeData(
      id: json['id'],
      name: json['name'],
      primaryColor: Color(json['primaryColor']),
      backgroundColor: Color(json['backgroundColor']),
      cardColor: Color(json['cardColor']),
      textColor: Color(json['textColor']),
      selfMessageBubbleColor: Color(json['selfMessageBubbleColor']),
      otherMessageBubbleColor: Color(json['otherMessageBubbleColor']),
      selfMessageTextColor: Color(json['selfMessageTextColor']),
      otherMessageTextColor: Color(json['otherMessageTextColor']),
      isDark: json['isDark'],
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryColor': primaryColor.value,
      'backgroundColor': backgroundColor.value,
      'cardColor': cardColor.value,
      'textColor': textColor.value,
      'selfMessageBubbleColor': selfMessageBubbleColor.value,
      'otherMessageBubbleColor': otherMessageBubbleColor.value,
      'selfMessageTextColor': selfMessageTextColor.value,
      'otherMessageTextColor': otherMessageTextColor.value,
      'isDark': isDark,
    };
  }

  // 创建自定义主题
  factory AppThemeData.custom({
    required String name,
    required Color primaryColor,
    required Color selfMessageBubbleColor,
    required Color otherMessageBubbleColor,
    bool isDark = false,
  }) {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    return AppThemeData(
      id: id,
      name: name,
      primaryColor: primaryColor,
      backgroundColor: isDark ? Color(0xFF121212) : Color(0xFFF5F5F5),
      cardColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
      textColor: isDark ? Colors.white : Color(0xFF212121),
      selfMessageBubbleColor: selfMessageBubbleColor,
      otherMessageBubbleColor: otherMessageBubbleColor,
      selfMessageTextColor: Colors.white,
      otherMessageTextColor: isDark ? Colors.white : Color(0xFF212121),
      isDark: isDark,
    );
  }
}
