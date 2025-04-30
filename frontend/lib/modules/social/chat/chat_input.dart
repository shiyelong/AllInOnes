import 'package:flutter/material.dart';
import 'emoji_picker.dart';
import 'image_picker.dart';

class ChatInput extends StatefulWidget {
  final void Function(String text)? onSendText;
  final void Function(dynamic image)? onSendImage;
  final void Function(String emoji)? onSendEmoji;
  const ChatInput({Key? key, this.onSendText, this.onSendImage, this.onSendEmoji}) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showEmoji = false;

  void _toggleEmoji() => setState(() => _showEmoji = !_showEmoji);

  void _pickImage() async {
    final img = await pickImage();
    if (img != null && widget.onSendImage != null) widget.onSendImage!(img);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(icon: Icon(Icons.emoji_emotions_outlined), onPressed: _toggleEmoji),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(hintText: '请输入内容...'),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty && widget.onSendText != null) {
                    widget.onSendText!(v.trim());
                    _controller.clear();
                  }
                },
              ),
            ),
            IconButton(icon: Icon(Icons.photo), onPressed: _pickImage),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: () {
                final txt = _controller.text.trim();
                if (txt.isNotEmpty && widget.onSendText != null) {
                  widget.onSendText!(txt);
                  _controller.clear();
                }
              },
            ),
          ],
        ),
        if (_showEmoji)
          EmojiPicker(
            onSelected: (emoji) {
              if (widget.onSendEmoji != null) widget.onSendEmoji!(emoji);
            },
          ),
      ],
    );
  }
}
