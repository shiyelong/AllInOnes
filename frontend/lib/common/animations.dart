import 'package:flutter/material.dart';
import 'dart:math' as Math;

class AppAnimations {
  // 页面切换动画
  static PageRouteBuilder<T> pageRouteBuilder<T>({
    required Widget page,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.easeInOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: duration,
      fullscreenDialog: fullscreenDialog,
    );
  }

  // 淡入动画
  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeIn,
    double begin = 0.0,
    double end = 1.0,
  }) {
    // 确保不透明度在有效范围内
    begin = begin.clamp(0.0, 1.0);
    end = end.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        // 确保不透明度在有效范围内
        final opacity = value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: child,
    );
  }

  // 缩放动画
  static Widget scale({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutBack,
    double begin = 0.0,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // 滑动动画
  static Widget slide({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // 组合动画：淡入+缩放
  static Widget fadeInScale({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOutBack,
    double beginOpacity = 0.0,
    double endOpacity = 1.0,
    double beginScale = 0.8,
    double endScale = 1.0,
  }) {
    // 确保不透明度在有效范围内
    beginOpacity = beginOpacity.clamp(0.0, 1.0);
    endOpacity = endOpacity.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final calculatedOpacity = beginOpacity + (endOpacity - beginOpacity) * value;
        final scale = beginScale + (endScale - beginScale) * value;

        // 确保不透明度在有效范围内
        final opacity = calculatedOpacity.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // 脉冲动画
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    double minScale = 0.97,
    double maxScale = 1.03,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        // 使用插值计算当前缩放值
        double currentScale = 1.0;
        if (value < 0.33) {
          // 0.0-0.33: 从1.0到maxScale
          currentScale = 1.0 + (maxScale - 1.0) * (value * 3);
        } else if (value < 0.66) {
          // 0.33-0.66: 从maxScale到minScale
          currentScale = maxScale + (minScale - maxScale) * ((value - 0.33) * 3);
        } else {
          // 0.66-1.0: 从minScale到1.0
          currentScale = minScale + (1.0 - minScale) * ((value - 0.66) * 3);
        }

        return Transform.scale(
          scale: currentScale,
          child: child,
        );
      },
      child: child,
    );
  }

  // 闪烁动画
  static Widget blink({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1000),
    double minOpacity = 0.4,
    double maxOpacity = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        // 使用正弦函数计算当前不透明度
        double calculatedOpacity = minOpacity + (maxOpacity - minOpacity) * (0.5 + 0.5 * Math.sin(value * 2 * Math.pi));
        // 确保不透明度在有效范围内
        double opacity = calculatedOpacity.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: child,
    );
  }
}
