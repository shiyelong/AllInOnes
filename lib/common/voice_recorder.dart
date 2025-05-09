import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 语音录制器
/// 用于录制语音消息
class VoiceRecorder {
  static final VoiceRecorder _instance = VoiceRecorder._internal();
  factory VoiceRecorder() => _instance;

  VoiceRecorder._internal();

  // 录音器
  final _recorder = _MockRecord();

  // 录音状态
  bool _isRecording = false;

  // 录音开始时间
  DateTime? _recordStartTime;

  // 录音时长（秒）
  int _recordDuration = 0;

  // 录音计时器
  Timer? _recordTimer;

  // 录音状态监听器
  final List<Function(bool, int)> _recordingListeners = [];

  // 获取录音状态
  bool get isRecording => _isRecording;

  // 获取录音时长
  int get recordDuration => _recordDuration;

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    try {
      // 检查麦克风权限
      final status = await Permission.microphone.status;

      if (status.isGranted) {
        // 已有权限
        return true;
      } else if (status.isDenied) {
        // 请求权限
        final result = await Permission.microphone.request();
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        // 永久拒绝，需要用户手动开启
        return false;
      }

      return false;
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

    try {
      // 检查麦克风权限
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('[VoiceRecorder] 没有麦克风权限');
        return false;
      }

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // 开始录音
      await _recorder.start(
        path: filePath,
        encoder: 'aacLc',
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
          _recordDuration = DateTime.now().difference(_recordStartTime!).inSeconds;
          _notifyRecordingListeners();
        }
      });

      // 通知监听器
      _notifyRecordingListeners();

      debugPrint('[VoiceRecorder] 开始录音: $filePath');
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
      return {
        'success': false,
        'msg': '没有正在进行的录音',
      };
    }

    try {
      // 停止计时器
      _recordTimer?.cancel();
      _recordTimer = null;

      // 停止录音
      final path = await _recorder.stop();

      // 更新状态
      _isRecording = false;
      final duration = _recordDuration;
      _recordDuration = 0;
      _recordStartTime = null;

      // 通知监听器
      _notifyRecordingListeners();

      if (path != null) {
        debugPrint('[VoiceRecorder] 录音完成: $path, 时长: $duration 秒');
        return {
          'success': true,
          'path': path,
          'duration': duration,
        };
      } else {
        debugPrint('[VoiceRecorder] 录音失败: 路径为空');
        return {
          'success': false,
          'msg': '录音失败: 路径为空',
        };
      }
    } catch (e) {
      debugPrint('[VoiceRecorder] 停止录音失败: $e');

      // 更新状态
      _isRecording = false;
      _recordDuration = 0;
      _recordStartTime = null;

      // 通知监听器
      _notifyRecordingListeners();

      return {
        'success': false,
        'msg': '停止录音失败: $e',
      };
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
      final path = await _recorder.stop();

      // 更新状态
      _isRecording = false;
      _recordDuration = 0;
      _recordStartTime = null;

      // 通知监听器
      _notifyRecordingListeners();

      // 删除录音文件
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[VoiceRecorder] 录音已取消，文件已删除: $path');
        }
      }

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
    _recorder.dispose();
    _recordingListeners.clear();
    _isRecording = false;
    _recordDuration = 0;
    _recordStartTime = null;
  }
}

/// 模拟录音类
class _MockRecord {
  String? _path;
  bool _isRecording = false;

  /// 开始录音
  Future<void> start({
    required String path,
    int? bitRate,
    int? samplingRate,
    int? numChannels,
    dynamic encoder,
    dynamic device,
    dynamic autoGain,
    dynamic echoCancel,
    dynamic noiseSuppress,
  }) async {
    _path = path;
    _isRecording = true;
    debugPrint('[MockRecord] 开始录音: $path');
    return;
  }

  /// 停止录音
  Future<String?> stop() async {
    _isRecording = false;
    debugPrint('[MockRecord] 停止录音: $_path');
    return _path;
  }

  /// 暂停录音
  Future<void> pause() async {
    debugPrint('[MockRecord] 暂停录音');
    return;
  }

  /// 恢复录音
  Future<void> resume() async {
    debugPrint('[MockRecord] 恢复录音');
    return;
  }

  /// 检查是否正在录音
  Future<bool> isRecording() async {
    return _isRecording;
  }

  /// 检查是否暂停
  Future<bool> isPaused() async {
    return false;
  }

  /// 获取录音振幅
  Future<double> getAmplitude() async {
    return 0.0;
  }

  /// 释放资源
  void dispose() {
    _path = null;
    _isRecording = false;
    debugPrint('[MockRecord] 释放资源');
  }
}
