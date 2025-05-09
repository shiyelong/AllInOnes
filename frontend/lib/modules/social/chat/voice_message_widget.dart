import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/common/voice_player.dart';
import 'package:frontend/common/theme_manager.dart';

/// 语音消息组件
/// 用于显示语音消息
class VoiceMessageWidget extends StatefulWidget {
  final String messageId;
  final String filePath;
  final int duration;
  final bool isMe;
  final bool isPlaying;
  
  const VoiceMessageWidget({
    Key? key,
    required this.messageId,
    required this.filePath,
    required this.duration,
    required this.isMe,
    this.isPlaying = false,
  }) : super(key: key);

  @override
  _VoiceMessageWidgetState createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> with SingleTickerProviderStateMixin {
  // 动画控制器
  late AnimationController _animationController;
  
  // 是否正在播放
  bool _isPlaying = false;
  
  // 播放进度
  double _playProgress = 0;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    // 循环播放动画
    _animationController.repeat(reverse: true);
    
    // 初始化播放状态
    _isPlaying = widget.isPlaying;
    
    // 监听播放状态
    VoicePlayer().addPlayingListener(_onPlayingStateChanged);
    
    // 如果当前消息正在播放，更新状态
    if (VoicePlayer().isPlaying && VoicePlayer().currentMessageId == widget.messageId) {
      _isPlaying = true;
      _playProgress = VoicePlayer().playProgress;
    }
  }
  
  @override
  void dispose() {
    // 移除播放状态监听器
    VoicePlayer().removePlayingListener(_onPlayingStateChanged);
    
    // 释放动画控制器
    _animationController.dispose();
    
    super.dispose();
  }
  
  // 播放状态变化回调
  void _onPlayingStateChanged(bool isPlaying, double progress, double duration, String? messageId) {
    if (messageId == widget.messageId) {
      setState(() {
        _isPlaying = isPlaying;
        _playProgress = progress;
      });
    } else if (_isPlaying) {
      setState(() {
        _isPlaying = false;
        _playProgress = 0;
      });
    }
  }
  
  // 播放或停止语音消息
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      // 停止播放
      await VoicePlayer().stopPlaying();
    } else {
      // 开始播放
      await VoicePlayer().playVoiceMessage(
        widget.messageId,
        widget.filePath,
        duration: widget.duration,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    
    // 计算进度条宽度
    final maxWidth = 200.0;
    final minWidth = 80.0;
    final progressWidth = minWidth + (maxWidth - minWidth) * (widget.duration / 60);
    
    // 计算播放进度
    final progress = _isPlaying ? _playProgress / widget.duration : 0.0;
    
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: progressWidth,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isMe ? theme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放按钮
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white.withOpacity(0.2) : theme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 16,
                  color: widget.isMe ? Colors.white : theme.primaryColor,
                ),
              ),
            ),
            SizedBox(width: 8),
            // 波形动画
            Expanded(
              child: _isPlaying
                  ? _buildWaveform(progress)
                  : _buildWaveformStatic(),
            ),
            SizedBox(width: 8),
            // 时长
            Text(
              '${widget.duration}″',
              style: TextStyle(
                fontSize: 12,
                color: widget.isMe ? Colors.white.withOpacity(0.8) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建静态波形
  Widget _buildWaveformStatic() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        8,
        (index) => Container(
          width: 3,
          height: 12 - (index % 3) * 4,
          decoration: BoxDecoration(
            color: widget.isMe
                ? Colors.white.withOpacity(0.6)
                : ThemeManager.currentTheme.primaryColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }
  
  // 构建动态波形
  Widget _buildWaveform(double progress) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            8,
            (index) {
              // 计算波形高度
              final baseHeight = 6.0;
              final maxHeight = 16.0;
              final heightFactor = _animationController.value * 0.5 + 0.5;
              
              // 根据进度显示不同颜色
              final isActive = index / 8 <= progress;
              
              // 计算实际高度
              final height = baseHeight + (maxHeight - baseHeight) * heightFactor * (1 - (index % 3) * 0.2);
              
              return Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? (isActive ? Colors.white : Colors.white.withOpacity(0.4))
                      : (isActive
                          ? ThemeManager.currentTheme.primaryColor
                          : ThemeManager.currentTheme.primaryColor.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
