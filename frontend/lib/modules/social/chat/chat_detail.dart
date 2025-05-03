import 'package:flutter/material.dart';
import 'dart:io';
import '../../../common/theme_manager.dart';
import 'chat_message_list.dart';
import 'chat_input.dart';
import 'enhanced_chat_input.dart';

class ChatDetail extends StatefulWidget {
  final Map chat;
  final List<Map<String, dynamic>> messages;
  final void Function(String text)? onSendText;
  final void Function(File image, String path)? onSendImage;
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
    final theme = ThemeManager.currentTheme;

    return Column(
      children: [
        // 聊天头部
        Container(
          color: theme.isDark ? Color(0xFF2D2D2D) : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.primaryColor.withOpacity(0.2),
                child: Text(
                  widget.chat['target_name']?[0] ?? '?',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat['target_name'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '在线',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.phone,
                  color: theme.primaryColor,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('语音通话功能开发中')),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.videocam,
                  color: theme.primaryColor,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('视频通话功能开发中')),
                  );
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: theme.isDark ? Colors.grey[800] : Colors.grey[300]),

        // 消息列表
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              // 使用渐变背景，类似QQ的聊天背景
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.primaryColor.withOpacity(0.05),
                  theme.backgroundColor,
                ],
              ),
            ),
            child: ChatMessageList(messages: widget.messages, controller: _scrollCtrl),
          ),
        ),

        // 输入区域
        Container(
          color: theme.isDark ? Color(0xFF2D2D2D) : Colors.white,
          child: EnhancedChatInput(
            onSendText: widget.onSendText,
            onSendImage: widget.onSendImage,
            onSendEmoji: widget.onSendEmoji,
            targetId: widget.chat['target_id']?.toString(),
            targetName: widget.chat['target_name']?.toString() ?? '未知用户',
            targetAvatar: widget.chat['target_avatar']?.toString() ?? '',
            onSendVideo: (video, path) {
              // 实现发送视频功能
              try {
                debugPrint('发送视频: $path');
                // 这里可以添加实际的视频发送逻辑
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('视频发送成功'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('发送视频失败: $e'), backgroundColor: Colors.red),
                );
              }
            },
            onSendFile: (file, path, fileName) {
              // 实现发送文件功能
              try {
                debugPrint('发送文件: $fileName, 路径: $path');
                // 这里可以添加实际的文件发送逻辑
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('文件发送成功'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('发送文件失败: $e'), backgroundColor: Colors.red),
                );
              }
            },
            onStartVoiceCall: () {
              // 实现语音通话功能
              try {
                debugPrint('启动语音通话');
                // 这里可以添加实际的语音通话逻辑
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('正在发起语音通话...'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('启动语音通话失败: $e'), backgroundColor: Colors.red),
                );
              }
            },
            onStartVideoCall: () {
              // 实现视频通话功能
              try {
                debugPrint('启动视频通话');
                // 这里可以添加实际的视频通话逻辑
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('正在发起视频通话...'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('启动视频通话失败: $e'), backgroundColor: Colors.red),
                );
              }
            },
            onSendRedPacket: (amount, greeting) {
              // TODO: 实现发送红包功能
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('发送红包功能开发中')),
              );
            },
          ),
        ),
      ],
    );
  }
}
