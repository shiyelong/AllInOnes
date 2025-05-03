import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:frontend/common/config.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String audioUrl;
  final int duration; // 语音时长（秒）
  final String? transcription; // 语音转写文本
  final bool isMe; // 是否是自己发送的消息

  const VoiceMessageWidget({
    Key? key,
    required this.audioUrl,
    required this.duration,
    this.transcription,
    required this.isMe,
  }) : super(key: key);

  @override
  _VoiceMessageWidgetState createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _currentPosition = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
          _currentPosition = 0;
        });
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _timer?.cancel();
      setState(() {
        _isPlaying = false;
      });
    } else {
      String fullUrl = widget.audioUrl.startsWith('http')
          ? widget.audioUrl
          : '${Config.baseUrl}${widget.audioUrl}';
      
      await _audioPlayer.play(UrlSource(fullUrl));
      
      setState(() {
        _isPlaying = true;
        _currentPosition = 0;
      });
      
      // 使用定时器更新进度
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_currentPosition < widget.duration) {
          setState(() {
            _currentPosition++;
          });
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isMe ? theme.primaryColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: theme.primaryColor,
                ),
                onPressed: _playPause,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_currentPosition}s / ${widget.duration}s',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 150,
                    child: LinearProgressIndicator(
                      value: widget.duration > 0 
                          ? _currentPosition / widget.duration 
                          : 0,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.transcription != null && widget.transcription!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
            child: Text(
              '📝 ${widget.transcription}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
