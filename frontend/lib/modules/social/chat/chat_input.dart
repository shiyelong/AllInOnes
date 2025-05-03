import 'package:flutter/material.dart';
import 'emoji_picker.dart';
import 'image_picker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../common/theme_manager.dart';

class ChatInput extends StatefulWidget {
  final void Function(String text)? onSendText;
  final void Function(File image, String path)? onSendImage;
  final void Function(File video, String thumbnail, String path)? onSendVideo;
  final void Function(File file, String filename, String filesize, String path)? onSendFile;
  final void Function(String emoji)? onSendEmoji;
  final void Function(double amount, String message)? onSendRedPacket;
  final void Function()? onStartVoiceCall;
  final void Function()? onStartVideoCall;

  const ChatInput({
    Key? key,
    this.onSendText,
    this.onSendImage,
    this.onSendVideo,
    this.onSendFile,
    this.onSendEmoji,
    this.onSendRedPacket,
    this.onStartVoiceCall,
    this.onStartVideoCall,
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showEmoji = false;
  bool _showMoreOptions = false;

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
      if (_showEmoji) {
        _showMoreOptions = false;
      }
    });
  }

  void _toggleMoreOptions() {
    setState(() {
      _showMoreOptions = !_showMoreOptions;
      if (_showMoreOptions) {
        _showEmoji = false;
      }
    });
  }

  void _pickImage() async {
    final img = await pickImage();
    if (img != null && widget.onSendImage != null) {
      widget.onSendImage!(File(img.path), img.path);
    }
  }

  void _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null && widget.onSendVideo != null) {
      final file = File(result.files.single.path!);
      // 生成缩略图（实际应用中应该使用视频缩略图生成库）
      final thumbnail = 'https://via.placeholder.com/120x120?text=Video';
      widget.onSendVideo!(file, thumbnail, result.files.single.path!);
    }
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null && widget.onSendFile != null) {
      final file = File(result.files.single.path!);
      final filename = result.files.single.name;
      final filesize = _formatFileSize(result.files.single.size);
      widget.onSendFile!(file, filename, filesize, result.files.single.path!);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  void _showRedPacketDialog() {
    if (widget.onSendRedPacket == null) return;

    double amount = 0.0;
    String message = '恭喜发财，大吉大利';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发红包'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '金额',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                amount = double.tryParse(value) ?? 0.0;
              },
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: '祝福语',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                message = value;
              },
              maxLength: 30,
              controller: TextEditingController(text: message),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (amount > 0) {
                widget.onSendRedPacket!(amount, message);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入有效金额')),
                );
              }
            },
            child: Text('发送'),
          ),
        ],
      ),
    );
  }

  void _startVoiceCall() {
    if (widget.onStartVoiceCall != null) {
      widget.onStartVoiceCall!();
    }
  }

  void _startVideoCall() {
    if (widget.onStartVideoCall != null) {
      widget.onStartVideoCall!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.emoji_emotions_outlined),
              onPressed: _toggleEmoji,
              color: _showEmoji ? theme.primaryColor : null,
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline),
              onPressed: _toggleMoreOptions,
              color: _showMoreOptions ? theme.primaryColor : null,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '请输入内容...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.isDark ? Colors.grey[800] : Colors.grey[200],
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                minLines: 1,
                maxLines: 5,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty && widget.onSendText != null) {
                    widget.onSendText!(v.trim());
                    _controller.clear();
                  }
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: () {
                final txt = _controller.text.trim();
                if (txt.isNotEmpty && widget.onSendText != null) {
                  widget.onSendText!(txt);
                  _controller.clear();
                }
              },
              color: theme.primaryColor,
            ),
          ],
        ),
        if (_showEmoji)
          Container(
            height: 200,
            child: EmojiPicker(
              onSelected: (emoji) {
                if (widget.onSendEmoji != null) widget.onSendEmoji!(emoji);
              },
            ),
          ),
        if (_showMoreOptions)
          Container(
            height: 120,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: GridView.count(
              crossAxisCount: 4,
              children: [
                _buildOptionItem(Icons.photo, '图片', _pickImage),
                _buildOptionItem(Icons.videocam, '视频', _pickVideo),
                _buildOptionItem(Icons.insert_drive_file, '文件', _pickFile),
                _buildOptionItem(Icons.redeem, '红包', _showRedPacketDialog),
                _buildOptionItem(Icons.call, '语音通话', _startVoiceCall),
                _buildOptionItem(Icons.video_call, '视频通话', _startVideoCall),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: ThemeManager.currentTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: ThemeManager.currentTheme.primaryColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
