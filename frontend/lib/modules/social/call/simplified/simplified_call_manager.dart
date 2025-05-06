import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/modules/social/call/simplified/simplified_call_dialog.dart';

/// 全局导航键
final GlobalKey<NavigatorState> simplifiedNavigatorKey = GlobalKey<NavigatorState>();

/// 简化版通话管理器
class SimplifiedCallManager {
  // 单例模式
  static final SimplifiedCallManager _instance = SimplifiedCallManager._internal();
  factory SimplifiedCallManager() => _instance;
  SimplifiedCallManager._internal();

  // 当前通话状态
  bool _isInCall = false;

  // Getters
  bool get isInCall => _isInCall;

  /// 初始化
  Future<void> initialize() async {
    debugPrint('[SimplifiedCallManager] 初始化完成');
  }

  /// 发起视频通话
  Future<void> startVideoCall(String targetId, String targetName, String? targetAvatar) async {
    if (_isInCall) {
      debugPrint('[SimplifiedCallManager] 已经在通话中，无法发起新的通话');
      return;
    }

    _isInCall = true;

    try {
      // 显示通话对话框
      final context = simplifiedNavigatorKey.currentContext;
      if (context == null) {
        debugPrint('[SimplifiedCallManager] 无法获取上下文');
        _isInCall = false;
        return;
      }

      final result = await showSimplifiedCallDialog(
        context: context,
        targetId: targetId,
        targetName: targetName,
        targetAvatar: targetAvatar,
        isIncoming: false,
        callType: 'video',
        callId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // 处理结果
      if (result == 'cancel' || result == 'timeout') {
        debugPrint('[SimplifiedCallManager] 通话已取消或超时');
      } else if (result == 'end') {
        debugPrint('[SimplifiedCallManager] 通话已结束');
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 发起视频通话失败: $e');
    } finally {
      _isInCall = false;
    }
  }

  /// 发起语音通话
  Future<void> startVoiceCall(String targetId, String targetName, String? targetAvatar) async {
    if (_isInCall) {
      debugPrint('[SimplifiedCallManager] 已经在通话中，无法发起新的通话');
      return;
    }

    _isInCall = true;

    try {
      // 显示通话对话框
      final context = simplifiedNavigatorKey.currentContext;
      if (context == null) {
        debugPrint('[SimplifiedCallManager] 无法获取上下文');
        _isInCall = false;
        return;
      }

      final result = await showSimplifiedCallDialog(
        context: context,
        targetId: targetId,
        targetName: targetName,
        targetAvatar: targetAvatar,
        isIncoming: false,
        callType: 'voice',
        callId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // 处理结果
      if (result == 'cancel' || result == 'timeout') {
        debugPrint('[SimplifiedCallManager] 通话已取消或超时');
      } else if (result == 'end') {
        debugPrint('[SimplifiedCallManager] 通话已结束');
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 发起语音通话失败: $e');
    } finally {
      _isInCall = false;
    }
  }

  /// 模拟收到来电
  Future<void> simulateIncomingCall({
    required String fromId,
    required String fromName,
    String? fromAvatar,
    required String callType,
  }) async {
    if (_isInCall) {
      debugPrint('[SimplifiedCallManager] 已经在通话中，无法接收新的通话');
      return;
    }

    _isInCall = true;

    try {
      // 显示来电对话框
      final context = simplifiedNavigatorKey.currentContext;
      if (context == null) {
        debugPrint('[SimplifiedCallManager] 无法获取上下文');
        _isInCall = false;
        return;
      }

      final result = await showSimplifiedCallDialog(
        context: context,
        targetId: fromId,
        targetName: fromName,
        targetAvatar: fromAvatar,
        isIncoming: true,
        callType: callType,
        callId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // 处理结果
      if (result == 'accept') {
        debugPrint('[SimplifiedCallManager] 通话已接受');
      } else if (result == 'reject' || result == 'timeout') {
        debugPrint('[SimplifiedCallManager] 通话已拒绝或超时');
      } else if (result == 'end') {
        debugPrint('[SimplifiedCallManager] 通话已结束');
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 处理来电失败: $e');
    } finally {
      _isInCall = false;
    }
  }
}
