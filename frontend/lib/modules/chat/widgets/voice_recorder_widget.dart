import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:frontend/common/api.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String audioPath, int duration, String? transcription) onVoiceRecorded;
  final Function() onCancel;

  const VoiceRecorderWidget({
    Key? key,
    required this.onVoiceRecorded,
    required this.onCancel,
  }) : super(key: key);

  @override
  _VoiceRecorderWidgetState createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  int _recordingDuration = 0;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能录音')),
      );
      widget.onCancel();
      return;
    }

    await _recorder.openRecorder();
    _isRecorderInitialized = true;
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) {
      return;
    }

    final directory = await getTemporaryDirectory();
    _recordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.aacADTS,
    );

    setState(() {
      _isRecording = true;
      _recordingDuration = 0;
    });

    // 使用定时器更新录音时长
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }

    _timer?.cancel();
    await _recorder.stopRecorder();

    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    // 处理录音文件
    if (_recordingPath != null) {
      try {
        // 读取录音文件
        final file = File(_recordingPath!);
        final bytes = await file.readAsBytes();
        final base64Audio = base64Encode(bytes);

        // 调用语音识别API
        final response = await Api.post('/speech/recognize', data: {
          'audio_data': base64Audio,
          'format': 'aac',
        });

        String? transcription;
        if (response['success'] == true && response['data'] != null) {
          transcription = response['data']['text'];
        }

        // 回调
        widget.onVoiceRecorded(_recordingPath!, _recordingDuration, transcription);
      } catch (e) {
        debugPrint('处理录音失败: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理录音失败: $e')),
        );
        widget.onCancel();
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    if (_isRecording) {
      await _recorder.stopRecorder();
    }
    
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    widget.onCancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRecording ? '正在录音...' : _isProcessing ? '处理中...' : '准备录音',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isRecording || _isProcessing)
            Text(
              '${_recordingDuration}s',
              style: TextStyle(
                fontSize: 24,
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 36),
                onPressed: _isProcessing ? null : _cancelRecording,
              ),
              if (!_isRecording && !_isProcessing)
                IconButton(
                  icon: Icon(Icons.mic, color: theme.primaryColor, size: 48),
                  onPressed: _startRecording,
                )
              else if (_isRecording)
                IconButton(
                  icon: Icon(Icons.stop, color: theme.primaryColor, size: 48),
                  onPressed: _stopRecording,
                )
              else
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(width: 36), // 占位，保持对称
            ],
          ),
        ],
      ),
    );
  }
}
