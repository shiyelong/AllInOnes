import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络监控器
/// 用于监控网络连接状态
class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;

  NetworkMonitor._internal();

  // 连接状态
  bool _isConnected = true;
  
  // 连接质量（0.0-1.0）
  double _quality = 1.0;
  
  // 连接类型
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  
  // 连接状态监听器
  final List<Function(bool)> _connectionListeners = [];
  
  // 连接质量监听器
  final List<Function(double)> _qualityListeners = [];
  
  // 连接类型监听器
  final List<Function(ConnectivityResult)> _typeListeners = [];
  
  // 连接状态订阅
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // 连接质量计时器
  Timer? _qualityTimer;
  
  // 获取连接状态
  bool get isConnected => _isConnected;
  
  // 获取连接质量
  double get quality => _quality;
  
  // 获取连接类型
  ConnectivityResult get connectivityResult => _connectivityResult;
  
  /// 初始化
  Future<void> initialize() async {
    try {
      // 获取当前连接状态
      _connectivityResult = await Connectivity().checkConnectivity();
      _isConnected = _connectivityResult != ConnectivityResult.none;
      
      // 监听连接状态变化
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectivity);
      
      // 启动连接质量监测
      _startQualityMonitor();
      
      debugPrint('[NetworkMonitor] 初始化成功，当前连接状态: $_isConnected, 连接类型: $_connectivityResult');
    } catch (e) {
      debugPrint('[NetworkMonitor] 初始化失败: $e');
    }
  }
  
  /// 更新连接状态
  void _updateConnectivity(ConnectivityResult result) {
    // 更新连接类型
    _connectivityResult = result;
    
    // 更新连接状态
    final isConnected = result != ConnectivityResult.none;
    
    // 如果连接状态发生变化，通知监听器
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      
      // 通知连接状态监听器
      _notifyConnectionListeners();
      
      debugPrint('[NetworkMonitor] 连接状态变化: $_isConnected, 连接类型: $_connectivityResult');
    }
    
    // 通知连接类型监听器
    _notifyTypeListeners();
  }
  
  /// 启动连接质量监测
  void _startQualityMonitor() {
    // 取消之前的计时器
    _qualityTimer?.cancel();
    
    // 启动计时器，每10秒检测一次连接质量
    _qualityTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      await _checkQuality();
    });
    
    // 立即检测一次连接质量
    _checkQuality();
  }
  
  /// 检测连接质量
  Future<void> _checkQuality() async {
    try {
      // 如果没有连接，则质量为0
      if (!_isConnected) {
        _updateQuality(0.0);
        return;
      }
      
      // 模拟连接质量检测
      // 实际应用中，可以通过ping、下载速度等方式检测
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      double quality;
      
      if (random < 10) {
        // 10%的概率为较差的连接
        quality = 0.3 + (random / 100);
      } else if (random < 30) {
        // 20%的概率为一般的连接
        quality = 0.6 + (random / 100);
      } else {
        // 70%的概率为良好的连接
        quality = 0.8 + (random / 500);
      }
      
      // 更新连接质量
      _updateQuality(quality);
    } catch (e) {
      debugPrint('[NetworkMonitor] 检测连接质量失败: $e');
    }
  }
  
  /// 更新连接质量
  void _updateQuality(double quality) {
    // 限制质量范围
    quality = quality.clamp(0.0, 1.0);
    
    // 如果质量变化超过0.1，通知监听器
    if ((_quality - quality).abs() > 0.1) {
      _quality = quality;
      
      // 通知连接质量监听器
      _notifyQualityListeners();
      
      debugPrint('[NetworkMonitor] 连接质量变化: $_quality');
    }
  }
  
  /// 添加连接状态监听器
  void addListener(Function(bool) listener) {
    if (!_connectionListeners.contains(listener)) {
      _connectionListeners.add(listener);
    }
  }
  
  /// 移除连接状态监听器
  void removeListener(Function(bool) listener) {
    _connectionListeners.remove(listener);
  }
  
  /// 添加连接质量监听器
  void addQualityListener(Function(double) listener) {
    if (!_qualityListeners.contains(listener)) {
      _qualityListeners.add(listener);
    }
  }
  
  /// 移除连接质量监听器
  void removeQualityListener(Function(double) listener) {
    _qualityListeners.remove(listener);
  }
  
  /// 添加连接类型监听器
  void addTypeListener(Function(ConnectivityResult) listener) {
    if (!_typeListeners.contains(listener)) {
      _typeListeners.add(listener);
    }
  }
  
  /// 移除连接类型监听器
  void removeTypeListener(Function(ConnectivityResult) listener) {
    _typeListeners.remove(listener);
  }
  
  /// 通知连接状态监听器
  void _notifyConnectionListeners() {
    for (var listener in _connectionListeners) {
      listener(_isConnected);
    }
  }
  
  /// 通知连接质量监听器
  void _notifyQualityListeners() {
    for (var listener in _qualityListeners) {
      listener(_quality);
    }
  }
  
  /// 通知连接类型监听器
  void _notifyTypeListeners() {
    for (var listener in _typeListeners) {
      listener(_connectivityResult);
    }
  }
  
  /// 释放资源
  void dispose() {
    // 取消连接状态订阅
    _connectivitySubscription?.cancel();
    
    // 取消连接质量计时器
    _qualityTimer?.cancel();
    
    // 清空监听器
    _connectionListeners.clear();
    _qualityListeners.clear();
    _typeListeners.clear();
    
    debugPrint('[NetworkMonitor] 资源已释放');
  }
}
