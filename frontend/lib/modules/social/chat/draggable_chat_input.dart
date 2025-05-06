import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'emoji_picker.dart';
import 'location_picker.dart';
import 'image_picker.dart' as custom_picker;
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/persistence.dart';
import '../../../common/api.dart';
import '../call/voice_call_page.dart';
import '../call/video_call_page.dart';

class DraggableChatInput extends StatefulWidget {
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

  const DraggableChatInput({
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
  State<DraggableChatInput> createState() => _DraggableChatInputState();
}

class _DraggableChatInputState extends State<DraggableChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showEmoji = false;
  bool _showMoreOptions = false;
  bool _isRecording = false;
  bool _isDragging = false;
  List<XFile> _draggedFiles = [];

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
      if (_showEmoji) {
        _showMoreOptions = false;

        // 确保输入框获得焦点
        FocusScope.of(context).requestFocus(FocusNode());

        // 延迟一下再设置光标位置，确保表情选择器已经显示
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            // 确保输入框获得焦点并设置光标位置
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          }
        });
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

  // 选择并发送图片 - 增强版
  Future<void> _pickImage() async {
    try {
      // 使用自定义图片选择器，它已经包含预览功能
      final XFile? image = await custom_picker.showImageSourceDialog(context);

      if (image != null) {
        final file = File(image.path);

        // 显示发送中状态
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                SizedBox(width: 16),
                Text('正在发送图片...'),
              ],
            ),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.blue,
          ),
        );

        // 发送图片
        if (widget.onSendImage != null) {
          try {
            widget.onSendImage!(file, image.path);

            // 发送成功提示
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('图片发送成功'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          } catch (sendError) {
            debugPrint('[DraggableChatInput] 发送图片出错: $sendError');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('发送图片失败: $sendError'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[DraggableChatInput] 选择图片出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 拍照并发送
  Future<void> _takePhoto() async {
    try {
      final XFile? image = await custom_picker.takePhoto(context: context);
      if (image != null && widget.onSendImage != null) {
        final file = File(image.path);
        widget.onSendImage!(file, image.path);
      }
    } catch (e) {
      debugPrint('[DraggableChatInput] 拍照出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 选择并发送视频
  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null && widget.onSendVideo != null) {
        final file = File(video.path);
        widget.onSendVideo!(file, video.path);
      }
    } catch (e) {
      debugPrint('[DraggableChatInput] 选择视频出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择视频失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 选择并发送文件
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null && widget.onSendFile != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        widget.onSendFile!(file, file.path, fileName);
      }
    } catch (e) {
      debugPrint('[DraggableChatInput] 选择文件出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 处理拖放文件 - 完全重写增强版
  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (files.isEmpty) {
      debugPrint('[DraggableChatInput] 没有收到拖放文件');
      return;
    }

    debugPrint('[DraggableChatInput] 收到拖放文件: ${files.length}个');

    // 关闭表情和更多选项面板
    setState(() {
      _showEmoji = false;
      _showMoreOptions = false;
      _isDragging = false;
    });

    // 显示处理中提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(width: 16),
            Text('正在处理${files.length}个文件...'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );

    // 如果只有一个文件，显示预览对话框
    if (files.length == 1) {
      final file = files.first;
      final filePath = file.path;
      final extension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
      final fileName = path.basename(filePath);

      debugPrint('[DraggableChatInput] 处理单个拖放文件: $filePath, 扩展名: $extension, 文件名: $fileName');

      try {
        // 检查文件是否存在
        final fileObj = File(filePath);
        if (!await fileObj.exists()) {
          debugPrint('[DraggableChatInput] 文件不存在: $filePath');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('文件不存在: $filePath'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // 根据文件类型显示不同的预览
        if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(extension)) {
          // 图片文件 - 显示图片预览
          final bool shouldSend = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('发送图片'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(
                    fileObj,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 8),
                  Text(fileName, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('发送'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldSend && widget.onSendImage != null) {
            try {
              debugPrint('[DraggableChatInput] 发送拖放图片: $filePath');
              widget.onSendImage!(fileObj, filePath);

              // 发送成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('图片发送成功'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
            } catch (e) {
              debugPrint('[DraggableChatInput] 发送图片异常: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('发送图片失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm'].contains(extension)) {
          // 视频文件 - 显示视频信息预览
          final fileSize = await fileObj.length();
          final formattedSize = formatFileSize(fileSize);

          final bool shouldSend = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('发送视频'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_file, size: 64, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(fileName, style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('文件大小: $formattedSize', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('发送'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldSend && widget.onSendVideo != null) {
            try {
              debugPrint('[DraggableChatInput] 发送拖放视频: $filePath');
              widget.onSendVideo!(fileObj, filePath);

              // 发送成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('视频发送成功'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
            } catch (e) {
              debugPrint('[DraggableChatInput] 发送视频异常: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('发送视频失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // 其他文件 - 显示文件信息预览
          final fileSize = await fileObj.length();
          final formattedSize = formatFileSize(fileSize);

          final bool shouldSend = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('发送文件'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getFileIcon(filePath), size: 64, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(fileName, style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('文件大小: $formattedSize', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('发送'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldSend && widget.onSendFile != null) {
            try {
              debugPrint('[DraggableChatInput] 发送拖放文件: $filePath');
              widget.onSendFile!(fileObj, filePath, fileName);

              // 发送成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('文件发送成功'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
            } catch (e) {
              debugPrint('[DraggableChatInput] 发送文件异常: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('发送文件失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[DraggableChatInput] 处理文件异常: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('处理文件失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // 多个文件处理
      int successCount = 0;
      int failCount = 0;

      // 处理每个文件
      for (final file in files) {
        final filePath = file.path;
        final extension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
        final fileName = path.basename(filePath);

        debugPrint('[DraggableChatInput] 处理拖放文件: $filePath, 扩展名: $extension, 文件名: $fileName');

        try {
          // 检查文件是否存在
          final fileObj = File(filePath);
          if (!await fileObj.exists()) {
            debugPrint('[DraggableChatInput] 文件不存在: $filePath');
            failCount++;
            continue;
          }

          // 根据文件类型直接发送
          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(extension)) {
            // 图片文件
            if (widget.onSendImage != null) {
              debugPrint('[DraggableChatInput] 发送拖放图片: $filePath');
              widget.onSendImage!(fileObj, filePath);
              successCount++;
            }
          } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm'].contains(extension)) {
            // 视频文件
            if (widget.onSendVideo != null) {
              debugPrint('[DraggableChatInput] 发送拖放视频: $filePath');
              widget.onSendVideo!(fileObj, filePath);
              successCount++;
            }
          } else {
            // 其他文件
            if (widget.onSendFile != null) {
              debugPrint('[DraggableChatInput] 发送拖放文件: $filePath');
              widget.onSendFile!(fileObj, filePath, fileName);
              successCount++;
            }
          }
        } catch (e) {
          debugPrint('[DraggableChatInput] 处理文件异常: $e');
          failCount++;
        }
      }

      // 显示处理结果
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已发送 $successCount 个文件' + (failCount > 0 ? '，$failCount 个文件发送失败' : '')),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  // 格式化文件大小
  String formatFileSize(int bytes) {
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

  // 根据文件扩展名获取对应的图标
  IconData _getFileIcon(String path) {
    final extension = path.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'flac':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
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

  // 获取拖放文件类型的文本描述
  String _getFileTypeText() {
    // 如果没有文件，显示默认文本
    if (_draggedFiles.isEmpty) {
      return '文件';
    }

    // 统计不同类型的文件数量
    int imageCount = 0;
    int videoCount = 0;
    int otherCount = 0;

    for (final file in _draggedFiles) {
      final path = file.path;
      final extension = path.split('.').last.toLowerCase();

      if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(extension)) {
        imageCount++;
      } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm'].contains(extension)) {
        videoCount++;
      } else {
        otherCount++;
      }
    }

    // 根据文件类型和数量生成描述文本
    List<String> descriptions = [];

    if (imageCount > 0) {
      descriptions.add('${imageCount}张图片');
    }

    if (videoCount > 0) {
      descriptions.add('${videoCount}个视频');
    }

    if (otherCount > 0) {
      descriptions.add('${otherCount}个文件');
    }

    if (_draggedFiles.length == 1) {
      // 如果只有一个文件，显示文件名
      return _draggedFiles.first.path.split('/').last;
    } else if (descriptions.isNotEmpty) {
      // 如果有多个文件，显示类型和数量
      return descriptions.join('、');
    } else {
      // 如果无法确定文件类型，显示默认文本
      return '文件';
    }
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
        // 拖放区域 - 简化版本
        DropTarget(
          onDragDone: (detail) {
            setState(() {
              _isDragging = false;
              _draggedFiles = detail.files;
            });
            _handleDroppedFiles(detail.files);
          },
          onDragEntered: (detail) {
            setState(() {
              _isDragging = true;
            });
            debugPrint('[DraggableChatInput] 文件拖入');
          },
          onDragExited: (detail) {
            setState(() {
              _isDragging = false;
            });
            debugPrint('[DraggableChatInput] 文件拖出');
          },
          onDragUpdated: (detail) {
            if (!_isDragging) {
              setState(() {
                _isDragging = true;
              });
            }
          },
          child: Stack(
            children: [
              // 输入框区域
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
                  border: Border.all(
                    color: _isDragging
                      ? theme.primaryColor
                      : (theme.isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: _isDragging ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
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

              // 拖放提示覆盖层 - 增强版
              if (_isDragging)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.primaryColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_upload,
                            color: theme.primaryColor,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '松开发送文件',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '支持图片、视频和其他文件',
                            style: TextStyle(
                              color: theme.primaryColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, color: theme.primaryColor, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  '拖放前会显示预览',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                _buildOptionItem(Icons.photo_library, '相册', _pickImage),
                _buildOptionItem(Icons.camera_alt, '拍照', _takePhoto),
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
