import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/modules/social/call/webrtc_service.dart';
import 'package:frontend/widgets/app_avatar.dart';

class EnhancedVoiceCallPage extends StatefulWidget {
  final String targetId;
  final String targetName;
  final String? targetAvatar;
  final bool isIncoming;
  final String? callId;

  const EnhancedVoiceCallPage({
    Key? key,
    required this.targetId,
    required this.targetName,
    this.targetAvatar,
    this.isIncoming = false,
    this.callId,
  }) : super(key: key);

  @override
  _EnhancedVoiceCallPageState createState() => _EnhancedVoiceCallPageState();
}

class _EnhancedVoiceCallPageState extends State<EnhancedVoiceCallPage> with SingleTickerProviderStateMixin {
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
  bool _isSpeakerOn = true;

  // 计时器
  Timer? _callTimer;
  int _callDuration = 0;

  // 用户信息
  String? _userId;

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);

    _initializeCall();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webRTCService.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 初始化通话
  Future<void> _initializeCall() async {
    try {
      debugPrint('[EnhancedVoiceCallPage] 初始化通话');

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

      debugPrint('[EnhancedVoiceCallPage] 用户ID: $_userId, 目标ID: ${widget.targetId}');
      debugPrint('[EnhancedVoiceCallPage] 是否为来电: ${widget.isIncoming}, 通话ID: ${widget.callId}');

      // 设置回调函数
      _webRTCService.onCallStateChanged = (status) {
        debugPrint('[EnhancedVoiceCallPage] 通话状态变更: $status');
        if (mounted) {
          setState(() {
            _callStatus = status;
          });
        }
      };

      _webRTCService.onCallConnected = () {
        debugPrint('[EnhancedVoiceCallPage] 通话已连接');
        if (mounted) {
          setState(() {
            _isConnected = true;
            _callStatus = '通话中';
          });
          _startCallTimer();
        }
      };

      _webRTCService.onCallEnded = () {
        debugPrint('[EnhancedVoiceCallPage] 通话已结束');
        if (mounted) {
          setState(() {
            _isCallEnded = true;
          });
          Navigator.of(context).pop();
        }
      };

      _webRTCService.onError = (error) {
        debugPrint('[EnhancedVoiceCallPage] 通话错误: $error');
        _showError(error);
      };

      // 初始化WebRTC服务
      await _webRTCService.initialize();

      if (widget.isIncoming) {
        // 接听来电
        if (widget.callId != null) {
          debugPrint('[EnhancedVoiceCallPage] 接听来电: ${widget.callId}');
          final result = await _webRTCService.answerCall(widget.callId!, 'voice');

          if (!result) {
            debugPrint('[EnhancedVoiceCallPage] 接听来电失败');
            _showError('接听来电失败');
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        } else {
          debugPrint('[EnhancedVoiceCallPage] 来电ID为空');
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

        debugPrint('[EnhancedVoiceCallPage] 发起呼叫: ${widget.targetId}');
        final callId = await _webRTCService.startVoiceCall(widget.targetId);

        if (callId == null) {
          // 呼叫失败
          debugPrint('[EnhancedVoiceCallPage] 呼叫失败');
          setState(() {
            _callStatus = '呼叫失败';
          });
          _showCallFailedDialog();
        } else {
          debugPrint('[EnhancedVoiceCallPage] 呼叫成功，通话ID: $callId');
        }
      }
    } catch (e) {
      debugPrint('[EnhancedVoiceCallPage] 初始化通话失败: $e');
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

  // 切换麦克风
  void _toggleMicrophone() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _webRTCService.toggleMicrophone(!_isMuted);
  }

  // 切换扬声器
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: 实现扬声器切换
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.indigo.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 顶部状态栏
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Text(
                      '语音通话',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.targetName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
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

              // 中间头像
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isConnected ? 1.0 : _animation.value,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isConnected ? Colors.green : Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: AppAvatar(
                        imageUrl: widget.targetAvatar,
                        size: 120,
                        name: widget.targetName,
                      ),
                    ),
                  );
                },
              ),

              // 底部控制栏
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
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
                      icon: Icons.call_end,
                      label: '结束通话',
                      onPressed: _endCall,
                      backgroundColor: Colors.red,
                      size: 70,
                    ),
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      label: _isSpeakerOn ? '扬声器' : '听筒',
                      onPressed: _toggleSpeaker,
                      backgroundColor: Colors.white24,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    double size = 60,
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
            icon: Icon(icon, color: Colors.white, size: size * 0.5),
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
