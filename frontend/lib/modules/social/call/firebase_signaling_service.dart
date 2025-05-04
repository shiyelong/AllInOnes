import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Firebase信令服务
/// 用于处理WebRTC信令
class FirebaseSignalingService {
  // 单例模式
  static final FirebaseSignalingService _instance = FirebaseSignalingService._internal();
  factory FirebaseSignalingService() => _instance;
  FirebaseSignalingService._internal();
  
  // Firebase实例
  late FirebaseDatabase _database;
  
  // 用户ID
  String? _userId;
  
  // 回调函数
  Function(Map<String, dynamic>)? onSignalReceived;
  Function(Map<String, dynamic>)? onCallInvitation;
  Function(Map<String, dynamic>)? onCallAccepted;
  Function(Map<String, dynamic>)? onCallRejected;
  Function(Map<String, dynamic>)? onCallEnded;
  
  // 订阅
  StreamSubscription? _signalSubscription;
  StreamSubscription? _callSubscription;
  
  /// 初始化Firebase
  Future<void> initialize() async {
    try {
      // 初始化Firebase
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDZvZ5LqRqcaIw_TFMtlZBgfZfAUWzYQ8E",
          authDomain: "allinone-webrtc.firebaseapp.com",
          databaseURL: "https://allinone-webrtc-default-rtdb.firebaseio.com",
          projectId: "allinone-webrtc",
          storageBucket: "allinone-webrtc.appspot.com",
          messagingSenderId: "123456789012",
          appId: "1:123456789012:web:1234567890abcdef",
        ),
      );
      
      // 获取数据库实例
      _database = FirebaseDatabase.instance;
      
      debugPrint('[FirebaseSignalingService] 初始化成功');
    } catch (e) {
      debugPrint('[FirebaseSignalingService] 初始化失败: $e');
      rethrow;
    }
  }
  
  /// 设置用户ID
  void setUserId(String userId) {
    _userId = userId;
    
    // 监听信令消息
    _listenForSignals();
    
    // 监听通话消息
    _listenForCalls();
    
    debugPrint('[FirebaseSignalingService] 设置用户ID: $_userId');
  }
  
  /// 监听信令消息
  void _listenForSignals() {
    if (_userId == null) return;
    
    // 取消之前的订阅
    _signalSubscription?.cancel();
    
    // 监听信令消息
    final signalRef = _database.ref('signals/$_userId');
    _signalSubscription = signalRef.onChildAdded.listen((event) {
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final signalData = Map<String, dynamic>.from(data);
        
        debugPrint('[FirebaseSignalingService] 收到信令消息: ${signalData['type']}');
        
        if (onSignalReceived != null) {
          onSignalReceived!(signalData);
        }
        
        // 删除已处理的消息
        event.snapshot.ref.remove();
      } catch (e) {
        debugPrint('[FirebaseSignalingService] 处理信令消息失败: $e');
      }
    });
  }
  
  /// 监听通话消息
  void _listenForCalls() {
    if (_userId == null) return;
    
    // 取消之前的订阅
    _callSubscription?.cancel();
    
    // 监听通话消息
    final callRef = _database.ref('calls/$_userId');
    _callSubscription = callRef.onChildAdded.listen((event) {
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final callData = Map<String, dynamic>.from(data);
        
        debugPrint('[FirebaseSignalingService] 收到通话消息: ${callData['type']}');
        
        switch (callData['type']) {
          case 'invitation':
            if (onCallInvitation != null) {
              onCallInvitation!(callData);
            }
            break;
          case 'accepted':
            if (onCallAccepted != null) {
              onCallAccepted!(callData);
            }
            break;
          case 'rejected':
            if (onCallRejected != null) {
              onCallRejected!(callData);
            }
            break;
          case 'ended':
            if (onCallEnded != null) {
              onCallEnded!(callData);
            }
            break;
        }
        
        // 删除已处理的消息
        event.snapshot.ref.remove();
      } catch (e) {
        debugPrint('[FirebaseSignalingService] 处理通话消息失败: $e');
      }
    });
  }
  
  /// 发送信令消息
  Future<void> sendSignal({
    required String toUserId,
    required String type,
    required String signal,
    required String callType,
  }) async {
    if (_userId == null) return;
    
    try {
      final signalRef = _database.ref('signals/$toUserId').push();
      
      await signalRef.set({
        'from': _userId,
        'type': type,
        'signal': signal,
        'call_type': callType,
        'timestamp': ServerValue.timestamp,
      });
      
      debugPrint('[FirebaseSignalingService] 发送信令消息: to=$toUserId, type=$type');
    } catch (e) {
      debugPrint('[FirebaseSignalingService] 发送信令消息失败: $e');
      rethrow;
    }
  }
  
  /// 发起通话
  Future<String> startCall({
    required String toUserId,
    required String callType,
  }) async {
    if (_userId == null) {
      throw Exception('用户ID未设置');
    }
    
    try {
      // 生成通话ID
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      
      // 保存通话信息
      final callRef = _database.ref('calls/$toUserId').push();
      
      await callRef.set({
        'type': 'invitation',
        'from_id': _userId,
        'call_type': callType,
        'call_id': callId,
        'timestamp': ServerValue.timestamp,
      });
      
      debugPrint('[FirebaseSignalingService] 发起通话: to=$toUserId, type=$callType, callId=$callId');
      
      return callId;
    } catch (e) {
      debugPrint('[FirebaseSignalingService] 发起通话失败: $e');
      rethrow;
    }
  }
  
  /// 接受通话
  Future<void> acceptCall({
    required String callId,
    required String fromUserId,
  }) async {
    if (_userId == null) return;
    
    try {
      final callRef = _database.ref('calls/$fromUserId').push();
      
      await callRef.set({
        'type': 'accepted',
        'from_id': _userId,
        'call_id': callId,
        'timestamp': ServerValue.timestamp,
      });
      
      debugPrint('[FirebaseSignalingService] 接受通话: callId=$callId, from=$fromUserId');
    } catch (e) {
      debugPrint('[FirebaseSignalingService] 接受通话失败: $e');
      rethrow;
    }
  }
  
  /// 拒绝通话
  Future<void> rejectCall({
    required String callId,
    required String fromUserId,
  }) async {
    if (_userId == null) return;
    
    try {
      final callRef = _database.ref('calls/$fromUserId').push();
      
      await callRef.set({
        'type': 'rejected',
        'from_id': _userId,
        'call_id': callId,
        'timestamp': ServerValue.timestamp,
      });
      
      debugPrint('[FirebaseSignalingService] 拒绝通话: callId=$callId, from=$fromUserId');
    } catch (e) {
      debugPrint('[FirebaseSignalingService] 拒绝通话失败: $e');
      rethrow;
    }
  }
  
  /// 结束通话
  Future<void> endCall({
    required String callId,
    required String toUserId,
  }) async {
    if (_userId == null) return;
    
    try {
      final callRef = _database.ref('calls/$toUserId').push();
      
      await callRef.set({
        'type': 'ended',
        'from_id': _userId,
        'call_id': callId,
        'timestamp': ServerValue.timestamp,
      });
      
      debugPrint('[FirebaseSignalingService] 结束通话: callId=$callId, to=$toUserId');
    } catch (e) {
      debugPrint('[FirebaseSignalingService] 结束通话失败: $e');
      rethrow;
    }
  }
  
  /// 清理资源
  void dispose() {
    _signalSubscription?.cancel();
    _callSubscription?.cancel();
  }
}
