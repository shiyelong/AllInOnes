import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/widgets/app_avatar.dart';

class EnhancedVideoCallPage extends StatefulWidget {
  final int userId;
  final int peerId;
  final String peerName;
  final String peerAvatar;
  final bool isOutgoing;
  final String callType; // 'audio' or 'video'

  const EnhancedVideoCallPage({
    Key? key,
    required this.userId,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.isOutgoing,
    required this.callType,
  }) : super(key: key);

  @override
  _EnhancedVideoCallPageState createState() => _EnhancedVideoCallPageState();
}

class _EnhancedVideoCallPageState extends State<EnhancedVideoCallPage> with SingleTickerProviderStateMixin {
  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isMinimized = false;
  bool _isControlsVisible = true;
  Timer? _controlsTimer;
  Timer? _callDurationTimer;
  int _callDuration = 0;
  String _callStatus = '';
  String _errorMessage = '';

  // 模拟视频流
  Widget _localVideoView = Container(color: Colors.black);
  Widget _remoteVideoView = Container(color: Colors.black);
  
  // UI动画相关
  late AnimationController _backgroundAnimController;
  late Animation<Color?> _backgroundColorAnimation;

  @override
  void initState() {
    super.initState();
    
    // 设置全屏和横屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // 初始化通话
    _initializeCall();
    
    // 设置控制栏自动隐藏
    _resetControlsTimer();
    
    // 初始化动画
    _initAnimations();
  }

  @override
  void dispose() {
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // 取消定时器
    _controlsTimer?.cancel();
    _callDurationTimer?.cancel();
    
    // 结束通话
    _endCall();
    
    // 释放动画控制器
    _backgroundAnimController.dispose();
    
    super.dispose();
  }

  // 初始化动画
  void _initAnimations() {
    _backgroundAnimController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    final theme = ThemeManager.currentTheme;
    _backgroundColorAnimation = ColorTween(
      begin: theme.primaryColor.withOpacity(0.8),
      end: Colors.blue.shade300,
    ).animate(_backgroundAnimController);
  }

  void _initializeCall() async {
    setState(() {
      _callStatus = widget.isOutgoing ? '正在呼叫...' : '来电接通中...';
    });

    try {
      // 模拟连接过程
      await Future.delayed(Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = true;
          _callStatus = '通话中';
          
          // 如果是语音通话，默认关闭视频
          if (widget.callType == 'audio') {
            _isVideoEnabled = false;
          }
        });
        
        // 开始计时
        _startCallDurationTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = '连接失败: $e';
        });
      }
    }
  }

  void _startCallDurationTimer() {
    _callDurationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    
    setState(() {
      _isControlsVisible = true;
    });
    
    _controlsTimer = Timer(Duration(seconds: 5), () {
      if (mounted && _isConnected) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    
    if (_isControlsVisible) {
      _resetControlsTimer();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _resetControlsTimer();
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _resetControlsTimer();
  }

  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    _resetControlsTimer();
  }

  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _resetControlsTimer();
  }

  void _toggleMinimize() {
    setState(() {
      _isMinimized = !_isMinimized;
    });
    _resetControlsTimer();
  }

  void _endCall() {
    Navigator.of(context).pop();
  }

  void _pauseVideo() {
    // 实际实现中应该暂停视频流
    debugPrint('暂停视频');
  }

  void _resumeVideo() {
    // 实际实现中应该恢复视频流
    debugPrint('恢复视频');
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 远程视频（全屏背景）
            if (widget.callType == 'video' && _isVideoEnabled)
              Positioned.fill(
                child: _isConnected
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      )
                    : Container(color: Colors.black),
              ),
            
            // 语音通话界面
            if (widget.callType == 'audio' || !_isVideoEnabled)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _backgroundAnimController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _backgroundColorAnimation.value ?? theme.primaryColor.withOpacity(0.8),
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: child,
                    );
                  },
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppAvatar(
                          name: widget.peerName,
                          imageUrl: widget.peerAvatar,
                          size: 120,
                        ),
                        SizedBox(height: 24),
                        Text(
                          widget.peerName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _isConnected
                              ? _formatDuration(_callDuration)
                              : _callStatus,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // 本地视频（小窗口）
            if (widget.callType == 'video' && _isVideoEnabled && _isConnected && !_isMinimized)
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: _toggleMinimize,
                  child: Container(
                    width: size.width * 0.3,
                    height: size.height * 0.2,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _localVideoView,
                    ),
                  ),
                ),
              ),
            
            // 最小化的本地视频（浮动图标）
            if (widget.callType == 'video' && _isVideoEnabled && _isConnected && _isMinimized)
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: _toggleMinimize,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.videocam,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            
            // 顶部状态栏
            if (_isControlsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 16),
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
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('结束通话'),
                            content: Text('确定要结束当前通话吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _endCall();
                                },
                                child: Text('确定'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.callType == 'video' ? '视频通话' : '语音通话',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _isConnected
                                  ? _formatDuration(_callDuration)
                                  : _callStatus,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                        ),
                        onPressed: _toggleSpeaker,
                      ),
                    ],
                  ),
                ),
              ),
            
            // 底部控制栏
            if (_isControlsVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 16),
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
                        onPressed: _toggleMute,
                      ),
                      if (widget.callType == 'video')
                        _buildControlButton(
                          icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                          label: _isVideoEnabled ? '关闭视频' : '开启视频',
                          onPressed: _toggleVideo,
                        ),
                      if (widget.callType == 'video' && _isVideoEnabled)
                        _buildControlButton(
                          icon: _isFrontCamera ? Icons.flip_camera_ios : Icons.flip_camera_android,
                          label: '切换摄像头',
                          onPressed: _switchCamera,
                        ),
                      _buildControlButton(
                        icon: Icons.call_end,
                        label: '结束通话',
                        backgroundColor: Colors.red,
                        onPressed: _endCall,
                      ),
                    ],
                  ),
                ),
              ),
            
            // 连接中或错误提示
            if (_isConnecting || _errorMessage.isNotEmpty)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: _errorMessage.isNotEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _endCall,
                                child: Text('返回'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              SizedBox(height: 16),
                              Text(
                                _callStatus,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
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
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon),
            color: Colors.white,
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
