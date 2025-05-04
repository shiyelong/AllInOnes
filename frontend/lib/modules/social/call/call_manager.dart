import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/modules/social/call/enhanced_video_call_page.dart';
import 'package:frontend/modules/social/call/enhanced_voice_call_page.dart';
import 'package:frontend/modules/social/call/webrtc_service.dart';

/// 通话管理器
/// 用于管理语音和视频通话
class CallManager {
  // 单例模式
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  // WebRTC服务
  final WebRTCService _webRTCService = WebRTCService();

  // 当前通话状态
  bool _isInCall = false;

  // Getters
  bool get isInCall => _isInCall;

  /// 初始化
  Future<void> initialize() async {
    await _webRTCService.initialize();

    // 设置来电监听
    _webRTCService.onIncomingCall = (callData) {
      _handleIncomingCall(callData);
    };
  }

  /// 处理来电
  void _handleIncomingCall(Map<String, dynamic> callData) async {
    if (_isInCall) {
      // 已经在通话中，自动拒绝
      await _webRTCService.rejectCall(
        callData['call_id'].toString(),
        callData['call_type'],
      );
      return;
    }

    // 获取来电者信息
    final fromId = callData['from_id'].toString();
    final callType = callData['call_type'];
    final callId = callData['call_id'].toString();

    debugPrint('[CallManager] 收到来电: fromId=$fromId, callType=$callType, callId=$callId');

    // 获取用户信息
    final response = await Api.getUserInfo(userId: fromId);

    if (response['success'] != true) {
      debugPrint('[CallManager] 获取用户信息失败: ${response['msg']}');
      // 获取用户信息失败，拒绝通话
      await _webRTCService.rejectCall(callId, callType);
      return;
    }

    final userData = response['data'];
    final userName = userData['nickname'] ?? '未知用户';
    final userAvatar = userData['avatar'];

    debugPrint('[CallManager] 来电用户信息: name=$userName, avatar=$userAvatar');

    // 获取全局上下文
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[CallManager] 无法获取全局上下文，无法显示来电界面');
      return;
    }

    // 播放来电铃声
    // TODO: 添加来电铃声

    // 显示来电界面
    _showIncomingCallDialog(
      context: context,
      fromId: fromId,
      fromName: userName,
      fromAvatar: userAvatar,
      callType: callType,
      callId: callId,
    );
  }

  /// 显示来电对话框
  void _showIncomingCallDialog({
    required BuildContext context,
    required String fromId,
    required String fromName,
    String? fromAvatar,
    required String callType,
    required String callId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallDialog(
        fromId: fromId,
        fromName: fromName,
        fromAvatar: fromAvatar,
        callType: callType,
        callId: callId,
        onAccept: () {
          Navigator.of(context).pop();
          _acceptCall(
            context: context,
            targetId: fromId,
            targetName: fromName,
            targetAvatar: fromAvatar,
            callType: callType,
            callId: callId,
          );
        },
        onReject: () async {
          Navigator.of(context).pop();
          await _webRTCService.rejectCall(callId, callType);
        },
      ),
    );
  }

  /// 接受通话
  void _acceptCall({
    required BuildContext context,
    required String targetId,
    required String targetName,
    String? targetAvatar,
    required String callType,
    required String callId,
  }) {
    _isInCall = true;

    if (callType == 'video') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EnhancedVideoCallPage(
            targetId: targetId,
            targetName: targetName,
            targetAvatar: targetAvatar,
            isIncoming: true,
            callId: callId,
          ),
        ),
      ).then((_) {
        _isInCall = false;
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EnhancedVoiceCallPage(
            targetId: targetId,
            targetName: targetName,
            targetAvatar: targetAvatar,
            isIncoming: true,
            callId: callId,
          ),
        ),
      ).then((_) {
        _isInCall = false;
      });
    }
  }

  /// 发起语音通话
  Future<void> startVoiceCall({
    required BuildContext context,
    required String targetId,
    required String targetName,
    String? targetAvatar,
  }) async {
    if (_isInCall) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('您已经在通话中'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _isInCall = true;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedVoiceCallPage(
          targetId: targetId,
          targetName: targetName,
          targetAvatar: targetAvatar,
        ),
      ),
    ).then((_) {
      _isInCall = false;
    });
  }

  /// 发起视频通话
  Future<void> startVideoCall({
    required BuildContext context,
    required String targetId,
    required String targetName,
    String? targetAvatar,
  }) async {
    if (_isInCall) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('您已经在通话中'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _isInCall = true;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedVideoCallPage(
          targetId: targetId,
          targetName: targetName,
          targetAvatar: targetAvatar,
        ),
      ),
    ).then((_) {
      _isInCall = false;
    });
  }
}

/// 全局导航键
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 来电对话框
class IncomingCallDialog extends StatefulWidget {
  final String fromId;
  final String fromName;
  final String? fromAvatar;
  final String callType;
  final String callId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallDialog({
    Key? key,
    required this.fromId,
    required this.fromName,
    this.fromAvatar,
    required this.callType,
    required this.callId,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  _IncomingCallDialogState createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              '来电',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: widget.callType == 'video' ? Colors.blue : Colors.green,
              ),
            ),
            SizedBox(height: 20),

            // 头像
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.callType == 'video' ? Colors.blue : Colors.green,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: widget.fromAvatar != null ? NetworkImage(widget.fromAvatar!) : null,
                      backgroundColor: Colors.grey.shade200,
                      child: widget.fromAvatar == null
                          ? Text(
                              widget.fromName.isNotEmpty ? widget.fromName.substring(0, 1).toUpperCase() : '?',
                              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20),

            // 用户名
            Text(
              widget.fromName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),

            // 通话类型
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.callType == 'video' ? Icons.videocam : Icons.phone,
                  color: widget.callType == 'video' ? Colors.blue : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  widget.callType == 'video' ? '视频通话' : '语音通话',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),

            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 拒绝按钮
                _buildCallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: '拒绝',
                  onPressed: widget.onReject,
                ),

                // 接听按钮
                _buildCallButton(
                  icon: widget.callType == 'video' ? Icons.videocam : Icons.call,
                  color: Colors.green,
                  label: '接听',
                  onPressed: widget.onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
