import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../common/persistence.dart';
import '../../../../../common/api.dart';

/// 简化版通话管理器
/// 用于管理语音/视频通话
class SimplifiedCallManager {
  static final SimplifiedCallManager _instance = SimplifiedCallManager._internal();
  factory SimplifiedCallManager() => _instance;

  SimplifiedCallManager._internal();

  // 通话状态
  bool _isInCall = false;
  bool _isCallConnected = false;
  bool _isCallMuted = false;
  bool _isCallSpeakerOn = false;
  bool _isCallVideoEnabled = false;
  bool _isCallFrontCamera = true;
  
  // 通话信息
  String? _callId;
  String? _callType; // 'voice' 或 'video'
  String? _callDirection; // 'outgoing' 或 'incoming'
  String? _callTargetId;
  String? _callTargetName;
  String? _callTargetAvatar;
  DateTime? _callStartTime;
  DateTime? _callConnectTime;
  DateTime? _callEndTime;
  
  // 通话状态监听器
  final List<Function(Map<String, dynamic>)> _callStateListeners = [];
  
  // 通话计时器
  Timer? _callTimer;
  int _callDuration = 0;
  
  // 获取通话状态
  bool get isInCall => _isInCall;
  bool get isCallConnected => _isCallConnected;
  bool get isCallMuted => _isCallMuted;
  bool get isCallSpeakerOn => _isCallSpeakerOn;
  bool get isCallVideoEnabled => _isCallVideoEnabled;
  bool get isCallFrontCamera => _isCallFrontCamera;
  
  // 获取通话信息
  String? get callId => _callId;
  String? get callType => _callType;
  String? get callDirection => _callDirection;
  String? get callTargetId => _callTargetId;
  String? get callTargetName => _callTargetName;
  String? get callTargetAvatar => _callTargetAvatar;
  DateTime? get callStartTime => _callStartTime;
  DateTime? get callConnectTime => _callConnectTime;
  DateTime? get callEndTime => _callEndTime;
  int get callDuration => _callDuration;
  
  /// 初始化
  Future<void> initialize() async {
    debugPrint('[SimplifiedCallManager] 初始化');
    
    // 这里可以添加初始化代码
  }
  
  /// 发起语音通话
  Future<Map<String, dynamic>> initiateVoiceCall(String targetId, String targetName, String? targetAvatar) async {
    try {
      // 检查是否已经在通话中
      if (_isInCall) {
        return {
          'success': false,
          'msg': '已经在通话中',
        };
      }
      
      // 检查麦克风权限
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        return {
          'success': false,
          'msg': '麦克风权限被拒绝',
        };
      }
      
      // 调用API发起语音通话
      final response = await Api.initiateVoiceCall(targetId: targetId);
      
      if (response['success'] == true) {
        // 更新通话状态
        _isInCall = true;
        _isCallConnected = false;
        _isCallMuted = false;
        _isCallSpeakerOn = false;
        _isCallVideoEnabled = false;
        
        // 更新通话信息
        _callId = response['data']['call_id'];
        _callType = 'voice';
        _callDirection = 'outgoing';
        _callTargetId = targetId;
        _callTargetName = targetName;
        _callTargetAvatar = targetAvatar;
        _callStartTime = DateTime.now();
        _callConnectTime = null;
        _callEndTime = null;
        
        // 启动通话计时器
        _startCallTimer();
        
        // 通知监听器
        _notifyCallStateListeners();
        
        return {
          'success': true,
          'call_id': _callId,
        };
      } else {
        return {
          'success': false,
          'msg': response['msg'] ?? '发起语音通话失败',
        };
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 发起语音通话失败: $e');
      return {
        'success': false,
        'msg': '发起语音通话异常: $e',
      };
    }
  }
  
  /// 发起视频通话
  Future<Map<String, dynamic>> initiateVideoCall(String targetId, String targetName, String? targetAvatar) async {
    try {
      // 检查是否已经在通话中
      if (_isInCall) {
        return {
          'success': false,
          'msg': '已经在通话中',
        };
      }
      
      // 检查麦克风权限
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        return {
          'success': false,
          'msg': '麦克风权限被拒绝',
        };
      }
      
      // 检查摄像头权限
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        return {
          'success': false,
          'msg': '摄像头权限被拒绝',
        };
      }
      
