import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/config.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class VideoCallPage extends StatefulWidget {
  final int userId; // 当前用户ID
  final int peerId; // 对方用户ID
  final String peerName; // 对方用户名
  final String peerAvatar; // 对方头像
  final bool isOutgoing; // 是否是拨出的通话
  final String callType; // 通话类型：'video' 或 'audio'

  const VideoCallPage({
    Key? key,
    required this.userId,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.isOutgoing,
    this.callType = 'video',
  }) : super(key: key);

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  // WebRTC相关
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isCallAccepted = false;
  bool _isCallEnded = false;
  String _callStatus = '正在连接...';
  Timer? _callTimer;
  int _callDuration = 0;
  int? _callId;

  // WebSocket相关
  WebSocketChannel? _channel;
  bool _isChannelReady = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initWebSocket();
  }

  @override
  void dispose() {
    _disposeWebRTC();
    _disposeWebSocket();
    _callTimer?.cancel();
    super.dispose();
  }

  // 初始化渲染器
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // 初始化WebSocket
  Future<void> _initWebSocket() async {
    try {
      // 获取token
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        _showError('获取用户信息失败');
        return;
      }

      _token = await Persistence.getTokenAsync();
      if (_token == null) {
        _showError('获取Token失败');
        return;
      }

      // 连接WebSocket
      final wsUrl = '${Config.wsBaseUrl}/ws?user_id=${widget.userId}&token=$_token';
      debugPrint('[VideoCall] 连接WebSocket: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // 监听WebSocket消息
      _channel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket错误: $error');
          _showError('WebSocket连接错误');
        },
        onDone: () {
          debugPrint('WebSocket连接关闭');
          if (!_isCallEnded) {
            _showError('WebSocket连接已关闭');
          }
        },
      );

      // 等待WebSocket连接就绪
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _isChannelReady = true;
      });

      // 初始化WebRTC
      await _initWebRTC();

      // 如果是拨出的通话，发送通话邀请
      if (widget.isOutgoing) {
        _sendCallInvitation();
      }
    } catch (e) {
      debugPrint('初始化WebSocket错误: $e');
      _showError('初始化WebSocket失败');
    }
  }

  // 处理WebSocket消息
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      switch (type) {
        case 'welcome':
          debugPrint('WebSocket连接成功');
          break;
        case 'webrtc_signal':
          _handleWebRTCSignal(data);
          break;
        case 'call_invitation':
          _handleCallInvitation(data);
          break;
        case 'call_response':
          _handleCallResponse(data);
          break;
        case 'call_ended':
          _handleCallEnded(data);
          break;
        case 'pong':
          // 心跳响应，不需要处理
          break;
        default:
          debugPrint('未知的WebSocket消息类型: $type');
      }
    } catch (e) {
      debugPrint('处理WebSocket消息错误: $e');
    }
  }

  // 处理WebRTC信令
  void _handleWebRTCSignal(Map<String, dynamic> data) async {
    if (data['from'] != widget.peerId) {
      return; // 忽略非目标用户的信令
    }

    final signalType = data['signal_type'];
    final signal = data['signal'];

    switch (signalType) {
      case 'offer':
        await _handleOffer(signal);
        break;
      case 'answer':
        await _handleAnswer(signal);
        break;
      case 'candidate':
        await _handleCandidate(signal);
        break;
      default:
        debugPrint('未知的信令类型: $signalType');
    }
  }

  // 处理通话邀请
  void _handleCallInvitation(Map<String, dynamic> data) {
    if (data['from'] != widget.peerId) {
      return; // 忽略非目标用户的邀请
    }

    final callId = data['call_id'];
    final callType = data['call_type'];

    setState(() {
      _callId = callId;
      _callStatus = '收到${callType == 'video' ? '视频' : '语音'}通话邀请';
    });

    // 自动接受通话（因为已经在通话页面了）
    _acceptCall();
  }

  // 处理通话响应
  void _handleCallResponse(Map<String, dynamic> data) {
    if (data['from'] != widget.peerId) {
      return; // 忽略非目标用户的响应
    }

    final callId = data['call_id'];
    final response = data['response'];

    setState(() {
      _callId = callId;
    });

    if (response == 'accepted') {
      setState(() {
        _isCallAccepted = true;
        _callStatus = '通话已接通';
      });
      _startCallTimer();
    } else {
      setState(() {
        _isCallEnded = true;
        _callStatus = '通话被拒绝';
      });
      _endCall(false);
    }
  }

  // 处理通话结束
  void _handleCallEnded(Map<String, dynamic> data) {
    if (data['from'] != widget.peerId) {
      return; // 忽略非目标用户的结束通知
    }

    final reason = data['reason'];
    setState(() {
      _isCallEnded = true;
      _callStatus = '通话已结束: $reason';
    });
    _endCall(false);
  }

  // 初始化WebRTC
  Future<void> _initWebRTC() async {
    try {
      // 创建本地媒体流
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': widget.callType == 'video'
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      // 如果是语音通话，不显示视频
      if (widget.callType == 'audio') {
        setState(() {
          _isCameraOff = true;
        });
      }

      // 创建PeerConnection
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
        ],
      };

      final Map<String, dynamic> offerSdpConstraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': widget.callType == 'video',
        },
        'optional': [],
      };

      _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

      // 添加本地媒体流
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 设置本地视频源
      _localRenderer.srcObject = _localStream;

      // 监听远程媒体流
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          setState(() {
            _isConnected = true;
          });
        }
      };

      // 监听ICE候选者
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendSignal('candidate', jsonEncode(candidate.toMap()));
      };

      // 监听连接状态
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('连接状态: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setState(() {
            _isConnected = true;
            if (_isCallAccepted) {
              _callStatus = '通话中';
            }
          });
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          setState(() {
            _isConnected = false;
            if (!_isCallEnded) {
              _callStatus = '连接已断开';
              _endCall(false);
            }
          });
        }
      };

      // 如果是拨出的通话，创建并发送offer
      if (widget.isOutgoing) {
        await _createOffer();
      }
    } catch (e) {
      debugPrint('初始化WebRTC错误: $e');
      _showError('初始化WebRTC失败: $e');
    }
  }

  // 创建并发送offer
  Future<void> _createOffer() async {
    try {
      RTCSessionDescription description = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(description);
      _sendSignal('offer', jsonEncode(description.toMap()));
    } catch (e) {
      debugPrint('创建offer错误: $e');
      _showError('创建offer失败');
    }
  }

  // 处理offer
  Future<void> _handleOffer(String sdpString) async {
    try {
      final sdpMap = jsonDecode(sdpString);
      final RTCSessionDescription description = RTCSessionDescription(
        sdpMap['sdp'],
        sdpMap['type'],
      );
      await _peerConnection!.setRemoteDescription(description);
      await _createAnswer();
    } catch (e) {
      debugPrint('处理offer错误: $e');
      _showError('处理offer失败');
    }
  }

  // 创建并发送answer
  Future<void> _createAnswer() async {
    try {
      RTCSessionDescription description = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(description);
      _sendSignal('answer', jsonEncode(description.toMap()));
    } catch (e) {
      debugPrint('创建answer错误: $e');
      _showError('创建answer失败');
    }
  }

  // 处理answer
  Future<void> _handleAnswer(String sdpString) async {
    try {
      final sdpMap = jsonDecode(sdpString);
      final RTCSessionDescription description = RTCSessionDescription(
        sdpMap['sdp'],
        sdpMap['type'],
      );
      await _peerConnection!.setRemoteDescription(description);
    } catch (e) {
      debugPrint('处理answer错误: $e');
      _showError('处理answer失败');
    }
  }

  // 处理ICE候选者
  Future<void> _handleCandidate(String candidateString) async {
    try {
      final candidateMap = jsonDecode(candidateString);
      final RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('处理candidate错误: $e');
      // 忽略候选者错误，不影响通话
    }
  }

  // 发送信令
  void _sendSignal(String signalType, String signal) {
    if (!_isChannelReady || _channel == null) {
      debugPrint('WebSocket未就绪，无法发送信令');
      return;
    }

    final message = {
      'type': 'webrtc_signal',
      'to': widget.peerId,
      'signal_type': signalType,
      'signal': signal,
      'call_type': widget.callType,
    };

    _channel!.sink.add(jsonEncode(message));
  }

  // 发送通话邀请
  void _sendCallInvitation() {
    if (!_isChannelReady || _channel == null) {
      debugPrint('WebSocket未就绪，无法发送通话邀请');
      return;
    }

    final message = {
      'type': 'call_invitation',
      'to': widget.peerId,
      'call_type': widget.callType,
    };

    _channel!.sink.add(jsonEncode(message));
    setState(() {
      _callStatus = '正在呼叫...';
    });
  }

  // 接受通话
  void _acceptCall() {
    if (!_isChannelReady || _channel == null || _callId == null) {
      debugPrint('WebSocket未就绪或通话ID为空，无法接受通话');
      return;
    }

    final message = {
      'type': 'call_response',
      'to': widget.peerId,
      'call_id': _callId,
      'call_type': widget.callType,
      'response': 'accepted',
    };

    _channel!.sink.add(jsonEncode(message));
    setState(() {
      _isCallAccepted = true;
      _callStatus = '通话已接通';
    });
    _startCallTimer();
  }

  // 拒绝通话
  void _rejectCall() {
    if (!_isChannelReady || _channel == null || _callId == null) {
      debugPrint('WebSocket未就绪或通话ID为空，无法拒绝通话');
      return;
    }

    final message = {
      'type': 'call_response',
      'to': widget.peerId,
      'call_id': _callId,
      'call_type': widget.callType,
      'response': 'rejected',
    };

    _channel!.sink.add(jsonEncode(message));
    setState(() {
      _isCallEnded = true;
      _callStatus = '已拒绝通话';
    });
    _endCall(false);
  }

  // 结束通话
  void _endCall(bool sendEndSignal) {
    if (sendEndSignal && _isChannelReady && _channel != null && _callId != null) {
      final message = {
        'type': 'call_ended',
        'to': widget.peerId,
        'call_id': _callId,
        'call_type': widget.callType,
        'reason': 'normal',
      };

      _channel!.sink.add(jsonEncode(message));
    }

    setState(() {
      _isCallEnded = true;
      _callStatus = '通话已结束';
    });

    // 延迟关闭页面
    Future.delayed(Duration(seconds: 1), () {
      Navigator.pop(context);
    });
  }

  // 开始通话计时器
  void _startCallTimer() {
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  // 格式化通话时长
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  // 切换麦克风
  void _toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  // 切换扬声器
  void _toggleSpeaker() {
    // 在Flutter WebRTC中，切换扬声器需要使用特定平台的API
    // 这里只是更新UI状态
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // 实际切换扬声器的代码
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  // 切换摄像头
  void _toggleCamera() {
    if (_localStream != null && widget.callType == 'video') {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }
      setState(() {
        _isCameraOff = !_isCameraOff;
      });
    }
  }

  // 切换前后摄像头
  void _switchCamera() {
    if (_localStream != null && widget.callType == 'video' && !_isCameraOff) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
    }
  }

  // 显示错误
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 释放WebRTC资源
  void _disposeWebRTC() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.close();
  }

  // 释放WebSocket资源
  void _disposeWebSocket() {
    _channel?.sink.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 远程视频（全屏）
          widget.callType == 'video'
              ? RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: false,
                )
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: widget.peerAvatar.isNotEmpty
                              ? NetworkImage(widget.peerAvatar)
                              : null,
                          child: widget.peerAvatar.isEmpty
                              ? Icon(Icons.person, size: 60, color: Colors.white)
                              : null,
                        ),
                        SizedBox(height: 20),
                        Text(
                          widget.peerName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

          // 本地视频（小窗口）
          if (widget.callType == 'video' && !_isCameraOff)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: _isFrontCamera,
                  ),
                ),
              ),
            ),

          // 顶部状态栏
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.black.withOpacity(0.5),
              child: Column(
                children: [
                  Text(
                    _callStatus,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (_isCallAccepted)
                    Text(
                      _formatDuration(_callDuration),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 底部控制栏
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              color: Colors.black.withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 麦克风按钮
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleMute,
                  ),
                  // 结束通话按钮
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.call_end, color: Colors.white),
                    onPressed: () => _endCall(true),
                  ),
                  // 扬声器按钮
                  IconButton(
                    icon: Icon(
                      _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleSpeaker,
                  ),
                ],
              ),
            ),
          ),

          // 视频控制按钮（仅视频通话时显示）
          if (widget.callType == 'video')
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 摄像头开关按钮
                    IconButton(
                      icon: Icon(
                        _isCameraOff ? Icons.videocam_off : Icons.videocam,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _toggleCamera,
                    ),
                    // 切换摄像头按钮
                    IconButton(
                      icon: Icon(
                        Icons.flip_camera_ios,
                        color: _isCameraOff ? Colors.white38 : Colors.white,
                        size: 30,
                      ),
                      onPressed: _isCameraOff ? null : _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
