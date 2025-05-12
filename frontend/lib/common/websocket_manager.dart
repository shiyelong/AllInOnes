import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/network_monitor.dart';

/// WebSocket连接管理器
/// 用于管理与后端的WebSocket连接，实现实时消息推送
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;

  WebSocketManager._internal();

  // WebSocket连接
  WebSocketChannel? _channel;

  // 连接状态
  bool _isConnected = false;
  bool _isConnecting = false;

  // 重连计数器
  int _reconnectAttempts = 0;

  // 最大重连次数
  static const int maxReconnectAttempts = 10;

  // 重连间隔（毫秒）
  static const List<int> reconnectIntervals = [1000, 2000, 5000, 10000, 30000]; // 递增的重连间隔

  // 消息监听器
  final Map<String, List<Function(Map<String, dynamic>)>> _messageListeners = {};

  // 连接状态监听器
  final List<Function(bool)> _connectionListeners = [];

  // 心跳定时器
  Timer? _heartbeatTimer;

  // 重连定时器
  Timer? _reconnectTimer;

  /// 初始化WebSocket连接
  Future<bool> initialize() async {
    if (_isConnected || _isConnecting) return _isConnected;

    _isConnecting = true;

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        debugPrint('[WebSocketManager] 用户未登录，无法初始化WebSocket连接');
        _isConnecting = false;
        return false;
      }

      // 使用固定的WebSocket URL，避免API调用失败
      final wsUrl = 'ws://localhost:3001/ws';
      final token = Persistence.getToken();

      if (token == null) {
        debugPrint('[WebSocketManager] Token为空，无法建立WebSocket连接');
        _isConnecting = false;
        return false;
      }

      // 创建WebSocket连接
      final fullUrl = '$wsUrl?token=$token&user_id=${userInfo.id}';
      debugPrint('[WebSocketManager] 正在连接WebSocket: $fullUrl');

      _channel = IOWebSocketChannel.connect(
        Uri.parse(fullUrl),
        pingInterval: Duration(seconds: 30),
      );

      // 监听消息
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 发送连接消息
      _sendMessage({
        'type': 'connect',
        'data': {
          'user_id': userInfo.id,
          'device_id': await _getDeviceId(),
          'platform': 'flutter',
        },
      });

      // 启动心跳
      _startHeartbeat();

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      // 通知连接状态监听器
      _notifyConnectionListeners();

      debugPrint('[WebSocketManager] WebSocket连接成功');
      return true;
    } catch (e) {
      debugPrint('[WebSocketManager] WebSocket连接失败: $e');
      _isConnected = false;
      _isConnecting = false;

      // 尝试重连
      _scheduleReconnect();

      return false;
    }
  }

  /// 关闭WebSocket连接
  void close() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }

    _isConnected = false;
    _isConnecting = false;

    // 通知连接状态监听器
    _notifyConnectionListeners();

    debugPrint('[WebSocketManager] WebSocket连接已关闭');
  }

  /// 发送消息
  bool sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      debugPrint('[WebSocketManager] WebSocket未连接，无法发送消息');
      return false;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      debugPrint('[WebSocketManager] 发送消息失败: $e');
      return false;
    }
  }

  /// 发送消息（内部方法）
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null) return;

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[WebSocketManager] 发送消息失败: $e');
    }
  }

  /// 接收消息
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      debugPrint('[WebSocketManager] 收到消息: $type');

      // 处理心跳响应
      if (type == 'pong') {
        return;
      }

      // 通知消息监听器
      if (_messageListeners.containsKey(type)) {
        for (var listener in _messageListeners[type]!) {
          listener(data);
        }
      }

      // 通知通用消息监听器
      if (_messageListeners.containsKey('*')) {
        for (var listener in _messageListeners['*']!) {
          listener(data);
        }
      }
    } catch (e) {
      debugPrint('[WebSocketManager] 处理消息失败: $e');
    }
  }

  /// 连接错误
  void _onError(error) {
    debugPrint('[WebSocketManager] WebSocket连接错误: $error');
    _isConnected = false;

    // 通知连接状态监听器
    _notifyConnectionListeners();

    // 尝试重连
    _scheduleReconnect();
  }

  /// 连接关闭
  void _onDone() {
    debugPrint('[WebSocketManager] WebSocket连接关闭');
    _isConnected = false;

    // 通知连接状态监听器
    _notifyConnectionListeners();

    // 尝试重连
    _scheduleReconnect();
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        _sendMessage({
          'type': 'ping',
          'data': {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        });
      }
    });
  }

  /// 安排重连
  void _scheduleReconnect() {
    // 如果已经在重连，不再安排新的重连
    if (_isConnecting || _reconnectTimer != null) return;

    // 如果超过最大重连次数，不再重连
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('[WebSocketManager] 已达到最大重连次数，不再重连');
      return;
    }

    // 计算重连间隔
    final intervalIndex = _reconnectAttempts < reconnectIntervals.length
        ? _reconnectAttempts
        : reconnectIntervals.length - 1;
    final interval = reconnectIntervals[intervalIndex];

    debugPrint('[WebSocketManager] 将在 $interval 毫秒后尝试重连，重连次数: ${_reconnectAttempts + 1}');

    _reconnectTimer = Timer(Duration(milliseconds: interval), () {
      _reconnectTimer = null;
      _reconnectAttempts++;
      initialize();
    });
  }

  /// 添加消息监听器
  void addMessageListener(String type, Function(Map<String, dynamic>) listener) {
    if (!_messageListeners.containsKey(type)) {
      _messageListeners[type] = [];
    }

    if (!_messageListeners[type]!.contains(listener)) {
      _messageListeners[type]!.add(listener);
    }
  }

  /// 移除消息监听器
  void removeMessageListener(String type, Function(Map<String, dynamic>) listener) {
    if (_messageListeners.containsKey(type)) {
      _messageListeners[type]!.remove(listener);

      if (_messageListeners[type]!.isEmpty) {
        _messageListeners.remove(type);
      }
    }
  }

  /// 添加连接状态监听器
  void addConnectionListener(Function(bool) listener) {
    if (!_connectionListeners.contains(listener)) {
      _connectionListeners.add(listener);

      // 立即通知当前状态
      listener(_isConnected);
    }
  }

  /// 移除连接状态监听器
  void removeConnectionListener(Function(bool) listener) {
    _connectionListeners.remove(listener);
  }

  /// 通知连接状态监听器
  void _notifyConnectionListeners() {
    for (var listener in _connectionListeners) {
      listener(_isConnected);
    }
  }

  /// 获取连接状态
  bool get isConnected => _isConnected;

  /// 获取设备ID
  Future<String> _getDeviceId() async {
    // 在实际应用中，应该使用设备信息库获取真实的设备ID
    // 这里使用一个固定的ID作为示例
    return 'flutter-device-${DateTime.now().millisecondsSinceEpoch}';
  }
}
