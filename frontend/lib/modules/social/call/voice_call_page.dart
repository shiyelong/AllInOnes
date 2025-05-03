import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../widgets/app_avatar.dart';
import 'call_service.dart';

class VoiceCallPage extends StatefulWidget {
  final String userId;
  final String targetId;
  final String targetName;
  final String targetAvatar;
  final bool isIncoming;
  final String? callId;

  const VoiceCallPage({
    Key? key,
    required this.userId,
    required this.targetId,
    required this.targetName,
    required this.targetAvatar,
    this.isIncoming = false,
    this.callId,
  }) : super(key: key);

  @override
  _VoiceCallPageState createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  final CallService _callService = CallService();

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String _callStatus = '正在连接...';
  Timer? _callTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      // 设置回调函数
      _callService.onCallConnected = () {
        _startCallTimer();
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

      if (widget.isIncoming) {
        // 接听来电
        if (widget.callId != null) {
          await _callService.answerCall(widget.callId!);
          _startCallTimer();
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

        final callId = await _callService.startVoiceCall(
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
  }

  Future<void> _toggleSpeaker() async {
    final result = await _callService.toggleSpeaker();
    setState(() {
      _isSpeakerOn = result;
    });
  }

  Future<void> _endCall({bool showDialog = false}) async {
    _callTimer?.cancel();
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
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 顶部状态栏
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    _isConnected ? '语音通话' : '正在呼叫...',
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

            // 中间头像区域
            Expanded(
              child: Center(
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
            ),

            // 底部控制按钮
            Container(
              padding: EdgeInsets.symmetric(vertical: 32),
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

                  // 挂断按钮
                  _buildControlButton(
                    icon: Icons.call_end,
                    label: '挂断',
                    onPressed: () => _endCall(),
                    backgroundColor: Colors.red,
                    size: 64,
                  ),

                  // 扬声器按钮
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    label: _isSpeakerOn ? '关闭扬声器' : '扬声器',
                    onPressed: _toggleSpeaker,
                    backgroundColor: _isSpeakerOn ? AppTheme.primaryColor : Colors.white24,
                  ),
                ],
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
