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
    
    // 获取用户信息
    final response = await Api.getUserInfo(userId: fromId);
    
    if (response['success'] != true) {
      // 获取用户信息失败，拒绝通话
      await _webRTCService.rejectCall(callId, callType);
      return;
    }
    
    final userData = response['data'];
    final userName = userData['nickname'] ?? '未知用户';
    final userAvatar = userData['avatar'];
    
    // 获取全局上下文
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
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
class IncomingCallDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('来电'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: fromAvatar != null ? NetworkImage(fromAvatar!) : null,
            child: fromAvatar == null ? Text(fromName.substring(0, 1)) : null,
          ),
          SizedBox(height: 16),
          Text(
            fromName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            callType == 'video' ? '视频通话' : '语音通话',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onReject,
          child: Text('拒绝'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
        TextButton(
          onPressed: onAccept,
          child: Text('接听'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.green,
          ),
        ),
      ],
    );
  }
}
