import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/common/api.dart';

/// 语音播放器
/// 用于播放语音消息
class VoicePlayer {
  static final VoicePlayer _instance = VoicePlayer._internal();
  factory VoicePlayer() => _instance;

  VoicePlayer._internal();

  // 音频播放器
  final _audioPlayer = AudioPlayer();
  
  // 当前播放的消息ID
  String? _currentMessageId;
  
  // 当前播放的文件路径
  String? _currentFilePath;
  
  // 播放状态
  bool _isPlaying = false;
  
  // 播放进度（秒）
  double _playProgress = 0;
  
  // 播放总时长（秒）
  double _playDuration = 0;
  
  // 播放状态监听器
  final List<Function(bool, double, double, String?)> _playingListeners = [];
  
  // 播放进度监听器
  StreamSubscription<Duration>? _positionSubscription;
  
  // 播放完成监听器
  StreamSubscription<void>? _completionSubscription;
  
  // 获取播放状态
  bool get isPlaying => _isPlaying;
  
  // 获取播放进度
  double get playProgress => _playProgress;
  
  // 获取播放总时长
  double get playDuration => _playDuration;
  
  // 获取当前播放的消息ID
  String? get currentMessageId => _currentMessageId;
  
  /// 初始化
  Future<void> initialize() async {
    // 监听播放进度
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      _playProgress = position.inMilliseconds / 1000;
      _notifyPlayingListeners();
    });
    
    // 监听播放完成
    _completionSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _playProgress = 0;
      _notifyPlayingListeners();
    });
  }
  
  /// 播放语音消息
  Future<bool> playVoiceMessage(String messageId, String filePath, {int duration = 0}) async {
    if (_isPlaying) {
      // 如果正在播放同一条消息，则停止播放
      if (_currentMessageId == messageId) {
        await stopPlaying();
        return false;
      }
      
      // 如果正在播放其他消息，先停止播放
      await stopPlaying();
    }
    
    try {
      // 检查文件是否存在
      final file = File(filePath);
      if (await file.exists()) {
        // 本地文件存在，直接播放
        await _audioPlayer.play(DeviceFileSource(filePath));
        
        // 更新状态
        _isPlaying = true;
        _currentMessageId = messageId;
        _currentFilePath = filePath;
        _playProgress = 0;
        _playDuration = duration > 0 ? duration.toDouble() : 0;
        
        // 通知监听器
        _notifyPlayingListeners();
        
        debugPrint('[VoicePlayer] 开始播放本地语音消息: $filePath, 消息ID: $messageId');
        return true;
      } else {
        // 本地文件不存在，尝试从服务器下载
        debugPrint('[VoicePlayer] 本地语音文件不存在，尝试从服务器下载: $messageId');
        
        // 获取语音消息
        final response = await Api.getVoiceMessage(messageId: messageId);
        
        if (response['success'] == true && response['data'] != null) {
          final voiceUrl = response['data']['url'];
          final voiceDuration = response['data']['duration'] ?? 0;
          
          if (voiceUrl != null && voiceUrl.isNotEmpty) {
            // 下载语音文件
            final downloadedPath = await _downloadVoiceFile(voiceUrl, messageId);
            
            if (downloadedPath.isNotEmpty) {
              // 播放下载的文件
              await _audioPlayer.play(DeviceFileSource(downloadedPath));
              
              // 更新状态
              _isPlaying = true;
              _currentMessageId = messageId;
              _currentFilePath = downloadedPath;
              _playProgress = 0;
              _playDuration = voiceDuration > 0 ? voiceDuration.toDouble() : 0;
              
              // 通知监听器
              _notifyPlayingListeners();
              
              debugPrint('[VoicePlayer] 开始播放下载的语音消息: $downloadedPath, 消息ID: $messageId');
              return true;
            }
          }
        }
        
        debugPrint('[VoicePlayer] 无法获取语音消息: $messageId');
        return false;
      }
    } catch (e) {
      debugPrint('[VoicePlayer] 播放语音消息失败: $e');
      return false;
    }
  }
  
  /// 停止播放
  Future<void> stopPlaying() async {
    if (!_isPlaying) return;
    
    try {
      await _audioPlayer.stop();
      
      // 更新状态
      _isPlaying = false;
      _playProgress = 0;
      
      // 通知监听器
      _notifyPlayingListeners();
      
      debugPrint('[VoicePlayer] 停止播放语音消息');
    } catch (e) {
      debugPrint('[VoicePlayer] 停止播放语音消息失败: $e');
    }
  }
  
  /// 暂停播放
  Future<void> pausePlaying() async {
    if (!_isPlaying) return;
    
    try {
      await _audioPlayer.pause();
      
      // 更新状态
      _isPlaying = false;
      
      // 通知监听器
      _notifyPlayingListeners();
      
      debugPrint('[VoicePlayer] 暂停播放语音消息');
    } catch (e) {
      debugPrint('[VoicePlayer] 暂停播放语音消息失败: $e');
    }
  }
  
  /// 恢复播放
  Future<void> resumePlaying() async {
    if (_isPlaying) return;
    
    try {
      await _audioPlayer.resume();
      
      // 更新状态
      _isPlaying = true;
      
      // 通知监听器
      _notifyPlayingListeners();
      
      debugPrint('[VoicePlayer] 恢复播放语音消息');
    } catch (e) {
      debugPrint('[VoicePlayer] 恢复播放语音消息失败: $e');
    }
  }
  
  /// 下载语音文件
  Future<String> _downloadVoiceFile(String url, String messageId) async {
    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_$messageId.m4a';
      
      // 检查文件是否已存在
      final file = File(filePath);
      if (await file.exists()) {
        debugPrint('[VoicePlayer] 语音文件已存在: $filePath');
        return filePath;
      }
      
      // 下载文件
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // 保存文件
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('[VoicePlayer] 语音文件下载成功: $filePath');
        return filePath;
      } else {
        debugPrint('[VoicePlayer] 语音文件下载失败: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      debugPrint('[VoicePlayer] 下载语音文件失败: $e');
      return '';
    }
  }
  
  /// 添加播放状态监听器
  void addPlayingListener(Function(bool, double, double, String?) listener) {
    if (!_playingListeners.contains(listener)) {
      _playingListeners.add(listener);
    }
  }
  
  /// 移除播放状态监听器
  void removePlayingListener(Function(bool, double, double, String?) listener) {
    _playingListeners.remove(listener);
  }
  
  /// 通知播放状态监听器
  void _notifyPlayingListeners() {
    for (var listener in _playingListeners) {
      listener(_isPlaying, _playProgress, _playDuration, _currentMessageId);
    }
  }
  
  /// 释放资源
  void dispose() {
    _positionSubscription?.cancel();
    _completionSubscription?.cancel();
    _audioPlayer.dispose();
    _playingListeners.clear();
    _isPlaying = false;
    _playProgress = 0;
    _playDuration = 0;
    _currentMessageId = null;
    _currentFilePath = null;
  }
}
