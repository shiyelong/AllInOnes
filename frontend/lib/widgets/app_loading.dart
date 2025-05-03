import 'package:flutter/material.dart';
import '../common/theme.dart';

enum LoadingSize { small, medium, large }
enum LoadingType { circular, linear }

class AppLoading extends StatelessWidget {
  final LoadingSize size;
  final LoadingType type;
  final Color? color;
  final String? message;
  final bool overlay;
  final double? value;

  const AppLoading({
    Key? key,
    this.size = LoadingSize.medium,
    this.type = LoadingType.circular,
    this.color,
    this.message,
    this.overlay = false,
    this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 确定尺寸
    double indicatorSize;
    double fontSize;
    switch (size) {
      case LoadingSize.small:
        indicatorSize = 16;
        fontSize = 12;
        break;
      case LoadingSize.medium:
        indicatorSize = 24;
        fontSize = 14;
        break;
      case LoadingSize.large:
        indicatorSize = 36;
        fontSize = 16;
        break;
    }

    // 确定颜色
    final indicatorColor = color ?? AppTheme.primaryColor;

    // 构建加载指示器
    Widget indicator;
    if (type == LoadingType.circular) {
      indicator = SizedBox(
        width: indicatorSize,
        height: indicatorSize,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: size == LoadingSize.small ? 2 : 3,
          valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
        ),
      );
    } else {
      indicator = SizedBox(
        width: 100,
        height: 4,
        child: LinearProgressIndicator(
          value: value,
          valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
          backgroundColor: indicatorColor.withOpacity(0.2),
        ),
      );
    }

    // 添加消息
    Widget content;
    if (message != null && message!.isNotEmpty) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          SizedBox(height: 12),
          Text(
            message!,
            style: TextStyle(
              fontSize: fontSize,
              color: Theme.of(context).brightness == Brightness.light
                  ? AppTheme.textSecondaryColor
                  : Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      content = indicator;
    }

    // 添加遮罩
    if (overlay) {
      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        ],
      );
    }

    return Center(child: content);
  }
}
