import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'emoji_picker.dart';
import 'location_picker.dart';
import 'telegram_style_media_picker.dart';
import 'telegram_style_media_preview.dart';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/persistence.dart';
import '../../../common/api.dart';
import '../../../common/enhanced_file_utils.dart';
import '../../../common/enhanced_thumbnail_generator.dart';
import '../../../common/thumbnail_manager.dart';
import '../../../common/voice_recorder.dart';
import 'call/voice_call_page.dart';
import 'call/video_call_page.dart';

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
  final void Function(String filePath, int duration)? onSendVoiceMessage;

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
    this.onSendVoiceMessage,
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

  // 录音相关
  int _recordDuration = 0;
  bool _isRecordingCancelled = false;

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

  // 选择并发送图片 - Telegram风格
  Future<void> _pickImage() async {
    try {
      // 使用Telegram风格的媒体选择器
      final List<MediaItem>? mediaItems = await TelegramStyleMediaPicker.pickImage(
        context: context,
        allowMultiple: true,
        allowCaption: true,
      );

      if (mediaItems != null && mediaItems.isNotEmpty && widget.onSendImage != null) {
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

        // 发送每张图片
        for (var item in mediaItems) {
          try {
            widget.onSendImage!(item.file, item.file.path);

            // 如果有标题，发送标题作为文本消息
            if (item.caption.isNotEmpty && widget.onSendText != null) {
              widget.onSendText!(item.caption);
            }
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

        // 发送成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片发送成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DraggableChatInput] 选择图片出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 拍照并发送 - Telegram风格
  Future<void> _takePhoto() async {
    try {
      // 使用Telegram风格的媒体选择器
      final List<MediaItem>? mediaItems = await TelegramStyleMediaPicker.takePhoto(
        context: context,
        allowCaption: true,
      );

      if (mediaItems != null && mediaItems.isNotEmpty && widget.onSendImage != null) {
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
        final item = mediaItems.first;
        try {
          widget.onSendImage!(item.file, item.file.path);

          // 如果有标题，发送标题作为文本消息
          if (item.caption.isNotEmpty && widget.onSendText != null) {
            widget.onSendText!(item.caption);
          }

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
    } catch (e) {
      debugPrint('[DraggableChatInput] 拍照出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 选择并发送视频 - Telegram风格
  Future<void> _pickVideo() async {
    try {
      // 使用Telegram风格的媒体选择器
      final List<MediaItem>? mediaItems = await TelegramStyleMediaPicker.pickVideo(
        context: context,
        allowCaption: true,
      );

      if (mediaItems != null && mediaItems.isNotEmpty && widget.onSendVideo != null) {
        // 显示发送中状态
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                SizedBox(width: 16),
                Text('正在发送视频...'),
              ],
            ),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.blue,
          ),
        );

        // 发送视频
        final item = mediaItems.first;
        try {
          widget.onSendVideo!(item.file, item.file.path);

          // 如果有标题，发送标题作为文本消息
          if (item.caption.isNotEmpty && widget.onSendText != null) {
            widget.onSendText!(item.caption);
          }

          // 发送成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('视频发送成功'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        } catch (sendError) {
          debugPrint('[DraggableChatInput] 发送视频出错: $sendError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('发送视频失败: $sendError'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[DraggableChatInput] 选择视频出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择视频失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 选择并发送文件 - Telegram风格
  Future<void> _pickFile() async {
    try {
      // 使用Telegram风格的媒体选择器
      final List<MediaItem>? mediaItems = await TelegramStyleMediaPicker.pickFile(
        context: context,
        allowCaption: true,
      );

      if (mediaItems != null && mediaItems.isNotEmpty && widget.onSendFile != null) {
        // 显示发送中状态
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                SizedBox(width: 16),
                Text('正在发送文件...'),
              ],
            ),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.blue,
          ),
        );

        // 发送文件
        final item = mediaItems.first;
        try {
          final fileName = path.basename(item.file.path);
          widget.onSendFile!(item.file, item.file.path, fileName);

          // 如果有标题，发送标题作为文本消息
          if (item.caption.isNotEmpty && widget.onSendText != null) {
            widget.onSendText!(item.caption);
          }

          // 发送成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('文件发送成功'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        } catch (sendError) {
          debugPrint('[DraggableChatInput] 发送文件出错: $sendError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('发送文件失败: $sendError'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

    // 验证文件是否可访问
    List<XFile> validFiles = [];
    for (final file in files) {
      try {
        // 检查文件是否存在
        final fileObj = File(file.path);
        if (await fileObj.exists()) {
          validFiles.add(file);
        } else {
          debugPrint('[DraggableChatInput] 文件不存在: ${file.path}');
        }
      } catch (e) {
        debugPrint('[DraggableChatInput] 验证文件失败: ${file.path}, 错误: $e');
      }
    }

    if (validFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('没有有效的文件可以发送'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 显示处理中提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(width: 16),
            Text('正在处理${validFiles.length}个文件...'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );

    // 如果只有一个文件，显示预览对话框
    if (validFiles.length == 1) {
      final file = validFiles.first;
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
          // 生成缩略图
          String thumbnailPath = '';
          try {
            debugPrint('[DraggableChatInput] 开始生成缩略图: $filePath');
            thumbnailPath = await ThumbnailManager.getThumbnail(
              filePath,
              width: 200,
              height: 200,
              quality: 80,
            );
            debugPrint('[DraggableChatInput] 缩略图生成成功: $thumbnailPath');
          } catch (e) {
            debugPrint('[DraggableChatInput] 生成缩略图失败: $e');
            // 缩略图生成失败不影响消息发送
          }

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
              // 验证文件路径
              final validPath = EnhancedFileUtils.getValidFilePath(filePath);
              if (validPath.isEmpty) {
                throw Exception('无效的图片路径');
              }

              // 确保文件存在
              if (!await EnhancedFileUtils.fileExists(validPath)) {
                throw Exception('图片文件不存在');
              }

              debugPrint('[DraggableChatInput] 发送拖放图片: $validPath');
              widget.onSendImage!(fileObj, validPath);

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
      for (final file in validFiles) {
        final filePath = file.path;
        final extension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
        final fileName = path.basename(filePath);

        debugPrint('[DraggableChatInput] 处理拖放文件: $filePath, 扩展名: $extension, 文件名: $fileName');

        try {
          // 文件已经在前面验证过存在，这里直接使用
          final fileObj = File(filePath);

          // 根据文件类型直接发送
          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(extension)) {
            // 图片文件
            if (widget.onSendImage != null) {
              try {
                // 验证文件路径
                final validPath = EnhancedFileUtils.getValidFilePath(filePath);
                if (validPath.isEmpty) {
                  throw Exception('无效的图片路径');
                }

                // 确保文件存在
                if (!await EnhancedFileUtils.fileExists(validPath)) {
                  throw Exception('图片文件不存在');
                }

                // 生成缩略图
                try {
                  debugPrint('[DraggableChatInput] 开始生成批量缩略图: $validPath');
                  await ThumbnailManager.getThumbnail(
                    validPath,
                    width: 200,
                    height: 200,
                    quality: 80,
                  );
                } catch (thumbError) {
                  debugPrint('[DraggableChatInput] 批量生成缩略图失败: $thumbError');
                  // 缩略图生成失败不影响消息发送
                }

                debugPrint('[DraggableChatInput] 发送拖放图片: $validPath');
                widget.onSendImage!(fileObj, validPath);
                successCount++;
              } catch (e) {
                debugPrint('[DraggableChatInput] 批量发送图片失败: $e');
                failCount++;
              }
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
              targetId: widget.targetId ?? '0',
              targetName: widget.targetName ?? '未知用户',
              targetAvatar: widget.targetAvatar ?? '',
              isIncoming: false,
              onCallEnded: () {},
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
              targetId: widget.targetId ?? '0',
              targetName: widget.targetName ?? '未知用户',
              targetAvatar: widget.targetAvatar ?? '',
              isIncoming: false,
              onCallEnded: () {},
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

  // 处理粘贴事件
  Future<void> _handlePaste() async {
    try {
      // 获取剪贴板数据
      final ClipboardData? clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

      // 如果是文本，直接插入到输入框
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        final text = clipboardData.text!;
        final currentText = _controller.text;
        final selection = _controller.selection;
        final newText = currentText.replaceRange(
          selection.start,
          selection.end,
          text,
        );
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: selection.baseOffset + text.length,
        );
        return;
      }

      // 尝试获取图片数据 - 注意：Flutter目前不直接支持获取剪贴板图片
      // 我们需要使用平台特定的通道或插件来实现这个功能
      // 这里我们使用一个简化的实现，仅支持文本粘贴

      debugPrint('[DraggableChatInput] 尝试处理粘贴内容');

      // 创建临时文件 - 在实际实现中，这里应该从剪贴板获取图片数据
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/clipboard_image_$timestamp.png');

      // 检查是否有图片文件
      bool hasImage = false;

      // 在实际实现中，这里应该检查剪贴板中是否有图片数据
      // 由于Flutter限制，我们需要使用平台特定的方法
      // 这里我们简单地提示用户使用其他方式添加图片

      if (!hasImage) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('目前不支持直接粘贴图片，请使用图片选择器或拖放功能'),
              action: SnackBarAction(
                label: '选择图片',
                onPressed: () => _pickImage(),
              ),
            ),
          );
        }
        return;
      }

      // 注意：由于我们已经在上面的代码中处理了粘贴图片的情况，
      // 这部分代码在当前实现中不会被执行
      // 保留这部分代码是为了将来实现真正的粘贴图片功能时使用

      // 在实际实现中，我们需要:
      // 1. 使用平台特定的通道获取剪贴板图片数据
      // 2. 将图片数据保存到临时文件
      // 3. 显示预览并让用户确认
      // 4. 发送图片

      debugPrint('[DraggableChatInput] 粘贴图片功能需要平台特定实现');

      // 提示用户使用其他方式添加图片
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请使用图片选择器或拖放功能添加图片'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DraggableChatInput] 处理粘贴异常: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    // 如果正在录音，显示录音界面
    if (_isRecording) {
      return Container(
        padding: EdgeInsets.all(16),
        color: theme.isDark ? Colors.grey[800] : Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '正在录音...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '上滑取消录音',
              style: TextStyle(
                fontSize: 14,
                color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '$_recordDuration 秒',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isRecording = false;
                    });
                    VoiceRecorder().cancelRecording();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('取消'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _isRecording = false;
                    });
                    await _stopRecording();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('完成'),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
                        child: RawKeyboardListener(
                          focusNode: FocusNode(),
                          onKey: (RawKeyEvent event) {
                            // 监听Ctrl+V或Command+V
                            if (event is RawKeyDownEvent) {
                              final bool isControlPressed = event.isControlPressed || event.isMetaPressed;
                              final bool isVPressed = event.logicalKey == LogicalKeyboardKey.keyV;

                              if (isControlPressed && isVPressed) {
                                debugPrint('[DraggableChatInput] 检测到粘贴快捷键');
                                _handlePaste();
                              }
                            }
                          },
                          child: Row(
                            children: [
                              // 语音按钮
                              GestureDetector(
                                onLongPress: () {
                                  _startRecording();
                                },
                                onLongPressEnd: (details) {
                                  _stopRecording();
                                },
                                onLongPressMoveUpdate: (details) {
                                  // 简化版本，不再使用 _recordStartPosition
                                  final offset = details.offsetFromOrigin;
                                  final distance = offset.distance;
                                  if (distance > 100) {
                                    // 如果移动距离超过100，显示取消提示
                                    if (!_isRecordingCancelled) {
                                      setState(() {
                                        _isRecordingCancelled = true;
                                      });
                                    }
                                  } else {
                                    if (_isRecordingCancelled) {
                                      setState(() {
                                        _isRecordingCancelled = false;
                                      });
                                    }
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.mic,
                                    color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                                    size: 24,
                                  ),
                                ),
                              ),
                              // 文本输入
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  decoration: InputDecoration(
                                    hintText: '输入消息...(支持粘贴图片)',
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
                                  onTap: () {
                                    // 点击输入框时关闭表情和更多选项面板
                                    if (_showEmoji || _showMoreOptions) {
                                      setState(() {
                                        _showEmoji = false;
                                        _showMoreOptions = false;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
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
                _buildOptionItem(Icons.mic, '语音消息', () {
                  setState(() {
                    _isRecording = true;
                    _showMoreOptions = false;
                  });
                  _startRecording();
                }),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    // 监听录音状态
    VoiceRecorder().addRecordingListener(_onRecordingStateChanged);
  }

  @override
  void dispose() {
    _controller.dispose();

    // 移除录音状态监听器
    VoiceRecorder().removeRecordingListener(_onRecordingStateChanged);

    super.dispose();
  }

  // 录音状态变化回调
  void _onRecordingStateChanged(bool isRecording, int duration) {
    setState(() {
      _isRecording = isRecording;
      _recordDuration = duration;
    });
  }

  // 开始录音
  Future<void> _startRecording() async {
    // 请求麦克风权限
    final hasPermission = await VoiceRecorder().requestPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没有麦克风权限'), backgroundColor: Colors.red),
      );
      return;
    }

    // 开始录音
    final result = await VoiceRecorder().startRecording();
    if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始录音失败'), backgroundColor: Colors.red),
      );
    }

    setState(() {
      _isRecordingCancelled = false;
    });
  }

  // 停止录音
  Future<void> _stopRecording() async {
    if (_isRecordingCancelled) {
      // 如果录音已取消，不发送
      await VoiceRecorder().cancelRecording();
      return;
    }

    // 停止录音
    final result = await VoiceRecorder().stopRecording();

    if (result['success'] == true) {
      final filePath = result['path'];
      final duration = result['duration'];

      if (widget.onSendVoiceMessage != null) {
        widget.onSendVoiceMessage!(filePath, duration);
      } else {
        // 直接上传语音消息
        try {
          final response = await Api.uploadVoiceMessage(
            filePath: filePath,
            duration: duration,
          );

          if (response['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('语音消息已发送'), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('发送语音消息失败: ${response['msg']}'), backgroundColor: Colors.red),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送语音消息失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音失败: ${result['msg']}'), backgroundColor: Colors.red),
      );
    }
  }

  // 取消录音
  void _cancelRecording() {
    setState(() {
      _isRecordingCancelled = true;
    });
  }
}
