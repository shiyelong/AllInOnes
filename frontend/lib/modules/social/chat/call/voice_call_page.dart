import 'package:flutter/material.dart';
import '../../../../common/persistence.dart';
import '../../../../common/api.dart';
import '../../../../common/theme_manager.dart';
import 'dart:async';

class VoiceCallPage extends StatefulWidget {
  final String targetId;
  final String targetName;
  final String targetAvatar;
  final bool isIncoming;
  
  const VoiceCallPage({
    Key? key,
    required this.targetId,
    required this.targetName,
    required this.targetAvatar,
    this.isIncoming = false,
  }) : super(key: key);

  @override
  _VoiceCallPageState createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
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
        _callStatus = '来电...';
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
      final response = await Api.startVoiceCall(
        fromId: userId.toString(),
        toId: widget.targetId,
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
  
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: 实现实际的扬声器切换功能
  }
  
  void _endCall() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      Navigator.pop(context);
      return;
    }
    
    try {
      await Api.endVoiceCall(
        fromId: userId.toString(),
        toId: widget.targetId,
      );
    } catch (e) {
      print('结束通话出错: $e');
    }
    
    Navigator.pop(context);
  }
  
  void _acceptCall() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      _handleCallError('未获取到用户信息');
      return;
    }
    
    try {
      final response = await Api.acceptVoiceCall(
        fromId: widget.targetId,
        toId: userId.toString(),
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
      await Api.rejectVoiceCall(
        fromId: widget.targetId,
        toId: userId.toString(),
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
      backgroundColor: theme.isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(height: 40),
            Column(
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _isConnected ? _formatDuration(_callDuration) : _callStatus,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: widget.isIncoming && !_isConnected
                  ? _buildIncomingCallActions()
                  : _buildCallActions(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCallActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: _isMuted ? '取消静音' : '静音',
          onPressed: _toggleMute,
          color: _isMuted ? Colors.red : null,
        ),
        _buildActionButton(
          icon: Icons.call_end,
          label: '结束',
          onPressed: _endCall,
          color: Colors.red,
          large: true,
        ),
        _buildActionButton(
          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          label: _isSpeakerOn ? '关闭扬声器' : '扬声器',
          onPressed: _toggleSpeaker,
          color: _isSpeakerOn ? ThemeManager.currentTheme.primaryColor : null,
        ),
      ],
    );
  }
  
  Widget _buildIncomingCallActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.call_end,
          label: '拒绝',
          onPressed: _rejectCall,
          color: Colors.red,
        ),
        _buildActionButton(
          icon: Icons.call,
          label: '接听',
          onPressed: _acceptCall,
          color: Colors.green,
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
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
            color: color ?? Colors.grey[300],
          ),
          child: IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
            color: Colors.white,
            iconSize: large ? 30 : 24,
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
