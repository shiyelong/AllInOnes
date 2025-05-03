import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../common/api.dart';
import '../../../common/config.dart';
import '../../../common/persistence.dart';

class CallService {
  // WebRTC相关
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  // WebSocket相关
  WebSocketChannel? _socket;
  String? _callId;

  // 回调函数
  VoidCallback? onCallConnected;
  VoidCallback? onCallRejected;
  VoidCallback? onCallEnded;
  Function(String error)? onCallError;
  Function(String status)? onStatusChanged;

  // 通话状态
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;

  // 初始化WebRTC
  Future<void> initialize() async {
    try {
      onStatusChanged?.call('初始化WebRTC...');

      // 创建PeerConnection
      Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          // 添加TURN服务器以提高NAT穿透成功率
          {
            'urls': 'turn:numb.viagenie.ca',
            'username': 'webrtc@live.com',
            'credential': 'muazkh'
          },
          {
            'urls': 'turn:turn.anyfirewall.com:443?transport=tcp',
            'username': 'webrtc',
            'credential': 'webrtc'
          }
        ],
        'sdpSemantics': 'unified-plan',
        'iceCandidatePoolSize': 10,
      };

      final Map<String, dynamic> offerSdpConstraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      };

      debugPrint('[CallService] 创建PeerConnection...');
      _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);
      debugPrint('[CallService] PeerConnection创建成功');

      // 监听远程流
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('[CallService] 收到远程轨道: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          debugPrint('[CallService] 收到远程流');
          if (_remoteRenderer != null) {
            _remoteRenderer!.srcObject = event.streams[0];
            onStatusChanged?.call('已连接远程音视频');
          }
        }
      };

      // 监听ICE候选
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        debugPrint('[CallService] 生成ICE候选: ${candidate.candidate}');
        if (_callId != null) {
          // 通过API发送ICE候选
          Api.sendSignal(
            fromId: Persistence.getUserInfo()?.id.toString() ?? '',
            toId: _callId!.split('_')[1], // 假设callId格式为 "type_targetId_timestamp"
            type: 'ice_candidate',
            signal: jsonEncode(candidate.toMap()),
            callType: _callId!.startsWith('voice') ? 'voice' : 'video',
          );
        }
      };

      // 监听ICE连接状态
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('[CallService] ICE连接状态变化: $state');
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateChecking:
            onStatusChanged?.call('正在检查连接...');
            break;
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
            onStatusChanged?.call('ICE连接已建立');
            onCallConnected?.call();
            break;
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            onStatusChanged?.call('ICE连接失败');
            onCallError?.call('网络连接失败，请检查网络设置');
            // 尝试重新协商
            _restartIce();
            break;
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            onStatusChanged?.call('ICE连接已断开');
            // 尝试重新连接
            _restartIce();
            break;
          default:
            break;
        }
      };

      // 监听连接状态
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[CallService] 连接状态变化: $state');
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            onStatusChanged?.call('通话已连接');
            onCallConnected?.call();
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            onStatusChanged?.call('正在连接...');
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            onStatusChanged?.call('连接失败');
            onCallError?.call('连接失败，请稍后重试');
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            onStatusChanged?.call('连接已断开');
            // 不要立即结束通话，尝试重新连接
            _restartIce();
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            onStatusChanged?.call('连接已关闭');
            onCallEnded?.call();
            break;
          default:
            break;
        }
      };

      // 监听信令状态
      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        debugPrint('[CallService] 信令状态变化: $state');
      };

      // 连接信令服务器
      await _connectSignalingServer();

      debugPrint('[CallService] WebRTC初始化完成');
    } catch (e) {
      debugPrint('[CallService] 初始化WebRTC失败: $e');
      onCallError?.call('初始化通话失败: $e');
      rethrow;
    }
  }

  // 重启ICE连接
  Future<void> _restartIce() async {
    try {
      debugPrint('[CallService] 尝试重启ICE连接...');
      if (_peerConnection != null) {
        await _peerConnection!.restartIce();
      }
    } catch (e) {
      debugPrint('[CallService] 重启ICE连接失败: $e');
    }
  }

  // 连接信令服务器
  Future<void> _connectSignalingServer() async {
    try {
      onStatusChanged?.call('连接信令服务器...');

      final token = Persistence.getToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        throw Exception('未获取到用户信息');
      }

      final wsUrl = '${Config.wsBaseUrl}/ws?token=$token&user_id=$userId';
      debugPrint('[CallService] 连接WebSocket: $wsUrl');

      // 使用重试机制连接WebSocket
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          _socket = WebSocketChannel.connect(Uri.parse(wsUrl));

          // 发送心跳消息以确认连接
          _sendHeartbeat();

          // 监听信令消息
          _socket!.stream.listen((message) {
            try {
              debugPrint('[CallService] 收到WebSocket消息: $message');
              final data = jsonDecode(message);
              _handleSignalingMessage(data);
            } catch (e) {
              debugPrint('[CallService] 解析信令消息失败: $e');
              onCallError?.call('信令消息解析失败');
            }
          }, onError: (error) {
            debugPrint('[CallService] WebSocket错误: $error');
            onStatusChanged?.call('信令服务器连接错误');

            if (retryCount < maxRetries - 1) {
              // 如果还有重试次数，不通知错误
              debugPrint('[CallService] 将尝试重新连接...');
            } else {
              onCallError?.call('信令服务器连接错误: $error');
              onCallEnded?.call();
            }
          }, onDone: () {
            debugPrint('[CallService] WebSocket连接关闭');
            onStatusChanged?.call('信令服务器连接已关闭');

            // 如果不是主动关闭，尝试重新连接
            if (_socket != null && retryCount < maxRetries - 1) {
              debugPrint('[CallService] 尝试重新连接信令服务器...');
              retryCount++;
              Future.delayed(Duration(seconds: 1), () {
                _connectSignalingServer();
              });
            }
          });

          // 连接成功，跳出循环
          onStatusChanged?.call('信令服务器连接成功');
          debugPrint('[CallService] 信令服务器连接成功');

          // 设置定期发送心跳
          Timer.periodic(Duration(seconds: 30), (timer) {
            if (_socket != null) {
              _sendHeartbeat();
            } else {
              timer.cancel();
            }
          });

          break;
        } catch (e) {
          debugPrint('[CallService] 连接信令服务器失败 (尝试 ${retryCount + 1}/$maxRetries): $e');
          retryCount++;

          if (retryCount >= maxRetries) {
            throw e;
          }

          // 等待一段时间后重试
          await Future.delayed(Duration(seconds: 1));
        }
      }
    } catch (e) {
      debugPrint('[CallService] 连接信令服务器失败: $e');
      onCallError?.call('连接信令服务器失败: $e');
      rethrow;
    }
  }

  // 发送心跳消息
  void _sendHeartbeat() {
    if (_socket != null && _socket!.sink != null) {
      try {
        _socket!.sink.add(jsonEncode({
          'type': 'heartbeat',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
        debugPrint('[CallService] 发送心跳消息');
      } catch (e) {
        debugPrint('[CallService] 发送心跳消息失败: $e');
      }
    }
  }

  // 处理信令消息
  void _handleSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'];
    debugPrint('[CallService] 处理信令消息: $type');

    switch (type) {
      case 'webrtc_signal':
        final signalType = message['signal_type'];
        final signal = message['signal'];
        final fromId = message['from'];

        debugPrint('[CallService] 收到WebRTC信令: $signalType, 来自: $fromId');

        switch (signalType) {
          case 'offer':
            _handleOffer(signal, fromId.toString());
            break;
          case 'answer':
            _handleAnswer(signal);
            break;
          case 'ice_candidate':
            _handleIceCandidate(signal);
            break;
        }
        break;

      case 'call_invitation':
        final fromId = message['from'];
        final callType = message['call_type'];
        final callId = message['call_id'];

        debugPrint('[CallService] 收到通话邀请: $callType, 来自: $fromId, 通话ID: $callId');

        // 这里不处理邀请，由上层UI处理
        break;

      case 'call_rejected':
        debugPrint('[CallService] 通话被拒绝');
        onCallRejected?.call();
        break;

      case 'call_ended':
        debugPrint('[CallService] 通话已结束');
        onCallEnded?.call();
        break;

      case 'heartbeat_response':
        debugPrint('[CallService] 收到心跳响应');
        break;

      default:
        debugPrint('[CallService] 未知信令类型: $type');
        break;
    }
  }

  // 处理Offer
  Future<void> _handleOffer(String signalData, String fromId) async {
    try {
      debugPrint('[CallService] 处理Offer信令');

      // 解析SDP
      final sdpMap = jsonDecode(signalData);
      final RTCSessionDescription description = RTCSessionDescription(
        sdpMap['sdp'],
        sdpMap['type'],
      );

      // 设置远程描述
      await _peerConnection!.setRemoteDescription(description);
      debugPrint('[CallService] 已设置远程描述');

      // 获取媒体流（如果尚未获取）
      if (_localStream == null) {
        debugPrint('[CallService] 获取本地媒体流');
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': _callId != null && _callId!.startsWith('video'),
        });

        // 添加本地流
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });

        // 设置本地渲染器
        if (_localRenderer != null && _localStream != null) {
          _localRenderer!.srcObject = _localStream;
        }
      }

      // 创建Answer
      debugPrint('[CallService] 创建Answer');
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[CallService] 已设置本地描述');

      // 发送Answer
      debugPrint('[CallService] 发送Answer信令');
      Api.sendSignal(
        fromId: Persistence.getUserInfo()?.id.toString() ?? '',
        toId: fromId,
        type: 'answer',
        signal: jsonEncode(answer.toMap()),
        callType: _callId != null && _callId!.startsWith('video') ? 'video' : 'voice',
      );
    } catch (e) {
      debugPrint('[CallService] 处理Offer信令失败: $e');
      onCallError?.call('处理通话请求失败: $e');
    }
  }

  // 处理Answer
  Future<void> _handleAnswer(String signalData) async {
    try {
      debugPrint('[CallService] 处理Answer信令');

      // 解析SDP
      final sdpMap = jsonDecode(signalData);
      final RTCSessionDescription description = RTCSessionDescription(
        sdpMap['sdp'],
        sdpMap['type'],
      );

      // 设置远程描述
      await _peerConnection!.setRemoteDescription(description);
      debugPrint('[CallService] 已设置远程描述 (Answer)');
    } catch (e) {
      debugPrint('[CallService] 处理Answer信令失败: $e');
      onCallError?.call('处理通话应答失败: $e');
    }
  }

  // 处理ICE候选
  Future<void> _handleIceCandidate(String signalData) async {
    try {
      debugPrint('[CallService] 处理ICE候选信令');

      // 解析候选者
      final candidateMap = jsonDecode(signalData);
      final RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );

      // 添加候选者
      await _peerConnection!.addCandidate(candidate);
      debugPrint('[CallService] 已添加ICE候选');
    } catch (e) {
      debugPrint('[CallService] 处理ICE候选信令失败: $e');
      // 不向用户显示错误，因为ICE候选失败是常见的，不一定影响通话
    }
  }

  // 设置视频渲染器
  void setVideoRenderers(RTCVideoRenderer localRenderer, RTCVideoRenderer remoteRenderer) {
    _localRenderer = localRenderer;
    _remoteRenderer = remoteRenderer;

    if (_localStream != null && _localRenderer != null) {
      _localRenderer!.srcObject = _localStream;
    }
  }

  // 开始语音通话
  Future<String?> startVoiceCall(String userId, String targetId) async {
    try {
      debugPrint('[CallService] 开始语音通话: 发起者=$userId, 接收者=$targetId');

      // 获取音频流
      debugPrint('[CallService] 获取音频流');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // 添加本地流
      debugPrint('[CallService] 添加本地流到PeerConnection');
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 创建Offer
      debugPrint('[CallService] 创建Offer');
      final offer = await _peerConnection!.createOffer();
      debugPrint('[CallService] 设置本地描述');
      await _peerConnection!.setLocalDescription(offer);

      // 调用API发起呼叫
      debugPrint('[CallService] 调用API发起语音通话');
      final response = await Api.startVoiceCall(
        fromId: userId,
        toId: targetId,
      );

      debugPrint('[CallService] 发起通话API响应: $response');

      if (response['success'] == true && response['data'] != null) {
        _callId = 'voice_${targetId}_${DateTime.now().millisecondsSinceEpoch}';
        if (response['data']['call_id'] != null) {
          _callId = response['data']['call_id'].toString();
        }
        debugPrint('[CallService] 通话ID: $_callId');
        return _callId;
      } else {
        // 如果API调用成功但返回失败，显示错误信息
        final errorMsg = response['msg'] ?? '发起通话失败';
        debugPrint('[CallService] 发起通话失败: $errorMsg');
        onCallError?.call(errorMsg);

        // 释放资源
        _disposeLocalStream();
      }
    } catch (e) {
      // 捕获并处理异常
      debugPrint('[CallService] 发起语音通话异常: $e');
      onCallError?.call('发起通话失败: $e');

      // 释放资源
      _disposeLocalStream();
    }

    return null;
  }

  // 开始视频通话
  Future<String?> startVideoCall(String userId, String targetId) async {
    try {
      debugPrint('[CallService] 开始视频通话: 发起者=$userId, 接收者=$targetId');

      // 获取音视频流
      debugPrint('[CallService] 获取音视频流');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });

      // 设置本地渲染器
      debugPrint('[CallService] 设置本地渲染器');
      if (_localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }

      // 添加本地流
      debugPrint('[CallService] 添加本地流到PeerConnection');
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 创建Offer
      debugPrint('[CallService] 创建Offer');
      final offer = await _peerConnection!.createOffer();
      debugPrint('[CallService] 设置本地描述');
      await _peerConnection!.setLocalDescription(offer);

      // 调用API发起呼叫
      debugPrint('[CallService] 调用API发起视频通话');
      final response = await Api.startVideoCall(
        fromId: userId,
        toId: targetId,
      );

      debugPrint('[CallService] 发起通话API响应: $response');

      if (response['success'] == true && response['data'] != null) {
        _callId = 'video_${targetId}_${DateTime.now().millisecondsSinceEpoch}';
        if (response['data']['call_id'] != null) {
          _callId = response['data']['call_id'].toString();
        }
        debugPrint('[CallService] 通话ID: $_callId');
        return _callId;
      } else {
        // 如果API调用成功但返回失败，显示错误信息
        final errorMsg = response['msg'] ?? '发起视频通话失败';
        debugPrint('[CallService] 发起视频通话失败: $errorMsg');
        onCallError?.call(errorMsg);

        // 释放资源
        _disposeLocalStream();
      }
    } catch (e) {
      // 捕获并处理异常
      debugPrint('[CallService] 发起视频通话异常: $e');
      onCallError?.call('发起视频通话失败: $e');

      // 释放资源
      _disposeLocalStream();
    }

    return null;
  }

  // 接听语音通话
  Future<void> answerCall(String callId) async {
    try {
      debugPrint('[CallService] 接听语音通话: callId=$callId');
      _callId = callId;

      // 获取音频流
      debugPrint('[CallService] 获取音频流');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // 添加本地流
      debugPrint('[CallService] 添加本地流到PeerConnection');
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 调用API接听通话
      debugPrint('[CallService] 调用API接听通话');
      final response = await Api.acceptVoiceCall(
        fromId: Persistence.getUserInfo()?.id.toString() ?? '',
        toId: callId.split('_')[1], // 假设callId格式为 "type_targetId_timestamp"
      );

      debugPrint('[CallService] 接听通话API响应: $response');

      if (response['success'] != true) {
        final errorMsg = response['msg'] ?? '接听通话失败';
        debugPrint('[CallService] 接听通话失败: $errorMsg');
        onCallError?.call(errorMsg);
      }
    } catch (e) {
      debugPrint('[CallService] 接听语音通话异常: $e');
      onCallError?.call('接听通话失败: $e');
    }
  }

  // 接听视频通话
  Future<void> answerVideoCall(String callId) async {
    try {
      debugPrint('[CallService] 接听视频通话: callId=$callId');
      _callId = callId;

      // 获取音视频流
      debugPrint('[CallService] 获取音视频流');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });

      // 设置本地渲染器
      debugPrint('[CallService] 设置本地渲染器');
      if (_localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }

      // 添加本地流
      debugPrint('[CallService] 添加本地流到PeerConnection');
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 调用API接听通话
      debugPrint('[CallService] 调用API接听通话');
      final response = await Api.acceptVideoCall(
        fromId: Persistence.getUserInfo()?.id.toString() ?? '',
        toId: callId.split('_')[1], // 假设callId格式为 "type_targetId_timestamp"
      );

      debugPrint('[CallService] 接听通话API响应: $response');

      if (response['success'] != true) {
        final errorMsg = response['msg'] ?? '接听视频通话失败';
        debugPrint('[CallService] 接听视频通话失败: $errorMsg');
        onCallError?.call(errorMsg);
      }
    } catch (e) {
      debugPrint('[CallService] 接听视频通话异常: $e');
      onCallError?.call('接听通话失败: $e');
    }
  }

  // 释放本地流资源
  void _disposeLocalStream() {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      _localStream = null;
    }
  }

  // 切换静音状态
  Future<bool> toggleMute() async {
    if (_localStream == null) return false;

    final audioTrack = _localStream!.getAudioTracks().first;
    _isMuted = !_isMuted;
    audioTrack.enabled = !_isMuted;

    return _isMuted;
  }

  // 切换摄像头状态
  Future<bool> toggleCamera() async {
    if (_localStream == null) return false;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return true;

    final videoTrack = videoTracks.first;
    _isCameraOff = !_isCameraOff;
    videoTrack.enabled = !_isCameraOff;

    return _isCameraOff;
  }

  // 切换前后摄像头
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    final videoTrack = videoTracks.first;
    await Helper.switchCamera(videoTrack);
  }

  // 切换扬声器状态
  Future<bool> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    return _isSpeakerOn;
  }

  // 结束通话
  Future<void> endCall() async {
    debugPrint('[CallService] 结束通话');

    // 调用API结束通话
    if (_callId != null) {
      try {
        debugPrint('[CallService] 调用API结束通话: $_callId');
        final response = _callId!.startsWith('video')
            ? await Api.endVideoCall(
                fromId: Persistence.getUserInfo()?.id.toString() ?? '',
                toId: _callId!.split('_')[1],
              )
            : await Api.endVoiceCall(
                fromId: Persistence.getUserInfo()?.id.toString() ?? '',
                toId: _callId!.split('_')[1],
              );
        debugPrint('[CallService] 结束通话API响应: $response');
      } catch (e) {
        debugPrint('[CallService] 结束通话API调用失败: $e');
      }

      try {
        // 发送结束通话信令
        if (_socket != null && _socket!.sink != null) {
          debugPrint('[CallService] 发送结束通话信令');
          _socket!.sink.add(jsonEncode({
            'type': 'call_ended',
            'call_id': _callId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }));
        }
      } catch (e) {
        debugPrint('[CallService] 发送结束通话信令失败: $e');
      }
    }

    // 释放资源
    await dispose();
  }

  // 释放资源
  Future<void> dispose() async {
    debugPrint('[CallService] 释放资源');

    // 关闭本地流
    _disposeLocalStream();

    // 关闭PeerConnection
    if (_peerConnection != null) {
      try {
        debugPrint('[CallService] 关闭PeerConnection');
        await _peerConnection!.close();
      } catch (e) {
        debugPrint('[CallService] 关闭PeerConnection失败: $e');
      } finally {
        _peerConnection = null;
      }
    }

    // 关闭WebSocket
    if (_socket != null) {
      try {
        debugPrint('[CallService] 关闭WebSocket');
        await _socket!.sink.close();
      } catch (e) {
        debugPrint('[CallService] 关闭WebSocket失败: $e');
      } finally {
        _socket = null;
      }
    }

    // 清空渲染器
    if (_localRenderer != null) {
      try {
        debugPrint('[CallService] 清空本地渲染器');
        _localRenderer!.srcObject = null;
      } catch (e) {
        debugPrint('[CallService] 清空本地渲染器失败: $e');
      } finally {
        _localRenderer = null;
      }
    }

    if (_remoteRenderer != null) {
      try {
        debugPrint('[CallService] 清空远程渲染器');
        _remoteRenderer!.srcObject = null;
      } catch (e) {
        debugPrint('[CallService] 清空远程渲染器失败: $e');
      } finally {
        _remoteRenderer = null;
      }
    }

    // 清空通话ID
    _callId = null;

    debugPrint('[CallService] 资源释放完成');
  }
}
