import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../video_call_page.dart';
import '../voice_call_page.dart';

/// 全局导航键，用于在任何地方访问导航器
final GlobalKey<NavigatorState> simplifiedNavigatorKey = GlobalKey<NavigatorState>();

/// 简化版通话管理器
/// 
/// 提供基本的语音和视频通话功能，不依赖于复杂的WebRTC实现
class SimplifiedCallManager {
  // 单例模式
  static final SimplifiedCallManager _instance = SimplifiedCallManager._internal();
  factory SimplifiedCallManager() => _instance;
  SimplifiedCallManager._internal();

  // 当前通话状态
  bool _isInCall = false;
  String? _currentCallId;
  String? _currentCallType;
  String? _currentTargetId;
  Timer? _callTimer;
  int _callDuration = 0;

  // 获取当前通话状态
  bool get isInCall => _isInCall;
  String? get currentCallId => _currentCallId;
  String? get currentCallType => _currentCallType;
  String? get currentTargetId => _currentTargetId;
  int get callDuration => _callDuration;

  // 初始化通话管理器
  Future<void> initialize() async {
    debugPrint('[SimplifiedCallManager] 初始化');
    // 可以在这里添加初始化代码，如WebSocket连接等
  }

  // 开始语音通话
  void startVoiceCall(String targetId, String targetName, String? targetAvatar) {
    if (_isInCall) {
      debugPrint('[SimplifiedCallManager] 已经在通话中，无法发起新通话');
      return;
    }

    debugPrint('[SimplifiedCallManager] 发起语音通话: $targetId, $targetName');
    
    // 生成通话ID
    _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentCallType = 'voice';
    _currentTargetId = targetId;
    _isInCall = true;
    
    // 打开语音通话页面
    simplifiedNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => VoiceCallPage(
          callId: _currentCallId!,
          targetId: targetId,
          targetName: targetName,
          targetAvatar: targetAvatar,
          onCallEnded: _handleCallEnded,
        ),
      ),
    );
    
    // 开始计时
    _startCallTimer();
  }

  // 开始视频通话
  void startVideoCall(String targetId, String targetName, String? targetAvatar) {
    if (_isInCall) {
      debugPrint('[SimplifiedCallManager] 已经在通话中，无法发起新通话');
      return;
    }

    debugPrint('[SimplifiedCallManager] 发起视频通话: $targetId, $targetName');
    
    // 生成通话ID
    _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentCallType = 'video';
    _currentTargetId = targetId;
    _isInCall = true;
    
    // 打开视频通话页面
    simplifiedNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => VideoCallPage(
          callId: _currentCallId!,
          targetId: targetId,
          targetName: targetName,
          targetAvatar: targetAvatar,
          onCallEnded: _handleCallEnded,
        ),
      ),
    );
    
    // 开始计时
    _startCallTimer();
  }

  // 结束通话
  void endCall() {
    if (!_isInCall) {
      debugPrint('[SimplifiedCallManager] 没有正在进行的通话');
      return;
    }

    debugPrint('[SimplifiedCallManager] 结束通话: $_currentCallId');
    
    // 停止计时
    _stopCallTimer();
    
    // 重置通话状态
    _isInCall = false;
    _currentCallId = null;
    _currentCallType = null;
    _currentTargetId = null;
    _callDuration = 0;
  }

  // 处理通话结束事件
  void _handleCallEnded() {
    debugPrint('[SimplifiedCallManager] 通话已结束');
    endCall();
  }

  // 开始通话计时器
  void _startCallTimer() {
    _callDuration = 0;
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _callDuration++;
    });
  }

  // 停止通话计时器
  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  // 格式化通话时长
  String formatCallDuration() {
    final minutes = (_callDuration / 60).floor();
    final seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
