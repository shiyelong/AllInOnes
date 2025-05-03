import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../widgets/app_avatar.dart';
import 'call_service.dart';

class VideoCallPage extends StatefulWidget {
  final String userId;
  final String targetId;
  final String targetName;
  final String targetAvatar;
  final bool isIncoming;
  final String? callId;

  const VideoCallPage({
    Key? key,
    required this.userId,
    required this.targetId,
    required this.targetName,
    required this.targetAvatar,
    this.isIncoming = false,
    this.callId,
  }) : super(key: key);

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final CallService _callService = CallService();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  String _callStatus = '正在连接...';
  Timer? _callTimer;
  int _callDuration = 0;
  bool _isControlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      // 设置回调函数
      _callService.onCallConnected = () {
        _startCallTimer();
        _startControlsTimer();
        setState(() {
          _isConnected = true;
          _callStatus = '通话中';
        });
      };

      _callService.onCallRejected = () {
        setState(() {
          _callStatus = '对方已拒绝';
        });
        _endCall(showDialog: true);
      };

      _callService.onCallEnded = () {
        _endCall();
      };

      _callService.onCallError = (error) {
        setState(() {
          _callStatus = error;
        });
        _showErrorDialog(error);
      };

      _callService.onStatusChanged = (status) {
        setState(() {
          _callStatus = status;
        });
      };

      // 初始化WebRTC
      await _callService.initialize();

      // 设置视频渲染器
      _callService.setVideoRenderers(_localRenderer, _remoteRenderer);

      if (widget.isIncoming) {
        // 接听来电
        if (widget.callId != null) {
          await _callService.answerVideoCall(widget.callId!);
          _startCallTimer();
          _startControlsTimer();
          setState(() {
            _isConnected = true;
            _callStatus = '通话中';
          });
        }
      } else {
        // 发起呼叫
        setState(() {
          _callStatus = '正在呼叫...';
        });

        final callId = await _callService.startVideoCall(
          widget.userId,
          widget.targetId,
        );

        if (callId == null) {
          // 呼叫失败
          setState(() {
            _callStatus = '呼叫失败';
          });
          _showCallFailedDialog();
        }
      }
    } catch (e) {
      debugPrint('初始化通话失败: $e');
      setState(() {
        _callStatus = '连接失败: $e';
      });
      _showCallFailedDialog();
    }
  }

  // 显示错误对话框
  Future<void> _showErrorDialog(String error) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('通话错误'),
        content: Text(error),
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

  void _startCallTimer() {
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 5), () {
      if (mounted && _isConnected) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    final result = await _callService.toggleMute();
    setState(() {
      _isMuted = result;
    });
    _startControlsTimer();
  }

  Future<void> _toggleCamera() async {
    final result = await _callService.toggleCamera();
    setState(() {
      _isCameraOff = result;
    });
    _startControlsTimer();
  }

  Future<void> _switchCamera() async {
    await _callService.switchCamera();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _startControlsTimer();
  }

  Future<void> _endCall({bool showDialog = false}) async {
    _callTimer?.cancel();
    _controlsTimer?.cancel();
    await _callService.endCall();

    if (mounted) {
      if (showDialog) {
        await _showCallEndedDialog();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showCallFailedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('通话失败'),
        content: Text('无法建立通话连接，请检查网络后重试。'),
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

  Future<void> _showCallEndedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('通话结束'),
        content: Text('通话已结束'),
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

  @override
  void dispose() {
    _callTimer?.cancel();
    _controlsTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_isConnected) {
            setState(() {
              _isControlsVisible = !_isControlsVisible;
            });
            if (_isControlsVisible) {
              _startControlsTimer();
            }
          }
        },
        child: Stack(
          children: [
            // 远程视频（全屏）
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

            // 本地视频（小窗口）
            Positioned(
              right: 16,
              top: 60,
              width: 100,
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _isCameraOff
                      ? Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        )
                      : RTCVideoView(
                          _localRenderer,
                          mirror: _isFrontCamera,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                ),
              ),
            ),

            // 顶部状态栏（仅在控制可见时显示）
            if (_isControlsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isConnected ? '视频通话' : '正在呼叫...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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

            // 未连接时显示对方头像
            if (!_isConnected)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppAvatar(
                      name: widget.targetName,
                      size: 120,
                      imageUrl: widget.targetAvatar,
                    ),
                    SizedBox(height: 24),
                    Text(
                      widget.targetName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // 底部控制按钮（仅在控制可见时显示）
            if (_isControlsVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    top: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 麦克风按钮
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        label: _isMuted ? '取消静音' : '静音',
                        onPressed: _toggleMute,
                        backgroundColor: _isMuted ? Colors.red : Colors.white24,
                      ),

                      // 摄像头开关按钮
                      _buildControlButton(
                        icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                        label: _isCameraOff ? '开启摄像头' : '关闭摄像头',
                        onPressed: _toggleCamera,
                        backgroundColor: _isCameraOff ? Colors.red : Colors.white24,
                      ),

                      // 挂断按钮
                      _buildControlButton(
                        icon: Icons.call_end,
                        label: '挂断',
                        onPressed: () => _endCall(),
                        backgroundColor: Colors.red,
                        size: 64,
                      ),

                      // 切换摄像头按钮
                      _buildControlButton(
                        icon: Icons.flip_camera_ios,
                        label: '切换摄像头',
                        onPressed: _switchCamera,
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 56,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
            iconSize: size * 0.5,
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
