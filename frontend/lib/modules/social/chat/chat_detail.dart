import 'package:flutter/material.dart';
import 'chat_message_list.dart';
import 'chat_input.dart';

class ChatDetail extends StatefulWidget {
  final Map chat;
  final List<Map<String, dynamic>> messages;
  final void Function(String text)? onSendText;
  final void Function(dynamic)? onSendImage;
  final void Function(String)? onSendEmoji;
  const ChatDetail({Key? key, required this.chat, required this.messages, this.onSendText, this.onSendImage, this.onSendEmoji}) : super(key: key);

  @override
  State<ChatDetail> createState() => _ChatDetailState();
}

class _ChatDetailState extends State<ChatDetail> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant ChatDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.grey[100],
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(child: Text(widget.chat['peer_name']?[0] ?? '?')),
              SizedBox(width: 12),
              Text(widget.chat['peer_name'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: ChatMessageList(messages: widget.messages, controller: _scrollCtrl),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ChatInput(
            onSendText: widget.onSendText,
            onSendImage: widget.onSendImage,
            onSendEmoji: widget.onSendEmoji,
          ),
        ),
      ],
    );
  }
}
