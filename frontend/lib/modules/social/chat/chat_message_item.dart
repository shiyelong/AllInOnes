import 'package:flutter/material.dart';

class ChatMessageItem extends StatelessWidget {
  final Map<String, dynamic> message;
  const ChatMessageItem({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMe = message['isMe'] ?? false;
    final type = message['type'] ?? 'text';
    Widget content;
    switch (type) {
      case 'image':
        content = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(message['file'], width: 120, height: 120, fit: BoxFit.cover),
        );
        break;
      case 'emoji':
        content = Text(message['emoji'] ?? '', style: TextStyle(fontSize: 32));
        break;
      default:
        content = Text(message['text'] ?? '', style: TextStyle(fontSize: 16));
    }
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 6),
            child: CircleAvatar(child: Text(message['avatar'] ?? '?')),
          ),
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
          margin: EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.all(type == 'emoji' ? 0 : 10),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: content,
        ),
        if (isMe)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 6),
            child: CircleAvatar(child: Text(message['avatar'] ?? '我')),
          ),
      ],
    );
  }
}
