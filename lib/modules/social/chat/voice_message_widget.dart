import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import '../../../common/voice_player.dart';
import '../../../common/theme_manager.dart';

/// 语音消息组件
/// 显示语音消息，支持播放、暂停等功能
class VoiceMessageWidget extends StatefulWidget {
  final String messageId;
  final String filePath;
  final int duration;
  final bool isMe;
  final String? serverUrl;

  const VoiceMessageWidget({
    Key? key,
    required this.messageId,
    required this.filePath,
    required this.duration,
    required this.isMe,
    this.serverUrl,
  }) : super(key: key);

  @override
  _VoiceMessageWidgetState createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isPaused = false;
  double _progress = 0.0;
  int _currentPosition = 0;
  late AnimationController _animationController;
  bool _fileExists = false;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat();
    
    // 检查文件是否存在
    _checkFileExists();
    
    // 监听播放状态
    VoicePlayer().addListener(_onPlayStateChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    VoicePlayer().removeListener(_onPlayStateChanged);
    super.dispose();
  }

  // 检查文件是否存在
  Future<void> _checkFileExists() async {
    try {
      final file = File(widget.filePath);
      final exists = await file.exists();
      
      if (mounted) {
        setState(() {
          _fileExists = exists;
        });
      }
    } catch (e) {
      debugPrint('[VoiceMessageWidget] 检查文件是否存在失败: $e');
      if (mounted) {
        setState(() {
          _fileExists = false;
        });
      }
    }
  }

  // 播放状态变化回调
  void _onPlayStateChanged(String messageId, bool isPlaying, bool isPaused, double progress, int position) {
    if (messageId == widget.messageId && mounted) {
      setState(() {
        _isPlaying = isPlaying;
        _isPaused = isPaused;
        _progress = progress;
        _currentPosition = position;
      });
    }
  }

  // 播放或暂停
  void _playOrPause() async {
    if (!_fileExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('语音文件不存在')),
      );
      return;
    }
    
    if (_isPlaying) {
      if (_isPaused) {
        // 恢复播放
        await VoicePlayer().resume(widget.messageId);
      } else {
        // 暂停播放
        await VoicePlayer().pause(widget.messageId);
      }
    } else {
      // 开始播放
      await VoicePlayer().play(
        messageId: widget.messageId,
        filePath: widget.filePath,
        duration: widget.duration,
        serverUrl: widget.serverUrl,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    final isMe = widget.isMe;
    
    // 计算宽度，根据语音时长动态调整
    final minWidth = 100.0;
    final maxWidth = 200.0;
    final maxDuration = 60; // 最大语音时长（秒）
    final width = minWidth + (maxWidth - minWidth) * math.min(widget.duration / maxDuration, 1.0);
    
    return GestureDetector(
      onTap: _playOrPause,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? theme.primaryColor
              : theme.isDark ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放图标
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Icon(
                  _isPlaying && !_isPaused
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: isMe ? Colors.white : theme.isDark ? Colors.white : Colors.black87,
                  size: 24,
                );
              },
            ),
            SizedBox(width: 8),
            
            // 波形动画
            Expanded(
              child: _isPlaying && !_isPaused
                  ? _buildWaveform(isMe)
                  : _buildStaticWaveform(isMe),
            ),
            
            SizedBox(width: 8),
            
            // 时长
            Text(
              _isPlaying
                  ? '${_formatDuration(_currentPosition)}/${_formatDuration(widget.duration * 1000)}'
                  : _formatDuration(widget.duration * 1000),
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white70 : theme.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建波形动画
  Widget _buildWaveform(bool isMe) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final delay = index * 0.2;
            final value = math.sin((_animationController.value * math.pi * 2) + delay) * 0.5 + 0.5;
            
            return Container(
              width: 3,
              height: 5 + value * 15,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withOpacity(0.7)
                    : ThemeManager.currentTheme.primaryColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }

  // 构建静态波形
  Widget _buildStaticWaveform(bool isMe) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final height = 5 + (index % 3 + 1) * 3.0;
        
        return Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withOpacity(0.5)
                : ThemeManager.currentTheme.primaryColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  // 格式化时长
  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
