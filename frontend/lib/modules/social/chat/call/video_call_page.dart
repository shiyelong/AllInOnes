import 'package:flutter/material.dart';
import '../../../../common/persistence.dart';
import '../../../../common/api.dart';
import '../../../../common/theme_manager.dart';
import 'dart:async';

class VideoCallPage extends StatefulWidget {
  final String targetId;
  final String targetName;
  final String? targetAvatar;
  final bool isIncoming;
  final VoidCallback onCallEnded;
  final String? callId;

  const VideoCallPage({
    Key? key,
    required this.targetId,
    required this.targetName,
    this.targetAvatar,
    this.isIncoming = false,
    required this.onCallEnded,
    this.callId,
  }) : super(key: key);

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isConnected = false;
  bool _isFrontCamera = true;
  String _callStatus = '正在连接...';
  Timer? _callTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();

    if (!widget.isIncoming) {
      _initiateCall();
    } else {
      setState(() {
        _callStatus = '视频来电...';
      });
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiateCall() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      _handleCallError('未获取到用户信息');
      return;
    }

    try {
      // 使用新的API方法
      final response = await Api.startVideoCallWithId(
        targetId: widget.targetId,
      );

      if (response['success'] == true) {
        setState(() {
          _callStatus = '正在呼叫...';
        });

        // 模拟对方接听
        Future.delayed(Duration(seconds: 2), () {
          _handleCallConnected();
        });
      } else {
        _handleCallError(response['msg'] ?? '呼叫失败');
      }
    } catch (e) {
      _handleCallError('网络异常: $e');
    }
  }

  void _handleCallConnected() {
    setState(() {
      _isConnected = true;
      _callStatus = '已接通';
    });

    // 开始计时
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  void _handleCallError(String error) {
    setState(() {
      _callStatus = '呼叫失败: $error';
    });

    // 显示错误后返回
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context);
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    // TODO: 实现实际的静音功能
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    // TODO: 实现实际的摄像头开关功能
  }

  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    // TODO: 实现实际的摄像头切换功能
  }

  void _endCall() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      Navigator.pop(context);
      return;
    }

    try {
      // 使用新的API方法
      await Api.endVideoCallWithId(
        callId: widget.targetId,
      );
    } catch (e) {
      print('结束通话出错: $e');
    }

    // 调用通话结束回调
    widget.onCallEnded();

    Navigator.pop(context);
  }

  void _acceptCall() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      _handleCallError('未获取到用户信息');
      return;
    }

    try {
      final response = await Api.acceptVideoCall(
        callId: widget.targetId,
      );

      if (response['success'] == true) {
        _handleCallConnected();
      } else {
        _handleCallError(response['msg'] ?? '接听失败');
      }
    } catch (e) {
      _handleCallError('网络异常: $e');
    }
  }

  void _rejectCall() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      Navigator.pop(context);
      return;
    }

    try {
      // 使用新的API方法
      await Api.rejectVideoCallWithId(
        callId: widget.targetId,
      );
    } catch (e) {
      print('拒绝通话出错: $e');
    }

    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 远程视频（对方）
          _isConnected
              ? Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      '对方视频画面',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: theme.primaryColor.withOpacity(0.2),
                          child: Text(
                            widget.targetName[0],
                            style: TextStyle(fontSize: 40, color: theme.primaryColor),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          widget.targetName,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _callStatus,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

          // 本地视频（自己）
          if (_isConnected)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isCameraOn
                    ? Center(
                        child: Text(
                          '本地视频画面',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Center(
                        child: Icon(Icons.videocam_off, color: Colors.white, size: 40),
                      ),
              ),
            ),

          // 通话时长
          if (_isConnected)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(_callDuration),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),

          // 控制按钮
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: widget.isIncoming && !_isConnected
                ? _buildIncomingCallActions()
                : _buildCallActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallActions() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      color: Colors.black.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? '取消静音' : '静音',
            onPressed: _toggleMute,
            color: _isMuted ? Colors.red : Colors.white,
          ),
          _buildActionButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: _isCameraOn ? '关闭摄像头' : '开启摄像头',
            onPressed: _toggleCamera,
            color: _isCameraOn ? Colors.white : Colors.red,
          ),
          _buildActionButton(
            icon: Icons.switch_camera,
            label: '切换摄像头',
            onPressed: _switchCamera,
            color: Colors.white,
          ),
          _buildActionButton(
            icon: Icons.call_end,
            label: '结束',
            onPressed: _endCall,
            color: Colors.red,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingCallActions() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      color: Colors.black.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.call_end,
            label: '拒绝',
            onPressed: _rejectCall,
            color: Colors.red,
          ),
          _buildActionButton(
            icon: Icons.videocam,
            label: '接听',
            onPressed: _acceptCall,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool large = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: large ? 70 : 60,
          height: large ? 70 : 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color == Colors.white ? Colors.white.withOpacity(0.3) : color,
          ),
          child: IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
            color: color == Colors.white ? Colors.white : Colors.white,
            iconSize: large ? 30 : 24,
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white)),
      ],
    );
  }
}
