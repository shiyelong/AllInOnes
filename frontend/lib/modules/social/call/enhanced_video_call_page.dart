import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/modules/social/call/webrtc_service.dart';
import 'package:frontend/widgets/app_avatar.dart';

class EnhancedVideoCallPage extends StatefulWidget {
  final String targetId;
  final String targetName;
  final String? targetAvatar;
  final bool isIncoming;
  final String? callId;

  const EnhancedVideoCallPage({
    Key? key,
    required this.targetId,
    required this.targetName,
    this.targetAvatar,
    this.isIncoming = false,
    this.callId,
  }) : super(key: key);

  @override
  _EnhancedVideoCallPageState createState() => _EnhancedVideoCallPageState();
}

class _EnhancedVideoCallPageState extends State<EnhancedVideoCallPage> {
  // WebRTC相关
  final WebRTCService _webRTCService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  // 通话状态
  String _callStatus = '准备中...';
  bool _isConnected = false;
  bool _isCallEnded = false;

  // 控制状态
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isControlsVisible = true;

  // 计时器
  Timer? _callTimer;
  Timer? _controlsTimer;
  int _callDuration = 0;

  // 用户信息
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _controlsTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webRTCService.dispose();
    super.dispose();
  }

  // 初始化通话
  Future<void> _initializeCall() async {
    try {
      debugPrint('[EnhancedVideoCallPage] 初始化通话');

      // 初始化渲染器
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      // 获取用户ID
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        _showError('获取用户信息失败');
        return;
      }

      _userId = userInfo.id.toString();

      debugPrint('[EnhancedVideoCallPage] 用户ID: $_userId, 目标ID: ${widget.targetId}');
      debugPrint('[EnhancedVideoCallPage] 是否为来电: ${widget.isIncoming}, 通话ID: ${widget.callId}');

      // 设置回调函数
      _webRTCService.onCallStateChanged = (status) {
        debugPrint('[EnhancedVideoCallPage] 通话状态变更: $status');
        if (mounted) {
          setState(() {
            _callStatus = status;
          });
        }
      };

      _webRTCService.onCallConnected = () {
        debugPrint('[EnhancedVideoCallPage] 通话已连接');
        if (mounted) {
          setState(() {
            _isConnected = true;
            _callStatus = '通话中';
          });
          _startCallTimer();
          _startControlsTimer();
        }
      };

      _webRTCService.onCallEnded = () {
        debugPrint('[EnhancedVideoCallPage] 通话已结束');
        if (mounted) {
          setState(() {
            _isCallEnded = true;
          });
          Navigator.of(context).pop();
        }
      };

      _webRTCService.onError = (error) {
        debugPrint('[EnhancedVideoCallPage] 通话错误: $error');
        _showError(error);
      };

      _webRTCService.onLocalStream = (stream) {
        debugPrint('[EnhancedVideoCallPage] 收到本地媒体流');
        if (mounted) {
          setState(() {
            _localRenderer.srcObject = stream;
          });
        }
      };

      _webRTCService.onRemoteStream = (stream) {
        debugPrint('[EnhancedVideoCallPage] 收到远程媒体流');
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
          });
        }
      };

      // 初始化WebRTC服务
      await _webRTCService.initialize();

      // 设置视频渲染器
      _webRTCService.setVideoRenderers(_localRenderer, _remoteRenderer);

      if (widget.isIncoming) {
        // 接听来电
        if (widget.callId != null) {
          debugPrint('[EnhancedVideoCallPage] 接听来电: ${widget.callId}');
          final result = await _webRTCService.answerCall(widget.callId!, 'video');

          if (!result) {
            debugPrint('[EnhancedVideoCallPage] 接听来电失败');
            _showError('接听来电失败');
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        } else {
          debugPrint('[EnhancedVideoCallPage] 来电ID为空');
          _showError('来电ID为空');
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      } else {
        // 发起呼叫
        setState(() {
          _callStatus = '正在呼叫...';
        });

        debugPrint('[EnhancedVideoCallPage] 发起呼叫: ${widget.targetId}');
        final callId = await _webRTCService.startVideoCall(widget.targetId);

        if (callId == null) {
          // 呼叫失败
          debugPrint('[EnhancedVideoCallPage] 呼叫失败');
          setState(() {
            _callStatus = '呼叫失败';
          });
          _showCallFailedDialog();
        } else {
          debugPrint('[EnhancedVideoCallPage] 呼叫成功，通话ID: $callId');
        }
      }
    } catch (e) {
      debugPrint('[EnhancedVideoCallPage] 初始化通话失败: $e');
      setState(() {
        _callStatus = '连接失败: $e';
      });
      _showCallFailedDialog();
    }
  }

  // 开始通话计时器
  void _startCallTimer() {
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  // 开始控制栏隐藏计时器
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 5), () {
      if (mounted && _isControlsVisible) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  // 切换控制栏可见性
  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });

    if (_isControlsVisible) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  // 切换麦克风
  void _toggleMicrophone() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _webRTCService.toggleMicrophone(!_isMuted);
    _startControlsTimer();
  }

  // 切换摄像头
  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _webRTCService.toggleCamera(!_isCameraOff);
    _startControlsTimer();
  }

  // 切换扬声器
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: 实现扬声器切换
    _startControlsTimer();
  }

  // 切换前后摄像头
  void _switchCamera() {
    _webRTCService.switchCamera();
    _startControlsTimer();
  }

  // 结束通话
  void _endCall() {
    _webRTCService.endCall();
    Navigator.of(context).pop();
  }

  // 显示错误对话框
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

  // 显示呼叫失败对话框
  void _showCallFailedDialog() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('通话失败'),
          content: Text('无法建立通话连接，请检查网络连接或稍后重试。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // 格式化通话时长
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 远程视频（全屏）
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: false,
              ),
            ),

            // 本地视频（小窗口）
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _isCameraOff
                      ? Center(
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.white,
                            size: 40,
                          ),
                        )
                      : RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                ),
              ),
            ),

            // 顶部状态栏
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: 300),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 20, right: 20, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.targetName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _isConnected ? _formatDuration(_callDuration) : _callStatus,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部控制栏
            AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              bottom: _isControlsVisible ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? '取消静音' : '静音',
                      onPressed: _toggleMicrophone,
                      backgroundColor: _isMuted ? Colors.red : Colors.white24,
                    ),
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      label: _isCameraOff ? '开启摄像头' : '关闭摄像头',
                      onPressed: _toggleCamera,
                      backgroundColor: _isCameraOff ? Colors.red : Colors.white24,
                    ),
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      label: _isSpeakerOn ? '扬声器' : '听筒',
                      onPressed: _toggleSpeaker,
                      backgroundColor: Colors.white24,
                    ),
                    _buildControlButton(
                      icon: Icons.switch_camera,
                      label: '切换摄像头',
                      onPressed: _switchCamera,
                      backgroundColor: Colors.white24,
                    ),
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: '结束通话',
                      onPressed: _endCall,
                      backgroundColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            // 未连接时显示头像
            if (!_isConnected && _remoteRenderer.srcObject == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAvatar(
                      imageUrl: widget.targetAvatar,
                      size: 120,
                      name: widget.targetName,
                    ),
                    SizedBox(height: 20),
                    Text(
                      _callStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
