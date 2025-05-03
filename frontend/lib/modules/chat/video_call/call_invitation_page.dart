import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/common/config.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/modules/chat/video_call/video_call_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallInvitationPage extends StatefulWidget {
  final int userId; // 当前用户ID
  final int peerId; // 对方用户ID
  final String peerName; // 对方用户名
  final String peerAvatar; // 对方头像
  final bool isOutgoing; // 是否是拨出的通话
  final String callType; // 通话类型：'video' 或 'audio'

  const CallInvitationPage({
    Key? key,
    required this.userId,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.isOutgoing,
    this.callType = 'video',
  }) : super(key: key);

  @override
  _CallInvitationPageState createState() => _CallInvitationPageState();
}

class _CallInvitationPageState extends State<CallInvitationPage> {
  // WebSocket相关
  WebSocketChannel? _channel;
  bool _isChannelReady = false;
  String? _token;
  int? _callId;
  bool _isCallAccepted = false;
  bool _isCallRejected = false;
  bool _isCallEnded = false;
  String _callStatus = '正在连接...';
  Timer? _callTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _initWebSocket();

    // 如果是来电，播放铃声
    if (!widget.isOutgoing) {
      // 播放铃声的代码
    }
  }

  @override
  void dispose() {
    _disposeWebSocket();
    _callTimer?.cancel();
    super.dispose();
  }

  // 初始化WebSocket
  Future<void> _initWebSocket() async {
    try {
      // 获取token
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        _showError('获取用户信息失败');
        return;
      }

      _token = await Persistence.getTokenAsync();
      if (_token == null) {
        _showError('获取Token失败');
        return;
      }

      // 连接WebSocket
      final wsUrl = '${Config.wsBaseUrl}/ws?user_id=${widget.userId}&token=$_token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // 监听WebSocket消息
      _channel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket错误: $error');
          _showError('WebSocket连接错误');
        },
        onDone: () {
          debugPrint('WebSocket连接关闭');
          if (!_isCallEnded) {
            _showError('WebSocket连接已关闭');
          }
        },
      );

      // 等待WebSocket连接就绪
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _isChannelReady = true;
      });

      // 如果是拨出的通话，发送通话邀请
      if (widget.isOutgoing) {
        _sendCallInvitation();
      }
    } catch (e) {
      debugPrint('初始化WebSocket错误: $e');
      _showError('初始化WebSocket失败');
    }
  }

  // 处理WebSocket消息
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      switch (type) {
        case 'welcome':
          debugPrint('WebSocket连接成功');
          break;
        case 'call_invitation':
          _handleCallInvitation(data);
          break;
        case 'call_response':
          _handleCallResponse(data);
          break;
        case 'call_ended':
          _handleCallEnded(data);
          break;
        case 'pong':
          // 心跳响应，不需要处理
          break;
        default:
          debugPrint('未知的WebSocket消息类型: $type');
      }
    } catch (e) {
      debugPrint('处理WebSocket消息错误: $e');
    }
  }

  // 处理通话邀请
  void _handleCallInvitation(Map<String, dynamic> data) {
    if (data['from'] != widget.peerId) {
      return; // 忽略非目标用户的邀请
    }

    final callId = data['call_id'];
    final callType = data['call_type'];

    setState(() {
      _callId = callId;
      _callStatus = '收到${callType == 'video' ? '视频' : '语音'}通话邀请';
    });
  }

  // 处理通话响应
  void _handleCallResponse(Map<String, dynamic> data) {
    if (data['from'] != widget.peerId) {
      return; // 忽略非目标用户的响应
    }

    final callId = data['call_id'];
    final response = data['response'];

    setState(() {
      _callId = callId;
    });

    if (response == 'accepted') {
      setState(() {
        _isCallAccepted = true;
        _callStatus = '通话已接通';
      });

      // 跳转到视频通话页面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallPage(
            userId: widget.userId,
            peerId: widget.peerId,
            peerName: widget.peerName,
            peerAvatar: widget.peerAvatar,
            isOutgoing: widget.isOutgoing,
            callType: widget.callType,
          ),
        ),
      );
    } else {
      setState(() {
        _isCallRejected = true;
        _isCallEnded = true;
        _callStatus = '通话被拒绝';
      });

      // 延迟关闭页面
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    }
  }

  // 处理通话结束
  void _handleCallEnded(Map<String, dynamic> data) {
    if (data['from'] != widget.peerId) {
      return; // 忽略非目标用户的结束通知
    }

    final reason = data['reason'];
    setState(() {
      _isCallEnded = true;
      _callStatus = '通话已结束: $reason';
    });

    // 延迟关闭页面
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context);
    });
  }

  // 发送通话邀请
  void _sendCallInvitation() {
    if (!_isChannelReady || _channel == null) {
      debugPrint('WebSocket未就绪，无法发送通话邀请');
      return;
    }

    final message = {
      'type': 'call_invitation',
      'to': widget.peerId,
      'call_type': widget.callType,
    };

    _channel!.sink.add(jsonEncode(message));
    setState(() {
      _callStatus = '正在呼叫...';
    });

    // 设置超时
    Future.delayed(Duration(seconds: 30), () {
      if (mounted && !_isCallAccepted && !_isCallRejected && !_isCallEnded) {
        setState(() {
          _isCallEnded = true;
          _callStatus = '无人接听';
        });
        _endCall(true);
      }
    });
  }

  // 接受通话
  void _acceptCall() {
    if (!_isChannelReady || _channel == null || _callId == null) {
      debugPrint('WebSocket未就绪或通话ID为空，无法接受通话');
      return;
    }

    final message = {
      'type': 'call_response',
      'to': widget.peerId,
      'call_id': _callId,
      'call_type': widget.callType,
      'response': 'accepted',
    };

    _channel!.sink.add(jsonEncode(message));
    setState(() {
      _isCallAccepted = true;
      _callStatus = '通话已接通';
    });

    // 跳转到视频通话页面
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallPage(
          userId: widget.userId,
          peerId: widget.peerId,
          peerName: widget.peerName,
          peerAvatar: widget.peerAvatar,
          isOutgoing: widget.isOutgoing,
          callType: widget.callType,
        ),
      ),
    );
  }

  // 拒绝通话
  void _rejectCall() {
    if (!_isChannelReady || _channel == null || _callId == null) {
      debugPrint('WebSocket未就绪或通话ID为空，无法拒绝通话');
      return;
    }

    final message = {
      'type': 'call_response',
      'to': widget.peerId,
      'call_id': _callId,
      'call_type': widget.callType,
      'response': 'rejected',
    };

    _channel!.sink.add(jsonEncode(message));
    setState(() {
      _isCallRejected = true;
      _isCallEnded = true;
      _callStatus = '已拒绝通话';
    });

    // 延迟关闭页面
    Future.delayed(Duration(seconds: 1), () {
      Navigator.pop(context);
    });
  }

  // 结束通话
  void _endCall(bool sendEndSignal) {
    if (sendEndSignal && _isChannelReady && _channel != null && _callId != null) {
      final message = {
        'type': 'call_ended',
        'to': widget.peerId,
        'call_id': _callId,
        'call_type': widget.callType,
        'reason': 'normal',
      };

      _channel!.sink.add(jsonEncode(message));
    }

    setState(() {
      _isCallEnded = true;
      _callStatus = '通话已结束';
    });

    // 延迟关闭页面
    Future.delayed(Duration(seconds: 1), () {
      Navigator.pop(context);
    });
  }

  // 显示错误
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

  // 释放WebSocket资源
  void _disposeWebSocket() {
    _channel?.sink.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 80),
            // 头像
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.peerAvatar.isNotEmpty
                  ? NetworkImage(widget.peerAvatar)
                  : null,
              child: widget.peerAvatar.isEmpty
                  ? Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            SizedBox(height: 20),
            // 用户名
            Text(
              widget.peerName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            // 通话类型
            Text(
              widget.callType == 'video' ? '视频通话' : '语音通话',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 10),
            // 通话状态
            Text(
              _callStatus,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            Spacer(),
            // 通话控制按钮
            if (!_isCallEnded)
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: widget.isOutgoing
                    ? // 拨出的通话
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FloatingActionButton(
                            backgroundColor: Colors.red,
                            child: Icon(Icons.call_end, color: Colors.white),
                            onPressed: () => _endCall(true),
                          ),
                        ],
                      )
                    : // 来电
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 拒绝按钮
                          FloatingActionButton(
                            backgroundColor: Colors.red,
                            child: Icon(Icons.call_end, color: Colors.white),
                            onPressed: _rejectCall,
                          ),
                          SizedBox(width: 50),
                          // 接受按钮
                          FloatingActionButton(
                            backgroundColor: Colors.green,
                            child: Icon(
                              widget.callType == 'video'
                                  ? Icons.videocam
                                  : Icons.call,
                              color: Colors.white,
                            ),
                            onPressed: _acceptCall,
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
