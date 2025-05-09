import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/message_queue_manager.dart';
import 'package:frontend/modules/social/chat/chat_service.dart';

/// 网络连接监控器
/// 用于监控网络连接状态，并在网络恢复时自动重试失败的消息
class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;

  NetworkMonitor._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isConnected = true;
  bool _hasRealConnection = true; // 是否有真实的网络连接（通过ping测试）
  Timer? _retryTimer;
  Timer? _pingTimer;
  bool _isRetrying = false;

  // 网络状态
  ConnectivityResult _lastConnectivityResult = ConnectivityResult.none;

  // 网络质量
  double _networkQuality = 1.0; // 0.0-1.0，1.0表示最佳
  int _pingFailCount = 0;

  // 网络状态变化监听器
  final List<Function(bool, double)> _listeners = []; // 参数：是否连接，网络质量

  /// 初始化网络监控
  void initialize() {
    _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    // 每30秒检查一次失败的消息，尝试重新发送
    _retryTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _retryFailedMessages();
    });

    // 每10秒进行一次网络质量检测
    _pingTimer = Timer.periodic(Duration(seconds: 10), (_) {
      _checkNetworkQuality();
    });

    // 初始化消息队列管理器
    MessageQueueManager().initialize();
  }

  /// 释放资源
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    _pingTimer?.cancel();
    _listeners.clear();
  }

  /// 获取当前网络状态
  ConnectivityResult get connectivityResult => _lastConnectivityResult;

  /// 获取当前网络质量
  double get networkQuality => _networkQuality;

  /// 检查当前网络连接状态
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);

      // 如果连接类型发生变化，立即检查网络质量
      if (result != _lastConnectivityResult) {
        _lastConnectivityResult = result;
        _checkNetworkQuality();
      }
    } catch (e) {
      debugPrint('[NetworkMonitor] 检查网络连接失败: $e');
      _isConnected = false;
      _hasRealConnection = false;
      _notifyListeners();
    }
  }

  /// 更新网络连接状态
  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    debugPrint('[NetworkMonitor] 网络状态变化: $result, 连接状态: $_isConnected');

    // 如果网络从断开变为连接，立即检查网络质量
    if (!wasConnected && _isConnected) {
      _checkNetworkQuality();
    }

    // 如果网络从断开变为连接，尝试重新发送失败的消息
    if (!wasConnected && _isConnected) {
      debugPrint('[NetworkMonitor] 网络已恢复，尝试重新发送失败的消息');
      _retryFailedMessages();
    }
  }

  /// 检查网络质量
  Future<void> _checkNetworkQuality() async {
    if (!_isConnected) {
      _hasRealConnection = false;
      _networkQuality = 0.0;
      _notifyListeners();
      return;
    }

    try {
      // 尝试ping几个常用的服务器
      final servers = [
        'www.baidu.com',
        'www.qq.com',
        'www.aliyun.com',
      ];

      int successCount = 0;
      int totalLatency = 0;

      for (var server in servers) {
        try {
          final startTime = DateTime.now().millisecondsSinceEpoch;
          final result = await InternetAddress.lookup(server);
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            final endTime = DateTime.now().millisecondsSinceEpoch;
            final latency = endTime - startTime;

            successCount++;
            totalLatency += latency;

            debugPrint('[NetworkMonitor] Ping $server 成功，延迟: $latency ms');
          }
        } catch (e) {
          debugPrint('[NetworkMonitor] Ping $server 失败: $e');
        }
      }

      // 更新网络状态
      final oldHasRealConnection = _hasRealConnection;
      _hasRealConnection = successCount > 0;

      // 计算网络质量
      if (successCount > 0) {
        final avgLatency = totalLatency / successCount;

        // 根据延迟计算网络质量，延迟越低，质量越高
        // 假设延迟在50ms以内为最佳，500ms以上为最差
        if (avgLatency <= 50) {
          _networkQuality = 1.0;
        } else if (avgLatency >= 500) {
          _networkQuality = 0.2;
        } else {
          _networkQuality = 1.0 - (avgLatency - 50) / 450 * 0.8;
        }

        _pingFailCount = 0;
      } else {
        // 所有ping都失败
        _pingFailCount++;

        // 如果连续多次ping失败，降低网络质量评分
        if (_pingFailCount >= 3) {
          _networkQuality = 0.0;
        } else {
          _networkQuality = 0.1;
        }
      }

      debugPrint('[NetworkMonitor] 网络质量检测结果: 成功率=${successCount / servers.length}, 质量评分=$_networkQuality');

      // 如果网络连接状态发生变化，通知监听器
      if (oldHasRealConnection != _hasRealConnection) {
        _notifyListeners();

        // 如果网络从断开变为连接，尝试重新发送失败的消息
        if (!oldHasRealConnection && _hasRealConnection) {
          debugPrint('[NetworkMonitor] 网络已恢复真实连接，尝试重新发送失败的消息');
          _retryFailedMessages();
        }
      }
    } catch (e) {
      debugPrint('[NetworkMonitor] 检查网络质量失败: $e');
      _hasRealConnection = false;
      _networkQuality = 0.0;
      _notifyListeners();
    }
  }

  /// 通知所有监听器
  void _notifyListeners() {
    for (var listener in _listeners) {
      listener(_hasRealConnection, _networkQuality);
    }
  }

  /// 添加网络状态变化监听器
  void addListener(Function(bool, double) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      // 立即通知新的监听器当前状态
      listener(_hasRealConnection, _networkQuality);
    }
  }

  /// 移除网络状态变化监听器
  void removeListener(Function(bool, double) listener) {
    _listeners.remove(listener);
  }

  /// 获取当前网络连接状态
  bool get isConnected => _hasRealConnection;

  /// 获取当前网络连接类型
  String get connectionType {
    switch (_lastConnectivityResult) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return '移动数据';
      case ConnectivityResult.ethernet:
        return '以太网';
      case ConnectivityResult.bluetooth:
        return '蓝牙';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return '其他';
      case ConnectivityResult.none:
      default:
        return '无连接';
    }
  }

  /// 重试发送失败的消息
  Future<void> _retryFailedMessages() async {
    // 如果没有真实的网络连接，不进行重试
    if (!_hasRealConnection || _isRetrying) return;

    _isRetrying = true;

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        _isRetrying = false;
        return;
      }

      final userId = userInfo.id;

      // 获取所有失败的消息
      final failedMessages = await LocalMessageStorage.getFailedMessages(userId);

      if (failedMessages.isEmpty) {
        _isRetrying = false;
        return;
      }

      debugPrint('[NetworkMonitor] 找到 ${failedMessages.length} 条失败的消息，准备重试');

      // 按聊天ID和群组ID分组
      final Map<int, List<Map<String, dynamic>>> singleChatMessages = {};
      final Map<int, List<Map<String, dynamic>>> groupChatMessages = {};

      for (var message in failedMessages) {
        if (message.containsKey('group_id') && message['group_id'] != null) {
          // 群聊消息
          final groupId = message['group_id'] as int;
          if (!groupChatMessages.containsKey(groupId)) {
            groupChatMessages[groupId] = [];
          }
          groupChatMessages[groupId]!.add(message);
        } else {
          // 单聊消息
          final chatId = message['to_id'] as int;
          if (!singleChatMessages.containsKey(chatId)) {
            singleChatMessages[chatId] = [];
          }
          singleChatMessages[chatId]!.add(message);
        }
      }

      // 重试单聊消息
      for (var entry in singleChatMessages.entries) {
        final chatId = entry.key;
        final messages = entry.value;

        for (var message in messages) {
          // 如果重试次数超过5次，不再重试
          final retryCount = message['retry_count'] ?? 0;
          if (retryCount >= 5) {
            debugPrint('[NetworkMonitor] 单聊消息重试次数已达上限，不再重试: ${message['content']}');
            continue;
          }

          debugPrint('[NetworkMonitor] 重试发送单聊消息: ${message['content']}');

          // 使用消息队列管理器添加消息
          await MessageQueueManager().addSingleChatMessage(
            chatId,
            message['content'] as String,
            type: message['type'] as String? ?? 'text',
          );
        }
      }

      // 重试群聊消息
      for (var entry in groupChatMessages.entries) {
        final groupId = entry.key;
        final messages = entry.value;

        for (var message in messages) {
          // 如果重试次数超过5次，不再重试
          final retryCount = message['retry_count'] ?? 0;
          if (retryCount >= 5) {
            debugPrint('[NetworkMonitor] 群聊消息重试次数已达上限，不再重试: ${message['content']}');
            continue;
          }

          debugPrint('[NetworkMonitor] 重试发送群聊消息: ${message['content']}');

          // 获取@用户列表
          List<String>? mentionedUsers;
          if (message.containsKey('mentioned_users') && message['mentioned_users'] != null) {
            if (message['mentioned_users'] is List) {
              mentionedUsers = (message['mentioned_users'] as List).map((e) => e.toString()).toList();
            } else if (message['mentioned_users'] is String) {
              mentionedUsers = (message['mentioned_users'] as String).split(',');
            }
          }

          // 使用消息队列管理器添加消息
          await MessageQueueManager().addGroupChatMessage(
            groupId,
            message['content'] as String,
            type: message['type'] as String? ?? 'text',
            mentionedUsers: mentionedUsers,
          );
        }
      }
    } catch (e) {
      debugPrint('[NetworkMonitor] 重试失败的消息时出错: $e');
    } finally {
      _isRetrying = false;
    }
  }

  /// 强制检查网络状态
  Future<void> forceCheckNetwork() async {
    await _checkConnectivity();
    await _checkNetworkQuality();
  }
}