      // 调用API发起视频通话
      final response = await Api.initiateVideoCall(targetId: targetId);
      
      if (response['success'] == true) {
        // 更新通话状态
        _isInCall = true;
        _isCallConnected = false;
        _isCallMuted = false;
        _isCallSpeakerOn = true;
        _isCallVideoEnabled = true;
        _isCallFrontCamera = true;
        
        // 更新通话信息
        _callId = response['data']['call_id'];
        _callType = 'video';
        _callDirection = 'outgoing';
        _callTargetId = targetId;
        _callTargetName = targetName;
        _callTargetAvatar = targetAvatar;
        _callStartTime = DateTime.now();
        _callConnectTime = null;
        _callEndTime = null;
        
        // 启动通话计时器
        _startCallTimer();
        
        // 通知监听器
        _notifyCallStateListeners();
        
        return {
          'success': true,
          'call_id': _callId,
        };
      } else {
        return {
          'success': false,
          'msg': response['msg'] ?? '发起视频通话失败',
        };
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 发起视频通话失败: $e');
      return {
        'success': false,
        'msg': '发起视频通话异常: $e',
      };
    }
  }
  
  /// 接收来电
  Future<Map<String, dynamic>> receiveIncomingCall(Map<String, dynamic> callData) async {
    try {
      // 检查是否已经在通话中
      if (_isInCall) {
        return {
          'success': false,
          'msg': '已经在通话中',
        };
      }
      
      // 更新通话状态
      _isInCall = true;
      _isCallConnected = false;
      _isCallMuted = false;
      _isCallSpeakerOn = callData['call_type'] == 'video';
      _isCallVideoEnabled = callData['call_type'] == 'video';
      _isCallFrontCamera = true;
      
      // 更新通话信息
      _callId = callData['call_id'];
      _callType = callData['call_type'];
      _callDirection = 'incoming';
      _callTargetId = callData['caller_id'];
      _callTargetName = callData['caller_name'];
      _callTargetAvatar = callData['caller_avatar'];
      _callStartTime = DateTime.now();
      _callConnectTime = null;
      _callEndTime = null;
      
      // 启动通话计时器
      _startCallTimer();
      
      // 通知监听器
      _notifyCallStateListeners();
      
      return {
        'success': true,
        'call_id': _callId,
      };
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 接收来电失败: $e');
      return {
        'success': false,
        'msg': '接收来电异常: $e',
      };
    }
  }
  
  /// 接受通话
  Future<Map<String, dynamic>> acceptCall() async {
    try {
      // 检查是否有来电
      if (!_isInCall || _callDirection != 'incoming' || _callId == null) {
        return {
          'success': false,
          'msg': '没有来电',
        };
      }
      
      // 检查麦克风权限
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        return {
          'success': false,
          'msg': '麦克风权限被拒绝',
        };
      }
      
      // 如果是视频通话，检查摄像头权限
      if (_callType == 'video') {
        final cameraPermission = await Permission.camera.request();
        if (!cameraPermission.isGranted) {
          return {
            'success': false,
            'msg': '摄像头权限被拒绝',
          };
        }
      }
      
      // 调用API接受通话
      final response = _callType == 'voice'
          ? await Api.acceptVoiceCall(callId: _callId!)
          : await Api.acceptVideoCall(callId: _callId!);
      
      if (response['success'] == true) {
        // 更新通话状态
        _isCallConnected = true;
        _callConnectTime = DateTime.now();
        
        // 通知监听器
        _notifyCallStateListeners();
        
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'msg': response['msg'] ?? '接受通话失败',
        };
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 接受通话失败: $e');
      return {
        'success': false,
        'msg': '接受通话异常: $e',
      };
    }
  }
  
  /// 拒绝通话
  Future<Map<String, dynamic>> rejectCall() async {
    try {
      // 检查是否有来电
      if (!_isInCall || _callDirection != 'incoming' || _callId == null) {
        return {
          'success': false,
          'msg': '没有来电',
        };
      }
      
      // 调用API拒绝通话
      final response = _callType == 'voice'
          ? await Api.rejectVoiceCall(callId: _callId!)
          : await Api.rejectVideoCall(callId: _callId!);
      
      if (response['success'] == true) {
        // 结束通话
        _endCall();
        
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'msg': response['msg'] ?? '拒绝通话失败',
        };
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 拒绝通话失败: $e');
      return {
        'success': false,
        'msg': '拒绝通话异常: $e',
      };
    }
  }
  
  /// 挂断通话
  Future<Map<String, dynamic>> hangupCall() async {
    try {
      // 检查是否在通话中
      if (!_isInCall || _callId == null) {
        return {
          'success': false,
          'msg': '没有通话',
        };
      }
      
      // 调用API结束通话
      final response = _callType == 'voice'
          ? await Api.endVoiceCall(callId: _callId!)
          : await Api.endVideoCall(callId: _callId!);
      
      if (response['success'] == true) {
        // 结束通话
        _endCall();
        
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'msg': response['msg'] ?? '挂断通话失败',
        };
      }
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 挂断通话失败: $e');
      return {
        'success': false,
        'msg': '挂断通话异常: $e',
      };
    }
  }
  
  /// 切换麦克风
  Future<Map<String, dynamic>> toggleMute() async {
    try {
      // 检查是否在通话中
      if (!_isInCall) {
        return {
          'success': false,
          'msg': '没有通话',
        };
      }
      
      // 切换麦克风状态
      _isCallMuted = !_isCallMuted;
      
      // 通知监听器
      _notifyCallStateListeners();
      
      return {
        'success': true,
        'is_muted': _isCallMuted,
      };
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 切换麦克风失败: $e');
      return {
        'success': false,
        'msg': '切换麦克风异常: $e',
      };
    }
  }
  
  /// 切换扬声器
  Future<Map<String, dynamic>> toggleSpeaker() async {
    try {
      // 检查是否在通话中
      if (!_isInCall) {
        return {
          'success': false,
          'msg': '没有通话',
        };
      }
      
      // 切换扬声器状态
      _isCallSpeakerOn = !_isCallSpeakerOn;
      
      // 通知监听器
      _notifyCallStateListeners();
      
      return {
        'success': true,
        'is_speaker_on': _isCallSpeakerOn,
      };
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 切换扬声器失败: $e');
      return {
        'success': false,
        'msg': '切换扬声器异常: $e',
      };
    }
  }
  
  /// 切换视频
  Future<Map<String, dynamic>> toggleVideo() async {
    try {
      // 检查是否在视频通话中
      if (!_isInCall || _callType != 'video') {
        return {
          'success': false,
          'msg': '没有视频通话',
        };
      }
      
      // 切换视频状态
      _isCallVideoEnabled = !_isCallVideoEnabled;
      
      // 通知监听器
      _notifyCallStateListeners();
      
      return {
        'success': true,
        'is_video_enabled': _isCallVideoEnabled,
      };
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 切换视频失败: $e');
      return {
        'success': false,
        'msg': '切换视频异常: $e',
      };
    }
  }
  
  /// 切换摄像头
  Future<Map<String, dynamic>> switchCamera() async {
    try {
      // 检查是否在视频通话中
      if (!_isInCall || _callType != 'video' || !_isCallVideoEnabled) {
        return {
          'success': false,
          'msg': '没有视频通话或视频未启用',
        };
      }
      
      // 切换摄像头
      _isCallFrontCamera = !_isCallFrontCamera;
      
      // 通知监听器
      _notifyCallStateListeners();
      
      return {
        'success': true,
        'is_front_camera': _isCallFrontCamera,
      };
    } catch (e) {
      debugPrint('[SimplifiedCallManager] 切换摄像头失败: $e');
      return {
        'success': false,
        'msg': '切换摄像头异常: $e',
      };
    }
  }
  
  /// 添加通话状态监听器
  void addCallStateListener(Function(Map<String, dynamic>) listener) {
    if (!_callStateListeners.contains(listener)) {
      _callStateListeners.add(listener);
    }
  }
  
  /// 移除通话状态监听器
  void removeCallStateListener(Function(Map<String, dynamic>) listener) {
    _callStateListeners.remove(listener);
  }
  
  /// 通知通话状态监听器
  void _notifyCallStateListeners() {
    final callState = {
      'is_in_call': _isInCall,
      'is_call_connected': _isCallConnected,
      'is_call_muted': _isCallMuted,
      'is_call_speaker_on': _isCallSpeakerOn,
      'is_call_video_enabled': _isCallVideoEnabled,
      'is_call_front_camera': _isCallFrontCamera,
      'call_id': _callId,
      'call_type': _callType,
      'call_direction': _callDirection,
      'call_target_id': _callTargetId,
      'call_target_name': _callTargetName,
      'call_target_avatar': _callTargetAvatar,
      'call_start_time': _callStartTime?.millisecondsSinceEpoch,
      'call_connect_time': _callConnectTime?.millisecondsSinceEpoch,
      'call_end_time': _callEndTime?.millisecondsSinceEpoch,
      'call_duration': _callDuration,
    };
    
    for (var listener in _callStateListeners) {
      listener(callState);
    }
  }
  
  /// 启动通话计时器
  void _startCallTimer() {
    // 取消之前的计时器
    _callTimer?.cancel();
    
    // 重置通话时长
    _callDuration = 0;
    
    // 启动计时器，每秒更新一次通话时长
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isCallConnected) {
        _callDuration++;
        _notifyCallStateListeners();
      }
    });
  }
  
  /// 结束通话
  void _endCall() {
    // 取消通话计时器
    _callTimer?.cancel();
    _callTimer = null;
    
    // 更新通话状态
    _isInCall = false;
    _isCallConnected = false;
    _callEndTime = DateTime.now();
    
    // 通知监听器
    _notifyCallStateListeners();
    
    // 重置通话状态
    Future.delayed(Duration(seconds: 2), () {
      _callId = null;
      _callType = null;
      _callDirection = null;
      _callTargetId = null;
      _callTargetName = null;
      _callTargetAvatar = null;
      _callStartTime = null;
      _callConnectTime = null;
      _callEndTime = null;
      _callDuration = 0;
      _isCallMuted = false;
      _isCallSpeakerOn = false;
      _isCallVideoEnabled = false;
      _isCallFrontCamera = true;
      
      // 通知监听器
      _notifyCallStateListeners();
    });
  }
  
  /// 处理对方接受通话
  void handleCallAccepted() {
    // 检查是否在拨出通话中
    if (!_isInCall || _callDirection != 'outgoing' || _isCallConnected) {
      return;
    }
    
    // 更新通话状态
    _isCallConnected = true;
    _callConnectTime = DateTime.now();
    
    // 通知监听器
    _notifyCallStateListeners();
  }
  
  /// 处理对方拒绝通话
  void handleCallRejected() {
    // 检查是否在拨出通话中
    if (!_isInCall || _callDirection != 'outgoing') {
      return;
    }
    
    // 结束通话
    _endCall();
  }
  
  /// 处理对方挂断通话
  void handleCallEnded() {
    // 检查是否在通话中
    if (!_isInCall) {
      return;
    }
    
    // 结束通话
    _endCall();
  }
  
  /// 处理通话连接失败
  void handleCallFailed(String reason) {
    // 检查是否在通话中
    if (!_isInCall) {
      return;
    }
    
    // 结束通话
    _endCall();
  }
  
  /// 释放资源
  void dispose() {
    // 取消通话计时器
    _callTimer?.cancel();
    _callTimer = null;
    
    // 清空监听器
    _callStateListeners.clear();
    
    // 重置通话状态
    _isInCall = false;
    _isCallConnected = false;
    _isCallMuted = false;
    _isCallSpeakerOn = false;
    _isCallVideoEnabled = false;
    _isCallFrontCamera = true;
    _callId = null;
    _callType = null;
    _callDirection = null;
    _callTargetId = null;
    _callTargetName = null;
    _callTargetAvatar = null;
    _callStartTime = null;
    _callConnectTime = null;
    _callEndTime = null;
    _callDuration = 0;
    
    debugPrint('[SimplifiedCallManager] 资源已释放');
  }
}
