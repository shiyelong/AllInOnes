import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'emoji_picker.dart';
import 'location_picker.dart';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/persistence.dart';
import '../call/voice_call_page.dart';
import '../call/video_call_page.dart';

class EnhancedChatInput extends StatefulWidget {
  final void Function(String text)? onSendText;
  final void Function(File image, String path)? onSendImage;
  final void Function(File video, String path)? onSendVideo;
  final void Function(File file, String path, String fileName)? onSendFile;
  final void Function(String emoji)? onSendEmoji;
  final void Function()? onStartVoiceCall;
  final void Function()? onStartVideoCall;
  final void Function(double amount, String greeting)? onSendRedPacket;
  final void Function(double latitude, double longitude, String address)? onSendLocation;
  final void Function(double latitude, double longitude, String address, int duration)? onSendLiveLocation;

  // 添加聊天对象信息，用于语音/视频通话
  final String? targetId;
  final String? targetName;
  final String? targetAvatar;

  const EnhancedChatInput({
    Key? key,
    this.onSendText,
    this.onSendImage,
    this.onSendVideo,
    this.onSendFile,
    this.onSendEmoji,
    this.onStartVoiceCall,
    this.onStartVideoCall,
    this.onSendRedPacket,
    this.onSendLocation,
    this.onSendLiveLocation,
    this.targetId,
    this.targetName,
    this.targetAvatar,
  }) : super(key: key);

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showEmoji = false;
  bool _showMoreOptions = false;
  bool _isRecording = false;

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

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.onSendText != null) {
      widget.onSendText!(text);
      _controller.clear();
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && widget.onSendImage != null) {
        widget.onSendImage!(File(image.path), image.path);
      }
    } catch (e) {
      print('选择图片出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null && widget.onSendVideo != null) {
        widget.onSendVideo!(File(video.path), video.path);
      }
    } catch (e) {
      print('选择视频出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择视频失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null && widget.onSendFile != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        widget.onSendFile!(file, file.path, fileName);
      }
    } catch (e) {
      print('选择文件出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRedPacketDialog() {
    if (widget.onSendRedPacket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('红包功能开发中'), backgroundColor: Colors.orange),
      );
      return;
    }

    final amountController = TextEditingController();
    final greetingController = TextEditingController(text: '恭喜发财，大吉大利！');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发红包'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: '金额',
                hintText: '请输入红包金额',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            TextField(
              controller: greetingController,
              decoration: InputDecoration(
                labelText: '祝福语',
                hintText: '请输入祝福语',
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 2,
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
              final amountText = amountController.text.trim();
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入金额'), backgroundColor: Colors.red),
                );
                return;
              }

              final amount = double.tryParse(amountText);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入有效金额'), backgroundColor: Colors.red),
                );
                return;
              }

              final greeting = greetingController.text.trim();
              if (greeting.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入祝福语'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(context);
              widget.onSendRedPacket!(amount, greeting);
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
    } else {
      // 直接实现语音通话功能
      try {
        debugPrint('启动语音通话');

        // 获取当前聊天对象信息
        final userInfo = Persistence.getUserInfo();
        if (userInfo == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('用户信息不存在，请重新登录'), backgroundColor: Colors.red),
          );
          return;
        }

        // 通知用户功能已启用
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在发起语音通话...'), backgroundColor: Colors.green),
        );

        // 导航到语音通话页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VoiceCallPage(
              userId: userInfo.id.toString(),
              targetId: widget.targetId ?? '0',
              targetName: widget.targetName ?? '未知用户',
              targetAvatar: widget.targetAvatar ?? '',
              isIncoming: false,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动语音通话失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startVideoCall() {
    if (widget.onStartVideoCall != null) {
      widget.onStartVideoCall!();
    } else {
      // 直接实现视频通话功能
      try {
        debugPrint('启动视频通话');

        // 获取当前聊天对象信息
        final userInfo = Persistence.getUserInfo();
        if (userInfo == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('用户信息不存在，请重新登录'), backgroundColor: Colors.red),
          );
          return;
        }

        // 通知用户功能已启用
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在发起视频通话...'), backgroundColor: Colors.green),
        );

        // 导航到视频通话页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallPage(
              userId: userInfo.id.toString(),
              targetId: widget.targetId ?? '0',
              targetName: widget.targetName ?? '未知用户',
              targetAvatar: widget.targetAvatar ?? '',
              isIncoming: false,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动视频通话失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLocationPicker() {
    if (widget.onSendLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('位置分享功能开发中'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 显示位置选择对话框
    showDialog(
      context: context,
      builder: (context) => LocationPickerDialog(
        onLocationSelected: (latitude, longitude, address) {
          widget.onSendLocation!(latitude, longitude, address);
        },
      ),
    );
  }

  void _showLiveLocationPicker() {
    if (widget.onSendLiveLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('实时位置分享功能开发中'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 显示实时位置分享对话框
    showDialog(
      context: context,
      builder: (context) => LiveLocationSharingDialog(
        onLiveLocationSharing: (latitude, longitude, address, duration) {
          widget.onSendLiveLocation!(latitude, longitude, address, duration);
        },
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    final theme = ThemeManager.currentTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.isDark ? Colors.grey[800] : theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.primaryColor,
              size: 28,
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.isDark ? Colors.grey[300] : Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.isDark ? Color(0xFF2D2D2D) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              // 表情按钮
              IconButton(
                icon: Icon(
                  _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  color: _showEmoji ? theme.primaryColor : theme.isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 24,
                ),
                onPressed: _toggleEmoji,
              ),
              // 更多选项按钮
              IconButton(
                icon: Icon(
                  _showMoreOptions ? Icons.close : Icons.add_circle_outline,
                  color: _showMoreOptions ? theme.primaryColor : theme.isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 24,
                ),
                onPressed: _toggleMoreOptions,
              ),
              // 输入框
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: theme.isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: TextStyle(
                        color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    style: TextStyle(
                      color: theme.isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
              ),
              // 发送按钮
              IconButton(
                icon: Icon(
                  Icons.send,
                  color: theme.primaryColor,
                  size: 24,
                ),
                onPressed: _sendText,
              ),
            ],
          ),
        ),
        // 表情选择器
        if (_showEmoji)
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: theme.isDark ? Color(0xFF2D2D2D) : Colors.grey[100],
              border: Border(
                top: BorderSide(
                  color: theme.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: EmojiPicker(
              onSelected: (emoji) {
                // 始终将表情插入到输入框
                final currentText = _controller.text;
                final selection = _controller.selection;
                final newText = currentText.replaceRange(
                  selection.start,
                  selection.end,
                  emoji,
                );
                _controller.text = newText;
                _controller.selection = TextSelection.collapsed(
                  offset: selection.baseOffset + emoji.length,
                );
              },
            ),
          ),
        // 更多选项
        if (_showMoreOptions)
          Container(
            height: 200,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: theme.isDark ? Color(0xFF2D2D2D) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: theme.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              children: [
                _buildOptionItem(Icons.photo, '图片', _pickImage),
                _buildOptionItem(Icons.videocam, '视频', _pickVideo),
                _buildOptionItem(Icons.insert_drive_file, '文件', _pickFile),
                _buildOptionItem(Icons.redeem, '红包', _showRedPacketDialog),
                _buildOptionItem(Icons.call, '语音通话', _startVoiceCall),
                _buildOptionItem(Icons.video_call, '视频通话', _startVideoCall),
                _buildOptionItem(Icons.location_on, '位置', _showLocationPicker),
                _buildOptionItem(Icons.location_searching, '实时位置', _showLiveLocationPicker),
                _buildOptionItem(Icons.contacts, '名片', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('名片分享功能开发中')),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}
