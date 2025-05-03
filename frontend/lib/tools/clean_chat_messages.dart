import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CleanChatMessages extends StatelessWidget {
  const CleanChatMessages({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('清理聊天消息'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await _cleanAllChatMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清理所有聊天消息')),
                );
              },
              child: const Text('清理所有聊天消息'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cleanAllChatMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    
    for (final key in keys) {
      if (key.startsWith('chat_messages_') || key.startsWith('last_message_')) {
        await prefs.remove(key);
        debugPrint('已删除: $key');
      }
    }
  }
}
