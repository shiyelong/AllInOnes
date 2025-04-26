import 'package:flutter/material.dart';
import 'single_chat_controller.dart';
import 'widgets/single_chat_message_list.dart';
import 'widgets/single_chat_input_box.dart';

class SingleChatPage extends StatelessWidget {
  final List<Map<String, dynamic>> messages = const [
    {"fromMe": false, "text": "你好！我是对方，欢迎使用 ALL。", "avatar": "A"},
    {"fromMe": true, "text": "你好！很高兴认识你。", "avatar": "我"},
    {"fromMe": false, "text": "你可以体验 Telegram 风格的聊天气泡。", "avatar": "A"},
    {"fromMe": true, "text": "UI 很赞！", "avatar": "我"},
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 64),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              itemCount: messages.length,
              itemBuilder: (context, idx) {
                final msg = messages[idx];
                final isMe = msg["fromMe"] as bool;
                return Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(child: Text(msg["avatar"])),
                      SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.65),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.grey[200] : Colors.blue[400],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                        ),
                        child: Text(
                          msg["text"],
                          style: TextStyle(color: isMe ? Colors.black87 : Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      SizedBox(width: 8),
                      CircleAvatar(child: Text(msg["avatar"])),
                    ],
                  ],
                );
              },
            ),
          ),
          // 悬浮输入框
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        fillColor: Colors.grey[100],
                        filled: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.send, color: Colors.white),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
