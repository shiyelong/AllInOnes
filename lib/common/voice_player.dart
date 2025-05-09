import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'api.dart';

/// 语音播放器
/// 用于播放语音消息
class VoicePlayer {
  static final VoicePlayer _instance = VoicePlayer._internal();
  factory VoicePlayer() => _instance;

  VoicePlayer._internal();

  // 播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 当前播放的消息ID
  String? _currentMessageId;
  
  // 当前播放的文件路径
  String? _currentFilePath;
  
  // 当前播放的总时长（毫秒）
  int _totalDuration = 0;
  
  // 当前播放的位置（毫秒）
  int _currentPosition = 0;
  
  // 是否正在播放
  bool _isPlaying = false;
  
  // 是否暂停
  bool _isPaused = false;
  
  // 播放状态监听器
  final List<Function(String, bool, bool, double, int)> _playStateListeners = [];
  
  // 播放进度计时器
  Timer? _progressTimer;
  
  // 获取当前播放状态
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  String? get currentMessageId => _currentMessageId;
  String? get currentFilePath => _currentFilePath;
  int get totalDuration => _totalDuration;
  int get currentPosition => _currentPosition;
  
  /// 初始化
  Future<void> init() async {
    // 监听播放状态变化
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _isPlaying = true;
        _isPaused = false;
        _startProgressTimer();
      } else if (state == PlayerState.paused) {
        _isPlaying = true;
        _isPaused = true;
        _stopProgressTimer();
      } else if (state == PlayerState.completed) {
        _isPlaying = false;
        _isPaused = false;
        _currentPosition = _totalDuration;
        _stopProgressTimer();
        _notifyPlayStateListeners();
      } else {
        _isPlaying = false;
        _isPaused = false;
        _stopProgressTimer();
      }
      
      _notifyPlayStateListeners();
    });
    
    // 监听播放完成
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _isPaused = false;
      _currentPosition = _totalDuration;
      _stopProgressTimer();
      _notifyPlayStateListeners();
    });
    
    // 监听播放位置变化
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position.inMilliseconds;
      _notifyPlayStateListeners();
    });
    
    // 监听播放时长变化
    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration.inMilliseconds;
      _notifyPlayStateListeners();
    });
  }
  
  /// 播放语音消息
  Future<bool> play({
    required String messageId,
    required String filePath,
    required int duration,
    String? serverUrl,
  }) async {
    try {
      // 如果正在播放同一个消息，则暂停/恢复播放
      if (_currentMessageId == messageId && _isPlaying) {
        if (_isPaused) {
          return await resume(messageId);
        } else {
          return await pause(messageId);
        }
      }
      
      // 停止当前播放
      await stop();
      
      // 更新当前播放信息
      _currentMessageId = messageId;
      _currentFilePath = filePath;
      _totalDuration = duration * 1000; // 转换为毫秒
      _currentPosition = 0;
      
      // 检查文件是否存在
      final file = File(filePath);
      if (await file.exists()) {
        // 播放本地文件
        await _audioPlayer.play(DeviceFileSource(filePath));
      } else if (serverUrl != null) {
        // 播放服务器文件
        await _audioPlayer.play(UrlSource(serverUrl));
      } else {
        // 尝试从服务器获取文件
        try {
          final response = await Api.getVoiceMessage(messageId: messageId);
          
          if (response['success'] == true) {
            final url = response['data']?['url'];
            if (url != null) {
              await _audioPlayer.play(UrlSource(url));
            } else {
              debugPrint('[VoicePlayer] 获取语音消息URL失败');
              return false;
            }
          } else {
            debugPrint('[VoicePlayer] 获取语音消息失败: ${response['msg']}');
            return false;
          }
        } catch (e) {
          debugPrint('[VoicePlayer] 获取语音消息异常: $e');
          return false;
        }
      }
      
      _isPlaying = true;
      _isPaused = false;
      _startProgressTimer();
      _notifyPlayStateListeners();
      
      return true;
    } catch (e) {
      debugPrint('[VoicePlayer] 播放语音消息异常: $e');
      return false;
    }
  }
  
  /// 暂停播放
  Future<bool> pause(String messageId) async {
    if (_currentMessageId != messageId || !_isPlaying || _isPaused) {
      return false;
    }
    
    try {
      await _audioPlayer.pause();
      _isPaused = true;
      _stopProgressTimer();
      _notifyPlayStateListeners();
      return true;
    } catch (e) {
      debugPrint('[VoicePlayer] 暂停播放异常: $e');
      return false;
    }
  }
  
  /// 恢复播放
  Future<bool> resume(String messageId) async {
    if (_currentMessageId != messageId || !_isPlaying || !_isPaused) {
      return false;
    }
    
    try {
      await _audioPlayer.resume();
      _isPaused = false;
      _startProgressTimer();
      _notifyPlayStateListeners();
      return true;
    } catch (e) {
      debugPrint('[VoicePlayer] 恢复播放异常: $e');
      return false;
    }
  }
  
  /// 停止播放
  Future<bool> stop() async {
    if (!_isPlaying) {
      return true;
    }
    
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _isPaused = false;
      _currentMessageId = null;
      _currentFilePath = null;
      _totalDuration = 0;
      _currentPosition = 0;
      _stopProgressTimer();
      _notifyPlayStateListeners();
      return true;
    } catch (e) {
      debugPrint('[VoicePlayer] 停止播放异常: $e');
      return false;
    }
  }
  
  /// 跳转到指定位置
  Future<bool> seekTo(String messageId, int position) async {
    if (_currentMessageId != messageId || !_isPlaying) {
      return false;
    }
    
    try {
      await _audioPlayer.seek(Duration(milliseconds: position));
      _currentPosition = position;
      _notifyPlayStateListeners();
      return true;
    } catch (e) {
      debugPrint('[VoicePlayer] 跳转播放位置异常: $e');
      return false;
    }
  }
  
  /// 添加播放状态监听器
  void addListener(Function(String, bool, bool, double, int) listener) {
    if (!_playStateListeners.contains(listener)) {
      _playStateListeners.add(listener);
    }
  }
  
  /// 移除播放状态监听器
  void removeListener(Function(String, bool, bool, double, int) listener) {
    _playStateListeners.remove(listener);
  }
  
  /// 通知播放状态监听器
  void _notifyPlayStateListeners() {
    if (_currentMessageId == null) return;
    
    final progress = _totalDuration > 0 ? _currentPosition / _totalDuration : 0.0;
    
    for (var listener in _playStateListeners) {
      listener(_currentMessageId!, _isPlaying, _isPaused, progress, _currentPosition);
    }
  }
  
  /// 启动进度计时器
  void _startProgressTimer() {
    _stopProgressTimer();
    
    _progressTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _notifyPlayStateListeners();
    });
  }
  
  /// 停止进度计时器
  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
  
  /// 释放资源
  void dispose() {
    _stopProgressTimer();
    _audioPlayer.dispose();
    _playStateListeners.clear();
    _isPlaying = false;
    _isPaused = false;
    _currentMessageId = null;
    _currentFilePath = null;
    _totalDuration = 0;
    _currentPosition = 0;
  }
}
