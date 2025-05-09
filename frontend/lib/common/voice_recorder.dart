import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// 自定义录音器类，避免使用抽象类 Record
class AudioRecorder {
  Future<bool> isRecording() async {
    return false;
  }

  Future<void> start({
    required String path,
    AudioEncoder encoder = AudioEncoder.aacLc,
    int bitRate = 128000,
    int samplingRate = 44100,
  }) async {
    // 模拟录音功能
    debugPrint('[AudioRecorder] 开始录音: $path');
  }

  Future<String?> stop() async {
    // 模拟停止录音
    debugPrint('[AudioRecorder] 停止录音');
    return null;
  }

  void dispose() {
    // 释放资源
    debugPrint('[AudioRecorder] 释放资源');
  }
}

// 音频编码器枚举
enum AudioEncoder {
  aacLc,
  aacEld,
  aacHe,
  amrNb,
  amrWb,
  opus,
  flac,
  pcm16bits,
  wav,
}

/// 语音录制器
/// 用于录制语音消息
class VoiceRecorder {
  static final VoiceRecorder _instance = VoiceRecorder._internal();
  factory VoiceRecorder() => _instance;

  VoiceRecorder._internal();

  // 录音器
  final _audioRecorder = AudioRecorder();

  // 录音状态
  bool _isRecording = false;

  // 录音开始时间
  DateTime? _recordStartTime;

  // 录音计时器
  Timer? _recordTimer;

  // 录音时长（秒）
  int _recordDuration = 0;

  // 录音路径
  String _recordPath = '';

  // 录音状态监听器
  final List<Function(bool, int)> _recordingListeners = [];

  // 获取录音状态
  bool get isRecording => _isRecording;

  // 获取录音时长
  int get recordDuration => _recordDuration;

  // 获取录音路径
  String get recordPath => _recordPath;

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[VoiceRecorder] 请求麦克风权限失败: $e');
      return false;
    }
  }

  /// 开始录音
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('[VoiceRecorder] 已经在录音中');
      return false;
    }

    // 请求麦克风权限
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[VoiceRecorder] 没有麦克风权限');
      return false;
    }

    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordPath = '${tempDir.path}/voice_$timestamp.m4a';

      // 开始录音
      await _audioRecorder.start(
        path: _recordPath,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );

      // 更新状态
      _isRecording = true;
      _recordStartTime = DateTime.now();
      _recordDuration = 0;

      // 启动计时器
      _recordTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_recordStartTime != null) {
          final now = DateTime.now();
          final duration = now.difference(_recordStartTime!);
          _recordDuration = duration.inSeconds;

          // 通知监听器
          _notifyRecordingListeners();

          // 最大录音时长为60秒
          if (_recordDuration >= 60) {
            stopRecording();
          }
        }
      });

      // 通知监听器
      _notifyRecordingListeners();

      debugPrint('[VoiceRecorder] 开始录音: $_recordPath');
      return true;
    } catch (e) {
      debugPrint('[VoiceRecorder] 开始录音失败: $e');
      return false;
    }
  }

  /// 停止录音
  Future<Map<String, dynamic>> stopRecording() async {
    if (!_isRecording) {
      debugPrint('[VoiceRecorder] 没有正在进行的录音');
      return {'success': false, 'msg': '没有正在进行的录音'};
    }

    try {
      // 停止计时器
      _recordTimer?.cancel();
      _recordTimer = null;

      // 停止录音
      final result = await _audioRecorder.stop();

      // 更新状态
      _isRecording = false;
      final duration = _recordDuration;
      _recordDuration = 0;
      _recordStartTime = null;

      // 通知监听器
      _notifyRecordingListeners();

      if (result == null) {
        debugPrint('[VoiceRecorder] 录音失败');
        return {'success': false, 'msg': '录音失败'};
      }

      // 检查文件是否存在
      final file = File(result);
      if (!await file.exists()) {
        debugPrint('[VoiceRecorder] 录音文件不存在: $result');
        return {'success': false, 'msg': '录音文件不存在'};
      }

      // 检查文件大小
      final fileSize = await file.length();
      if (fileSize <= 0) {
        debugPrint('[VoiceRecorder] 录音文件为空: $result');
        return {'success': false, 'msg': '录音文件为空'};
      }

      debugPrint('[VoiceRecorder] 停止录音: $result, 时长: $duration 秒, 大小: $fileSize 字节');
      return {
        'success': true,
        'path': result,
        'duration': duration,
        'size': fileSize,
      };
    } catch (e) {
      debugPrint('[VoiceRecorder] 停止录音失败: $e');

      // 更新状态
      _isRecording = false;
      _recordDuration = 0;
      _recordStartTime = null;

      // 通知监听器
      _notifyRecordingListeners();

      return {'success': false, 'msg': '停止录音失败: $e'};
    }
  }

  /// 取消录音
  Future<bool> cancelRecording() async {
    if (!_isRecording) {
      debugPrint('[VoiceRecorder] 没有正在进行的录音');
      return false;
    }

    try {
      // 停止计时器
      _recordTimer?.cancel();
      _recordTimer = null;

      // 停止录音
      await _audioRecorder.stop();

      // 更新状态
      _isRecording = false;
      _recordDuration = 0;
      _recordStartTime = null;

      // 通知监听器
      _notifyRecordingListeners();

      // 删除录音文件
      if (_recordPath.isNotEmpty) {
        final file = File(_recordPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[VoiceRecorder] 已删除录音文件: $_recordPath');
        }
      }

      debugPrint('[VoiceRecorder] 已取消录音');
      return true;
    } catch (e) {
      debugPrint('[VoiceRecorder] 取消录音失败: $e');

      // 更新状态
      _isRecording = false;
      _recordDuration = 0;
      _recordStartTime = null;

      // 通知监听器
      _notifyRecordingListeners();

      return false;
    }
  }

  /// 添加录音状态监听器
  void addRecordingListener(Function(bool, int) listener) {
    if (!_recordingListeners.contains(listener)) {
      _recordingListeners.add(listener);
    }
  }

  /// 移除录音状态监听器
  void removeRecordingListener(Function(bool, int) listener) {
    _recordingListeners.remove(listener);
  }

  /// 通知录音状态监听器
  void _notifyRecordingListeners() {
    for (var listener in _recordingListeners) {
      listener(_isRecording, _recordDuration);
    }
  }

  /// 释放资源
  void dispose() {
    _recordTimer?.cancel();
    _recordTimer = null;
    _audioRecorder.dispose();
    _recordingListeners.clear();
    _isRecording = false;
    _recordDuration = 0;
    _recordStartTime = null;
  }
}
