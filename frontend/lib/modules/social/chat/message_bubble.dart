import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/common/enhanced_file_utils.dart';
import 'package:frontend/common/enhanced_file_utils_extension.dart';
import 'package:frontend/common/image_thumbnail_generator.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/modules/social/chat/image_viewer_page.dart';
import 'package:frontend/widgets/app_avatar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showAvatar;
  final bool showName;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onRetry; // 重试回调
  final VoidCallback? onRecall; // 撤回回调
  final Function(String)? onForward; // 转发回调
  final bool isRead; // 是否已读

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.showName = false,
    this.onLongPress,
    this.onTap,
    this.onRetry,
    this.onRecall,
    this.onForward,
    this.isRead = false,
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showMenu = false;

  // 显示消息操作菜单
  void _showMessageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isMe) ...[
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('撤回消息'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onRecall != null) {
                    widget.onRecall!();
                  }
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.forward, color: ThemeManager.currentTheme.primaryColor),
              title: Text('转发消息'),
              onTap: () {
                Navigator.pop(context);
                if (widget.onForward != null) {
                  final messageId = widget.message['id']?.toString() ?? '';
                  if (messageId.isNotEmpty) {
                    widget.onForward!(messageId);
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: ThemeManager.currentTheme.primaryColor),
              title: Text('复制消息'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final content = widget.message['content']?.toString() ?? '';
                  await Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('消息已复制到剪贴板')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('复制消息失败: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 显示图片上下文菜单
  void _showImageContextMenu(BuildContext context, String imagePath) {
    final isLocalPath = imagePath.startsWith('/');

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: ThemeManager.currentTheme.primaryColor),
              title: Text('查看图片'),
              onTap: () {
                Navigator.pop(context);
                // 查看大图，不使用Hero动画，因为这里不需要动画效果
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageViewerPage(
                      imageUrl: imagePath,
                      heroTag: null, // 不使用Hero动画
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.save_alt, color: ThemeManager.currentTheme.primaryColor),
              title: Text('保存图片'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  // 保存图片到相册
                  if (isLocalPath) {
                    // 本地图片直接保存
                    final result = await EnhancedFileUtilsExtension.saveImageToGallery(imagePath);
                    if (result) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('图片已保存到相册')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('保存图片失败')),
                      );
                    }
                  } else {
                    // 网络图片先下载再保存
                    final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
                      imagePath,
                      fileType: 'image',
                    );

                    if (result['success'] == true && result['path'] != null) {
                      final savedResult = await EnhancedFileUtilsExtension.saveImageToGallery(result['path']);
                      if (savedResult) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('图片已保存到相册')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('保存图片失败')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('下载图片失败')),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存图片失败: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: ThemeManager.currentTheme.primaryColor),
              title: Text('分享图片'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  String localPath = imagePath;

                  // 如果是网络图片，先下载
                  if (!isLocalPath) {
                    final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
                      imagePath,
                      fileType: 'image',
                    );

                    if (result['success'] == true && result['path'] != null) {
                      localPath = result['path'];
                    } else {
                      throw Exception('下载图片失败');
                    }
                  }

                  // 分享图片
                  final success = await EnhancedFileUtilsExtension.shareFile(localPath, text: '分享图片');
                  if (!success) {
                    throw Exception('分享图片失败');
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('图片分享成功')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('分享图片失败: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: ThemeManager.currentTheme.primaryColor),
              title: Text('复制图片'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  // 复制图片到剪贴板
                  // 注意：Flutter目前不支持直接复制图片到剪贴板，只能复制文本
                  // 这里我们复制图片路径
                  await Clipboard.setData(ClipboardData(text: imagePath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('图片路径已复制到剪贴板')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('复制图片失败: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 生成缩略图
  Future<void> _generateThumbnail(String imagePath) async {
    if (!imagePath.startsWith('/')) return;

    try {
      final thumbnailPath = await ImageThumbnailGenerator.generateThumbnail(
        imagePath,
        width: 200,
        height: 200,
        quality: 80,
      );

      if (thumbnailPath.isNotEmpty && mounted) {
        // 更新消息中的缩略图路径
        if (widget.message['extra'] != null && widget.message['extra'] is String) {
          try {
            final extraData = jsonDecode(widget.message['extra']);
            extraData['thumbnail'] = thumbnailPath;
            widget.message['extra'] = jsonEncode(extraData);
          } catch (e) {
            debugPrint('更新extra数据失败: $e');
          }
        } else {
          widget.message['thumbnail'] = thumbnailPath;
        }

        // 强制刷新
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('生成缩略图失败: $e');
    }
  }

  // 下载图片
  Future<void> _downloadImage(String imageUrl) async {
    if (imageUrl.startsWith('/')) return;

    try {
      final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
        imageUrl,
        fileType: 'image',
      );

      if (result['success'] == true && result['path'] != null && mounted) {
        // 生成缩略图
        final thumbnailPath = await ImageThumbnailGenerator.generateThumbnail(
          result['path'],
          width: 200,
          height: 200,
          quality: 80,
        );

        if (thumbnailPath.isNotEmpty && mounted) {
          // 更新消息中的缩略图路径
          if (widget.message['extra'] != null && widget.message['extra'] is String) {
            try {
              final extraData = jsonDecode(widget.message['extra']);
              extraData['thumbnail'] = thumbnailPath;
              extraData['original'] = result['path'];
              widget.message['extra'] = jsonEncode(extraData);
            } catch (e) {
              debugPrint('更新extra数据失败: $e');
            }
          } else {
            widget.message['thumbnail'] = thumbnailPath;
            widget.message['local_path'] = result['path'];
          }

          // 强制刷新
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('下载图片失败: $e');
    }
  }

  // 构建图片组件
  Widget _buildImageWidget(String displayPath, bool isLocalPath, String originalPath, {String? heroTag}) {
    Widget imageWidget = isLocalPath
        ? Image.file(
            File(displayPath),
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('加载本地图片失败: $error');
              // 如果缩略图加载失败，尝试生成新的缩略图
              _generateThumbnail(originalPath);
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                  ),
                ),
              );
            },
          )
        : Image.network(
            displayPath,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('加载网络图片失败: $error');
              // 如果网络图片加载失败，尝试下载
              _downloadImage(displayPath);
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                  ),
                ),
              );
            },
          );

    // 如果提供了heroTag，使用Hero包装图片
    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag,
        child: imageWidget,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageWidget,
    );
  }

  // 构建消息内容
  Widget _buildMessageContent(BuildContext context, String type, String content) {
    switch (type) {
      case 'text':
        return Text(
          content,
          style: TextStyle(
            color: widget.isMe ? Colors.white : Colors.black,
          ),
        );
      case 'image':
        // 检查是否有缩略图
        String? thumbnailPath;
        String originalPath = content;

        try {
          if (widget.message['extra'] != null && widget.message['extra'] is String) {
            final extraData = jsonDecode(widget.message['extra']);
            thumbnailPath = extraData['thumbnail'];
            originalPath = extraData['original'] ?? content;
          } else if (widget.message['thumbnail'] != null) {
            thumbnailPath = widget.message['thumbnail'].toString();
          }
        } catch (e) {
          debugPrint('解析extra数据失败: $e');
        }

        // 优先使用缩略图，如果没有则使用原图
        final displayPath = thumbnailPath ?? content;
        final isLocalPath = displayPath.startsWith('/');

        // 生成唯一的Hero标签 - 使用消息ID确保唯一性
        final heroTag = 'image_${widget.message['id'] ?? DateTime.now().millisecondsSinceEpoch}';

        return GestureDetector(
          onTap: () {
            // 查看大图，使用专用的图片查看器
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerPage(
                  imageUrl: originalPath,
                  heroTag: heroTag,
                ),
              ),
            );
          },
          onLongPress: () {
            // 显示上下文菜单
            _showImageContextMenu(context, originalPath);
          },
          child: _buildImageWidget(displayPath, isLocalPath, originalPath, heroTag: heroTag),
        );
      case 'file':
        final fileName = widget.message['extra']?['file_name'] ?? '文件';
        final fileSize = widget.message['extra']?['file_size'] ?? 0;
        final fileSizeStr = _formatFileSize(fileSize);

        return Container(
          width: 200,
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: widget.isMe ? Colors.white : Colors.blue,
                size: 40,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        color: widget.isMe ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      fileSizeStr,
                      style: TextStyle(
                        color: widget.isMe ? Colors.white70 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'location':
        return Container(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on,
                color: widget.isMe ? Colors.white : Colors.red,
              ),
              SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      default:
        return Text(
          content,
          style: TextStyle(
            color: widget.isMe ? Colors.white : Colors.black,
          ),
        );
    }
  }

  // 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    final messageContent = widget.message['content'] ?? '';
    final messageType = widget.message['type'] ?? 'text';
    final timestamp = widget.message['created_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(widget.message['created_at'] * 1000)
        : DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(timestamp);
    final senderName = widget.message['sender']?['nickname'] ?? '未知用户';
    final senderAvatar = widget.message['sender']?['avatar'];

    // 消息状态：0=发送中，1=已发送，2=发送失败
    final messageStatus = widget.message['status'] ?? 1;

    return GestureDetector(
      onLongPress: () {
        // 显示消息操作菜单
        _showMessageMenu(context);

        // 调用外部长按回调
        if (widget.onLongPress != null) {
          widget.onLongPress!();
        }
      },
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isMe && widget.showAvatar) ...[
              AppAvatar(
                name: senderName,
                imageUrl: senderAvatar,
                size: 36,
              ),
              SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (widget.showName && !widget.isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.isMe) ...[
                        // 消息状态指示器
                        if (messageStatus == 0)
                          Container(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
                          )
                        else if (messageStatus == 1)
                          widget.isRead
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.done_all,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ],
                                )
                              : Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green,
                                )
                        else if (messageStatus == 2)
                          GestureDetector(
                            onTap: widget.onRetry,
                            child: Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                        SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isMe ? theme.primaryColor : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _buildMessageContent(context, messageType, messageContent),
                        ),
                      ),
                      if (!widget.isMe) ...[
                        SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (widget.isMe && widget.showAvatar) ...[
              SizedBox(width: 8),
              AppAvatar(
                name: 'Me',
                imageUrl: widget.message['sender']?['avatar'],
                size: 36,
              ),
            ],
          ],
        ),
      ),
    );
  }
}