import 'package:flutter/material.dart';
import 'chat_message_item.dart';

class ChatMessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final ScrollController? controller;
  const ChatMessageList({Key? key, required this.messages, this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: messages.length,
      itemBuilder: (context, idx) {
        final msg = messages[messages.length - 1 - idx];
        return ChatMessageItem(message: msg);
      },
    );
  }
}
