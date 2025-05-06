import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_avatar.dart';

/// 显示通话对话框
/// 
/// 参数:
/// - context: 上下文
/// - targetId: 目标用户ID
/// - targetName: 目标用户名称
/// - targetAvatar: 目标用户头像
/// - isIncoming: 是否是来电
/// - callType: 通话类型 (voice/video)
/// - callId: 通话ID
/// 
/// 返回值:
/// - 'accept': 接受通话
/// - 'reject': 拒绝通话
/// - 'cancel': 取消通话
/// - 'timeout': 超时
Future<String> showSimplifiedCallDialog({
  required BuildContext context,
  required String targetId,
  required String targetName,
  String? targetAvatar,
  required bool isIncoming,
  required String callType,
  String? callId,
}) async {
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SimplifiedCallDialog(
      targetId: targetId,
      targetName: targetName,
      targetAvatar: targetAvatar,
      isIncoming: isIncoming,
      callType: callType,
      callId: callId,
    ),
  );
  
  return result ?? 'timeout';
}

/// 简化版通话对话框
class SimplifiedCallDialog extends StatefulWidget {
  final String targetId;
  final String targetName;
  final String? targetAvatar;
  final bool isIncoming;
  final String callType;
  final String? callId;

  const SimplifiedCallDialog({
    Key? key,
    required this.targetId,
    required this.targetName,
    this.targetAvatar,
    required this.isIncoming,
    required this.callType,
    this.callId,
  }) : super(key: key);

  @override
  _SimplifiedCallDialogState createState() => _SimplifiedCallDialogState();
}

class _SimplifiedCallDialogState extends State<SimplifiedCallDialog> with SingleTickerProviderStateMixin {
  late AnimationController _avatarController;
  late Animation<double> _avatarAnimation;
  Timer? _callTimer;
  int _callDuration = 0;
  bool _isConnected = false;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化头像动画
    _avatarController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    
    _avatarAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _avatarController,
        curve: Curves.easeInOut,
      ),
    );
    
    _avatarController.repeat(reverse: true);
    
    // 如果是拨出电话，30秒后自动取消
    if (!widget.isIncoming) {
      Future.delayed(Duration(seconds: 30), () {
        if (mounted && !_isConnected) {
          Navigator.of(context).pop('timeout');
        }
      });
    }
    
    // 如果是来电，60秒后自动拒绝
    if (widget.isIncoming) {
      Future.delayed(Duration(seconds: 60), () {
        if (mounted && !_isConnected) {
          Navigator.of(context).pop('timeout');
        }
      });
    }
  }
  
  @override
  void dispose() {
    _avatarController.dispose();
    _callTimer?.cancel();
    super.dispose();
  }
  
  // 格式化通话时长
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  // 开始通话计时
  void _startCallTimer() {
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }
  
  // 接受通话
  void _acceptCall() {
    setState(() {
      _isConnected = true;
      _avatarController.stop();
    });
    
    _startCallTimer();
    
    // 这里不关闭对话框，而是显示通话中的界面
  }
  
  // 拒绝通话
  void _rejectCall() {
    Navigator.of(context).pop('reject');
  }
  
  // 取消通话
  void _cancelCall() {
    Navigator.of(context).pop('cancel');
  }
  
  // 结束通话
  void _endCall() {
    Navigator.of(context).pop('end');
  }
  
  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';
    final callTypeText = isVideo ? '视频通话' : '语音通话';
    final callStatusText = widget.isIncoming 
        ? '邀请你进行$callTypeText' 
        : _isConnected 
            ? '通话中' 
            : '正在等待对方接听...';
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 300,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              _isConnected ? callTypeText : widget.isIncoming ? '来电' : '拨出',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isVideo ? Colors.blue : Colors.green,
              ),
            ),
            SizedBox(height: 20),
            
            // 头像
            _isConnected
                ? Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isVideo ? Colors.blue : Colors.green,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: AppAvatar(
                        imageUrl: widget.targetAvatar,
                        name: widget.targetName,
                        size: 100,
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _avatarAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _avatarAnimation.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isVideo ? Colors.blue : Colors.green,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: AppAvatar(
                              imageUrl: widget.targetAvatar,
                              name: widget.targetName,
                              size: 100,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            SizedBox(height: 20),
            
            // 用户名
            Text(
              widget.targetName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 10),
            
            // 通话状态
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.phone,
                  color: isVideo ? Colors.blue : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  callStatusText,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            
            // 通话时长
            if (_isConnected) ...[
              SizedBox(height: 10),
              Text(
                _formatDuration(_callDuration),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
            
            SizedBox(height: 30),
            
            // 按钮
            _buildCallButtons(),
          ],
        ),
      ),
    );
  }
  
  // 构建通话按钮
  Widget _buildCallButtons() {
    if (_isConnected) {
      // 通话中的按钮
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCallButton(
            icon: Icons.call_end,
            color: Colors.red,
            label: '结束',
            onPressed: _endCall,
          ),
        ],
      );
    } else if (widget.isIncoming) {
      // 来电按钮
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCallButton(
            icon: Icons.call_end,
            color: Colors.red,
            label: '拒绝',
            onPressed: _rejectCall,
          ),
          _buildCallButton(
            icon: widget.callType == 'video' ? Icons.videocam : Icons.call,
            color: Colors.green,
            label: '接听',
            onPressed: _acceptCall,
          ),
        ],
      );
    } else {
      // 拨出按钮
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCallButton(
            icon: Icons.call_end,
            color: Colors.red,
            label: '取消',
            onPressed: _cancelCall,
          ),
        ],
      );
    }
  }
  
  // 构建单个通话按钮
  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
