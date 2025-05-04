import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// 模拟信令服务器
/// 用于在本地测试WebRTC通话功能
class MockSignalingServer {
  // 单例模式
  static final MockSignalingServer _instance = MockSignalingServer._internal();
  factory MockSignalingServer() => _instance;
  MockSignalingServer._internal();
  
  // 服务器实例
  late Router _router;
  dynamic _server;
  
  // 连接的客户端
  final Map<String, StreamController<String>> _clients = {};
  
  // 通话状态
  final Map<String, Map<String, dynamic>> _calls = {};
  
  /// 启动服务器
  Future<void> start({int port = 3002}) async {
    try {
      // 创建路由
      _router = Router();
      
      // WebSocket连接
      _router.get('/ws', _handleWebSocket);
      
      // 通话相关API
      _router.post('/api/call/start', _handleStartCall);
      _router.post('/api/call/answer', _handleAnswerCall);
      _router.post('/api/call/reject', _handleRejectCall);
      _router.post('/api/call/end', _handleEndCall);
      
      // 启动服务器
      _server = await shelf_io.serve(_router, 'localhost', port);
      
      debugPrint('[MockSignalingServer] 服务器已启动，端口: $port');
    } catch (e) {
      debugPrint('[MockSignalingServer] 启动服务器失败: $e');
    }
  }
  
  /// 停止服务器
  Future<void> stop() async {
    try {
      // 关闭所有客户端连接
      for (final client in _clients.values) {
        await client.close();
      }
      _clients.clear();
      
      // 关闭服务器
      await _server?.close();
      
      debugPrint('[MockSignalingServer] 服务器已停止');
    } catch (e) {
      debugPrint('[MockSignalingServer] 停止服务器失败: $e');
    }
  }
  
  /// 处理WebSocket连接
  Future<Response> _handleWebSocket(Request request) async {
    try {
      final userId = request.url.queryParameters['user_id'];
      if (userId == null) {
        return Response.forbidden('缺少用户ID');
      }
      
      debugPrint('[MockSignalingServer] 用户连接: $userId');
      
      // 创建WebSocket连接
      final controller = StreamController<String>();
      _clients[userId] = controller;
      
      // 返回WebSocket响应
      return Response.ok(
        controller.stream.map((message) => message),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[MockSignalingServer] 处理WebSocket连接失败: $e');
      return Response.internalServerError(body: 'WebSocket连接失败: $e');
    }
  }
  
  /// 处理发起通话请求
  Future<Response> _handleStartCall(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final fromId = data['from_id'];
      final toId = data['to_id'];
      final callType = data['type'];
      
      if (fromId == null || toId == null || callType == null) {
        return Response.badRequest(body: '缺少必要参数');
      }
      
      debugPrint('[MockSignalingServer] 发起通话: from=$fromId, to=$toId, type=$callType');
      
      // 生成通话ID
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      
      // 保存通话信息
      _calls[callId] = {
        'from': fromId,
        'to': toId,
        'type': callType,
        'status': 'pending',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };
      
      // 向接收者发送通话邀请
      _sendToClient(toId.toString(), {
        'type': 'call_invitation',
        'from': fromId,
        'call_type': callType,
        'call_id': callId,
      });
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'msg': '通话请求已发送',
          'data': {
            'call_id': callId,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[MockSignalingServer] 处理发起通话请求失败: $e');
      return Response.internalServerError(body: '发起通话失败: $e');
    }
  }
  
  /// 处理接听通话请求
  Future<Response> _handleAnswerCall(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final callId = data['call_id'];
      
      if (callId == null) {
        return Response.badRequest(body: '缺少通话ID');
      }
      
      debugPrint('[MockSignalingServer] 接听通话: callId=$callId');
      
      // 获取通话信息
      final call = _calls[callId];
      if (call == null) {
        return Response.notFound('通话不存在');
      }
      
      // 更新通话状态
      call['status'] = 'accepted';
      
      // 向发起者发送通话已接受消息
      _sendToClient(call['from'].toString(), {
        'type': 'call_accepted',
        'call_id': callId,
      });
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'msg': '通话已接听',
          'data': {
            'call_id': callId,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[MockSignalingServer] 处理接听通话请求失败: $e');
      return Response.internalServerError(body: '接听通话失败: $e');
    }
  }
  
  /// 处理拒绝通话请求
  Future<Response> _handleRejectCall(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final callId = data['call_id'];
      
      if (callId == null) {
        return Response.badRequest(body: '缺少通话ID');
      }
      
      debugPrint('[MockSignalingServer] 拒绝通话: callId=$callId');
      
      // 获取通话信息
      final call = _calls[callId];
      if (call == null) {
        return Response.notFound('通话不存在');
      }
      
      // 更新通话状态
      call['status'] = 'rejected';
      
      // 向发起者发送通话已拒绝消息
      _sendToClient(call['from'].toString(), {
        'type': 'call_rejected',
        'call_id': callId,
      });
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'msg': '通话已拒绝',
          'data': {
            'call_id': callId,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[MockSignalingServer] 处理拒绝通话请求失败: $e');
      return Response.internalServerError(body: '拒绝通话失败: $e');
    }
  }
  
  /// 处理结束通话请求
  Future<Response> _handleEndCall(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final callId = data['call_id'];
      
      if (callId == null) {
        return Response.badRequest(body: '缺少通话ID');
      }
      
      debugPrint('[MockSignalingServer] 结束通话: callId=$callId');
      
      // 获取通话信息
      final call = _calls[callId];
      if (call == null) {
        return Response.notFound('通话不存在');
      }
      
      // 更新通话状态
      call['status'] = 'ended';
      
      // 向双方发送通话已结束消息
      _sendToClient(call['from'].toString(), {
        'type': 'call_ended',
        'call_id': callId,
      });
      
      _sendToClient(call['to'].toString(), {
        'type': 'call_ended',
        'call_id': callId,
      });
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'msg': '通话已结束',
          'data': {
            'call_id': callId,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[MockSignalingServer] 处理结束通话请求失败: $e');
      return Response.internalServerError(body: '结束通话失败: $e');
    }
  }
  
  /// 向客户端发送消息
  void _sendToClient(String userId, Map<String, dynamic> message) {
    try {
      final client = _clients[userId];
      if (client != null) {
        client.add(jsonEncode(message));
        debugPrint('[MockSignalingServer] 向用户 $userId 发送消息: ${message['type']}');
      } else {
        debugPrint('[MockSignalingServer] 用户 $userId 不在线');
      }
    } catch (e) {
      debugPrint('[MockSignalingServer] 向客户端发送消息失败: $e');
    }
  }
}
