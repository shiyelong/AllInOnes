import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/config.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/modules/social/call/firebase_signaling_service.dart';

/// WebRTC服务类，用于处理语音和视频通话
class WebRTCService {
  // 单例模式
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  // WebRTC相关
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  // Firebase信令服务
  final FirebaseSignalingService _firebaseSignaling = FirebaseSignalingService();

  // 通话状态
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isCallInProgress = false;
  String? _currentCallId;
  String? _currentCallType;

  // 回调函数
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onCallStateChanged;
  Function(String)? onError;
  Function()? onCallConnected;
  Function()? onCallEnded;
  Function(Map<String, dynamic>)? onIncomingCall;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isCallInProgress => _isCallInProgress;
  String? get currentCallId => _currentCallId;
  String? get currentCallType => _currentCallType;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// 初始化WebRTC服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化Firebase信令服务
      await _initFirebaseSignaling();

      // 创建PeerConnection
      await _createPeerConnection();

      _isInitialized = true;
      debugPrint('[WebRTCService] 初始化完成');
    } catch (e) {
      debugPrint('[WebRTCService] 初始化失败: $e');
      if (onError != null) onError!('初始化失败: $e');
      rethrow;
    }
  }

  /// 初始化Firebase信令服务
  Future<void> _initFirebaseSignaling() async {
    try {
      // 获取用户信息
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        throw Exception('获取用户信息失败');
      }

      // 初始化Firebase
      await _firebaseSignaling.initialize();

      // 设置用户ID
      _firebaseSignaling.setUserId(userInfo.id.toString());

      // 设置回调函数
      _firebaseSignaling.onSignalReceived = (data) {
        _handleSignalMessage(data);
      };

      _firebaseSignaling.onCallInvitation = (data) {
        _handleCallInvitation(data);
      };

      _firebaseSignaling.onCallAccepted = (data) {
        _handleCallAccepted(data);
      };

      _firebaseSignaling.onCallRejected = (data) {
        _handleCallRejected(data);
      };

      _firebaseSignaling.onCallEnded = (data) {
        _handleCallEnded(data);
      };

      _isConnected = true;
      debugPrint('[WebRTCService] Firebase信令服务初始化成功');
    } catch (e) {
      debugPrint('[WebRTCService] 初始化Firebase信令服务失败: $e');
      rethrow;
    }
  }

  /// 创建PeerConnection
  Future<void> _createPeerConnection() async {
    try {
      // 配置PeerConnection
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      // 创建PeerConnection
      _peerConnection = await createPeerConnection(configuration);

      // 设置事件监听
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendIceCandidate(candidate);
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('[WebRTCService] ICE连接状态: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _isCallInProgress = true;
          if (onCallConnected != null) onCallConnected!();
          if (onCallStateChanged != null) onCallStateChanged!('已连接');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
                  state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          _endCall();
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('[WebRTCService] 收到远程媒体流');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          if (_remoteRenderer != null) {
            _remoteRenderer!.srcObject = _remoteStream;
          }
          if (onRemoteStream != null) onRemoteStream!(_remoteStream!);
        }
      };

      debugPrint('[WebRTCService] PeerConnection创建成功');
    } catch (e) {
      debugPrint('[WebRTCService] 创建PeerConnection失败: $e');
      rethrow;
    }
  }

  // 移除了_handleWebSocketMessage方法，改为使用Firebase信令服务的回调函数

  /// 处理信令消息
  void _handleSignalMessage(Map<String, dynamic> data) {
    final String signalType = data['signal_type'];
    final String signal = data['signal'];

    switch (signalType) {
      case 'offer':
        _handleOffer(signal);
        break;
      case 'answer':
        _handleAnswer(signal);
        break;
      case 'candidate':
        _handleCandidate(signal);
        break;
      default:
        debugPrint('[WebRTCService] 未知信令类型: $signalType');
    }
  }

  /// 处理Offer
  Future<void> _handleOffer(String sdpString) async {
    try {
      final RTCSessionDescription description = RTCSessionDescription(
        sdpString,
        'offer',
      );

      await _peerConnection!.setRemoteDescription(description);

      final RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendAnswer(answer.sdp!);
    } catch (e) {
      debugPrint('[WebRTCService] 处理Offer失败: $e');
    }
  }

  /// 处理Answer
  Future<void> _handleAnswer(String sdpString) async {
    try {
      final RTCSessionDescription description = RTCSessionDescription(
        sdpString,
        'answer',
      );

      await _peerConnection!.setRemoteDescription(description);
    } catch (e) {
      debugPrint('[WebRTCService] 处理Answer失败: $e');
    }
  }

  /// 处理ICE Candidate
  Future<void> _handleCandidate(String candidateString) async {
    try {
      final Map<String, dynamic> candidateData = jsonDecode(candidateString);
      final RTCIceCandidate candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('[WebRTCService] 处理Candidate失败: $e');
    }
  }

  /// 处理通话邀请
  void _handleCallInvitation(Map<String, dynamic> data) {
    final int fromUserId = data['from'];
    final String callType = data['call_type'];
    final int callId = data['call_id'];

    debugPrint('[WebRTCService] 收到通话邀请: fromUserId=$fromUserId, callType=$callType, callId=$callId');

    _currentCallId = callId.toString();
    _currentCallType = callType;

    if (onIncomingCall != null) {
      onIncomingCall!({
        'from_id': fromUserId,
        'call_type': callType,
        'call_id': callId,
      });
    } else {
      debugPrint('[WebRTCService] 警告: 没有设置onIncomingCall回调，无法处理来电');
    }
  }

  /// 处理通话接受
  void _handleCallAccepted(Map<String, dynamic> data) {
    debugPrint('[WebRTCService] 通话已接受');
    if (onCallStateChanged != null) onCallStateChanged!('对方已接受');
  }

  /// 处理通话拒绝
  void _handleCallRejected(Map<String, dynamic> data) {
    debugPrint('[WebRTCService] 通话已拒绝');
    _cleanupCall();
    if (onCallStateChanged != null) onCallStateChanged!('对方已拒绝');
    if (onCallEnded != null) onCallEnded!();
  }

  /// 处理通话结束
  void _handleCallEnded(Map<String, dynamic> data) {
    debugPrint('[WebRTCService] 通话已结束');
    _cleanupCall();
    if (onCallStateChanged != null) onCallStateChanged!('通话已结束');
    if (onCallEnded != null) onCallEnded!();
  }

  /// 发送Offer
  Future<void> _sendOffer(String sdp) async {
    try {
      final toUserId = _currentCallId!.split('_')[1]; // 假设callId格式为 "call_接收者ID"

      await _firebaseSignaling.sendSignal(
        toUserId: toUserId,
        type: 'offer',
        signal: sdp,
        callType: _currentCallType!,
      );

      debugPrint('[WebRTCService] 发送Offer成功');
    } catch (e) {
      debugPrint('[WebRTCService] 发送Offer失败: $e');
    }
  }

  /// 发送Answer
  Future<void> _sendAnswer(String sdp) async {
    try {
      final toUserId = _currentCallId!.split('_')[1]; // 假设callId格式为 "call_接收者ID"

      await _firebaseSignaling.sendSignal(
        toUserId: toUserId,
        type: 'answer',
        signal: sdp,
        callType: _currentCallType!,
      );

      debugPrint('[WebRTCService] 发送Answer成功');
    } catch (e) {
      debugPrint('[WebRTCService] 发送Answer失败: $e');
    }
  }

  /// 发送ICE Candidate
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      final toUserId = _currentCallId!.split('_')[1]; // 假设callId格式为 "call_接收者ID"

      final Map<String, dynamic> candidateData = {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      };

      await _firebaseSignaling.sendSignal(
        toUserId: toUserId,
        type: 'candidate',
        signal: jsonEncode(candidateData),
        callType: _currentCallType!,
      );

      debugPrint('[WebRTCService] 发送ICE Candidate成功');
    } catch (e) {
      debugPrint('[WebRTCService] 发送ICE Candidate失败: $e');
    }
  }

  /// 设置视频渲染器
  void setVideoRenderers(RTCVideoRenderer localRenderer, RTCVideoRenderer remoteRenderer) {
    _localRenderer = localRenderer;
    _remoteRenderer = remoteRenderer;

    if (_localStream != null && _localRenderer != null) {
      _localRenderer!.srcObject = _localStream;
    }

    if (_remoteStream != null && _remoteRenderer != null) {
      _remoteRenderer!.srcObject = _remoteStream;
    }
  }

  /// 开始语音通话
  Future<String?> startVoiceCall(String targetId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 获取用户信息
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        throw Exception('获取用户信息失败');
      }

      // 设置通话类型
      _currentCallType = 'voice';

      // 获取音频流
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      if (onLocalStream != null) onLocalStream!(_localStream!);

      if (_localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }

      // 添加本地流
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 创建Offer
      final RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // 发起通话请求
      _currentCallId = await _firebaseSignaling.startCall(
        toUserId: targetId,
        callType: 'voice',
      );

      // 发送Offer
      await _sendOffer(offer.sdp!);

      if (onCallStateChanged != null) onCallStateChanged!('正在呼叫...');
      return _currentCallId;
    } catch (e) {
      debugPrint('[WebRTCService] 开始语音通话失败: $e');
      _cleanupCall();
      if (onError != null) onError!('开始语音通话失败: $e');
      return null;
    }
  }

  /// 开始视频通话
  Future<String?> startVideoCall(String targetId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 获取用户信息
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        throw Exception('获取用户信息失败');
      }

      // 设置通话类型
      _currentCallType = 'video';

      // 获取音视频流
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });

      if (onLocalStream != null) onLocalStream!(_localStream!);

      if (_localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }

      // 添加本地流
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 创建Offer
      final RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // 发起通话请求
      _currentCallId = await _firebaseSignaling.startCall(
        toUserId: targetId,
        callType: 'video',
      );

      // 发送Offer
      await _sendOffer(offer.sdp!);

      if (onCallStateChanged != null) onCallStateChanged!('正在呼叫...');
      return _currentCallId;
    } catch (e) {
      debugPrint('[WebRTCService] 开始视频通话失败: $e');
      _cleanupCall();
      if (onError != null) onError!('开始视频通话失败: $e');
      return null;
    }
  }

  /// 接听通话
  Future<bool> answerCall(String callId, String callType) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 获取用户信息
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        throw Exception('获取用户信息失败');
      }

      // 设置通话类型
      _currentCallType = callType;
      _currentCallId = callId;

      // 解析来电者ID
      final fromUserId = callId.split('_')[1]; // 假设callId格式为 "call_发起者ID"

      // 获取媒体流
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': callType == 'video' ? {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        } : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (onLocalStream != null) onLocalStream!(_localStream!);

      if (_localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }

      // 添加本地流
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 接听通话请求
      await _firebaseSignaling.acceptCall(
        callId: callId,
        fromUserId: fromUserId,
      );

      if (onCallStateChanged != null) onCallStateChanged!('已接听');
      return true;
    } catch (e) {
      debugPrint('[WebRTCService] 接听通话失败: $e');
      _cleanupCall();
      if (onError != null) onError!('接听通话失败: $e');
      return false;
    }
  }

  /// 拒绝通话
  Future<bool> rejectCall(String callId, String callType) async {
    try {
      // 解析来电者ID
      final fromUserId = callId.split('_')[1]; // 假设callId格式为 "call_发起者ID"

      // 拒绝通话请求
      await _firebaseSignaling.rejectCall(
        callId: callId,
        fromUserId: fromUserId,
      );

      _cleanupCall();
      return true;
    } catch (e) {
      debugPrint('[WebRTCService] 拒绝通话失败: $e');
      if (onError != null) onError!('拒绝通话失败: $e');
      return false;
    }
  }

  /// 结束通话
  Future<bool> endCall() async {
    try {
      if (_currentCallId == null || _currentCallType == null) {
        return false;
      }

      // 解析对方ID
      final toUserId = _currentCallId!.split('_')[1]; // 假设callId格式为 "call_对方ID"

      // 结束通话请求
      await _firebaseSignaling.endCall(
        callId: _currentCallId!,
        toUserId: toUserId,
      );

      _cleanupCall();
      return true;
    } catch (e) {
      debugPrint('[WebRTCService] 结束通话失败: $e');
      _cleanupCall();
      if (onError != null) onError!('结束通话失败: $e');
      return false;
    }
  }

  /// 内部结束通话
  void _endCall() {
    _cleanupCall();
    if (onCallEnded != null) onCallEnded!();
  }

  /// 清理通话资源
  void _cleanupCall() {
    // 停止本地流
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream = null;

    // 清理远程流
    _remoteStream = null;

    // 清理渲染器
    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
    }

    if (_remoteRenderer != null) {
      _remoteRenderer!.srcObject = null;
    }

    // 关闭PeerConnection
    _peerConnection?.close();
    _peerConnection = null;

    // 重置状态
    _isCallInProgress = false;
    _currentCallId = null;
    _currentCallType = null;

    // 重新创建PeerConnection
    _createPeerConnection();
  }

  /// 切换摄像头
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    MediaStreamTrack? videoTrack;
    if (videoTracks.isNotEmpty) {
      videoTrack = videoTracks.first;
    }

    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  /// 切换麦克风
  Future<void> toggleMicrophone(bool enabled) async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    MediaStreamTrack? audioTrack;
    if (audioTracks.isNotEmpty) {
      audioTrack = audioTracks.first;
    }

    if (audioTrack != null) {
      audioTrack.enabled = enabled;
    }
  }

  /// 切换摄像头开关
  Future<void> toggleCamera(bool enabled) async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    MediaStreamTrack? videoTrack;
    if (videoTracks.isNotEmpty) {
      videoTrack = videoTracks.first;
    }

    if (videoTrack != null) {
      videoTrack.enabled = enabled;
    }
  }

  /// 释放资源
  void dispose() {
    _cleanupCall();

    // 释放Firebase资源
    _firebaseSignaling.dispose();

    _isInitialized = false;
    _isConnected = false;
  }
}
