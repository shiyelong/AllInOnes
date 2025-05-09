import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'persistence.dart';
import 'websocket_message_handler.dart';
import 'network_monitor.dart';
import 'config.dart';

/// WebSocket管理器
/// 用于管理WebSocket连接
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;

  WebSocketManager._internal();

  // WebSocket通道
  WebSocketChannel? _channel;

  // 是否已连接
  bool _isConnected = false;

  // 是否正在重连
  bool _isReconnecting = false;

  // 重连计时器
  Timer? _reconnectTimer;

  // 心跳计时器
  Timer? _heartbeatTimer;

  // 重连次数
  int _reconnectCount = 0;

  // 最大重连次数
  final int _maxReconnectCount = 10;

  // 重连间隔（毫秒）
  final int _reconnectInterval = 5000;

  // 心跳间隔（毫秒）
  final int _heartbeatInterval = 30000;

  // 连接状态监听器
  final List<Function(bool)> _connectionListeners = [];

  // 消息监听器
  final List<Function(Map<String, dynamic>)> _messageListeners = [];

  // 获取连接状态
  bool get isConnected => _isConnected;

  /// 初始化WebSocket连接
  Future<void> initialize() async {
    // 如果已连接，则不重复连接
    if (_isConnected) {
      debugPrint('[WebSocketManager] WebSocket已连接，无需重复连接');
      return;
    }

    // 如果正在重连，则不重复连接
    if (_isReconnecting) {
      debugPrint('[WebSocketManager] WebSocket正在重连，无需重复连接');
      return;
    }

    // 连接WebSocket
    await _connect();

    // 监听网络状态变化
    NetworkMonitor().addListener(_onNetworkStatusChanged);
  }

  /// 连接WebSocket
  Future<void> _connect() async {
    try {
      // 获取Token
      final token = Persistence.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[WebSocketManager] Token为空，无法连接WebSocket');
        return;
      }

      // 获取用户ID
      final userId = Persistence.getUserId();
      if (userId == null || userId.isEmpty) {
        debugPrint('[WebSocketManager] 用户ID为空，无法连接WebSocket');
        return;
      }

      // 获取设备ID
      final deviceId = 'device-id-12345678';
      if (deviceId.isEmpty) {
        debugPrint('[WebSocketManager] 设备ID为空，无法连接WebSocket');
        return;
      }

      // 构建WebSocket URL
      final wsUrl = '${Config.wsUrl}?token=$token&user_id=$userId&device_id=device-id-12345678';

      // 连接WebSocket
      _channel = IOWebSocketChannel.connect(wsUrl);

      // 监听消息
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 更新连接状态
      _isConnected = true;
      _isReconnecting = false;
      _reconnectCount = 0;

      // 启动心跳
      _startHeartbeat();

      // 通知连接状态监听器
      _notifyConnectionListeners();

      debugPrint('[WebSocketManager] WebSocket连接成功');
    } catch (e) {
      debugPrint('[WebSocketManager] WebSocket连接失败: $e');

      // 更新连接状态
      _isConnected = false;

      // 通知连接状态监听器
      _notifyConnectionListeners();

      // 尝试重连
      _reconnect();
    }
  }

  /// 重连WebSocket
  void _reconnect() {
    // 如果已连接，则不重连
    if (_isConnected) {
      debugPrint('[WebSocketManager] WebSocket已连接，无需重连');
      return;
    }

    // 如果正在重连，则不重复重连
    if (_isReconnecting) {
      debugPrint('[WebSocketManager] WebSocket正在重连，无需重复重连');
      return;
    }

    // 如果重连次数超过最大重连次数，则不再重连
    if (_reconnectCount >= _maxReconnectCount) {
      debugPrint('[WebSocketManager] WebSocket重连次数超过最大重连次数，不再重连');
      return;
    }

    // 更新重连状态
    _isReconnecting = true;
    _reconnectCount++;

    // 通知连接状态监听器
    _notifyConnectionListeners();

    // 取消之前的重连计时器
    _reconnectTimer?.cancel();

    // 启动重连计时器
    _reconnectTimer = Timer(Duration(milliseconds: _reconnectInterval), () async {
      debugPrint('[WebSocketManager] 尝试重连WebSocket，第$_reconnectCount次');

      // 连接WebSocket
      await _connect();
    });
  }

  /// 启动心跳
  void _startHeartbeat() {
    // 取消之前的心跳计时器
    _heartbeatTimer?.cancel();

    // 启动心跳计时器
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: _heartbeatInterval), (timer) {
      // 发送心跳消息
      sendMessage({
        'type': 'heartbeat',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    // 取消心跳计时器
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 发送消息
  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      debugPrint('[WebSocketManager] WebSocket未连接，无法发送消息');
      return;
    }

    try {
      // 发送消息
      _channel!.sink.add(jsonEncode(message));

      debugPrint('[WebSocketManager] 发送消息: $message');
    } catch (e) {
      debugPrint('[WebSocketManager] 发送消息失败: $e');
    }
  }

  /// 关闭WebSocket连接
  void close() {
    // 停止心跳
    _stopHeartbeat();

    // 取消重连计时器
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 关闭WebSocket连接
    _channel?.sink.close();
    _channel = null;

    // 更新连接状态
    _isConnected = false;
    _isReconnecting = false;

    // 通知连接状态监听器
    _notifyConnectionListeners();

    // 移除网络状态监听器
    NetworkMonitor().removeListener(_onNetworkStatusChanged);

    debugPrint('[WebSocketManager] WebSocket连接已关闭');
  }

  /// 添加连接状态监听器
  void addConnectionListener(Function(bool) listener) {
    if (!_connectionListeners.contains(listener)) {
      _connectionListeners.add(listener);
    }
  }

  /// 移除连接状态监听器
  void removeConnectionListener(Function(bool) listener) {
    _connectionListeners.remove(listener);
  }

  /// 添加消息监听器
  void addMessageListener(Function(Map<String, dynamic>) listener) {
    if (!_messageListeners.contains(listener)) {
      _messageListeners.add(listener);
    }
  }

  /// 移除消息监听器
  void removeMessageListener(Function(Map<String, dynamic>) listener) {
    _messageListeners.remove(listener);
  }

  /// 通知连接状态监听器
  void _notifyConnectionListeners() {
    for (var listener in _connectionListeners) {
      listener(_isConnected);
    }
  }

  /// 通知消息监听器
  void _notifyMessageListeners(Map<String, dynamic> message) {
    for (var listener in _messageListeners) {
      listener(message);
    }
  }

  /// 消息回调
  void _onMessage(dynamic message) {
    try {
      // 解析消息
      final Map<String, dynamic> data = jsonDecode(message);

      debugPrint('[WebSocketManager] 收到消息: $data');

      // 处理消息
      WebSocketMessageHandler().handleMessage(data);

      // 通知消息监听器
      _notifyMessageListeners(data);
    } catch (e) {
      debugPrint('[WebSocketManager] 解析消息失败: $e');
    }
  }

  /// 错误回调
  void _onError(dynamic error) {
    debugPrint('[WebSocketManager] WebSocket错误: $error');

    // 更新连接状态
    _isConnected = false;

    // 通知连接状态监听器
    _notifyConnectionListeners();

    // 尝试重连
    _reconnect();
  }

  /// 关闭回调
  void _onDone() {
    debugPrint('[WebSocketManager] WebSocket连接已关闭');

    // 更新连接状态
    _isConnected = false;

    // 通知连接状态监听器
    _notifyConnectionListeners();

    // 尝试重连
    _reconnect();
  }

  /// 网络状态变化回调
  void _onNetworkStatusChanged(bool isConnected) {
    if (isConnected) {
      // 网络已连接，尝试重连WebSocket
      if (!_isConnected && !_isReconnecting) {
        debugPrint('[WebSocketManager] 网络已连接，尝试重连WebSocket');
        _reconnect();
      }
    } else {
      // 网络已断开，关闭WebSocket连接
      if (_isConnected) {
        debugPrint('[WebSocketManager] 网络已断开，关闭WebSocket连接');
        close();
      }
    }
  }

  /// 获取设备ID
  Future<String?> _getDeviceId() async {
    try {
      // 使用UUID生成一个随机设备ID
      const uuid = 'device-id-12345678';
      return uuid;
    } catch (e) {
      debugPrint('[WebSocketManager] 获取设备ID失败: $e');
      return null;
    }
  }
}
