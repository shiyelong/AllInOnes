import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/modules/social/chat/red_packet_detail_page.dart';
import 'package:frontend/modules/social/chat/image_viewer_page.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../common/theme_manager.dart';
import '../../../common/text_sanitizer.dart';
import '../../../common/enhanced_file_utils.dart';

class ChatMessageItem extends StatefulWidget {
  final Map<String, dynamic> message;
  const ChatMessageItem({Key? key, required this.message}) : super(key: key);

  @override
  _ChatMessageItemState createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<ChatMessageItem> {
  late Map<String, dynamic> message;

  @override
  void initState() {
    super.initState();
    message = widget.message;
  }

  // 重试加载图片
  Future<bool> _retryLoadImage(String url) async {
    try {
      // 检查是否是本地文件路径
      if (url.startsWith('file://') || url.startsWith('/')) {
        final filePath = EnhancedFileUtils.getValidFilePath(url);
        return await EnhancedFileUtils.fileExists(filePath);
      }

      // 如果是网络URL，尝试使用不同的缓存策略加载图片
      if (url.startsWith('http://') || url.startsWith('https://')) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            // 如果成功加载，保存到本地以便下次使用
            final localPath = await EnhancedFileUtils.downloadAndSaveImage(url);
            if (localPath.isNotEmpty) {
              // 更新消息中的图片路径
              message['content'] = localPath;
            }
            return true;
          }
          return false;
        } catch (e) {
          debugPrint('网络图片加载失败: $e');
          return false;
        }
      }

      return false;
    } catch (e) {
      debugPrint('重试加载图片失败: $e');
      return false;
    }
  }

  // 获取图片小部件
  Widget _getImageWidget(String imageUrl, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    // 处理本地文件路径
    if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
      final filePath = EnhancedFileUtils.getValidFilePath(imageUrl);
      if (filePath.isNotEmpty) {
        return Image.file(
          File(filePath),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('本地图片加载失败: $error');
            return _buildImageErrorWidget(width ?? 120, height ?? 120);
          },
        );
      } else {
        return _buildImageErrorWidget(width ?? 120, height ?? 120);
      }
    }

    // 处理网络URL
    return FutureBuilder<bool>(
      future: _retryLoadImage(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 加载中显示占位符
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == true) {
          // 如果重试成功，使用更新后的路径
          final updatedUrl = message['content'] ?? imageUrl;
          if (updatedUrl.startsWith('file://') || updatedUrl.startsWith('/')) {
            final filePath = EnhancedFileUtils.getValidFilePath(updatedUrl);
            if (filePath.isNotEmpty) {
              return Image.file(
                File(filePath),
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('更新后的本地图片加载失败: $error');
                  return _buildImageErrorWidget(width ?? 120, height ?? 120);
                },
              );
            }
          }
        }

        // 如果重试失败或者没有更新路径，尝试直接加载网络图片
        return Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('网络图片加载失败: $error');
            return _buildImageErrorWidget(width ?? 120, height ?? 120);
          },
        );
      },
    );
  }

  // 使用 TextSanitizer 清理消息内容

  // 构建图片错误小部件
  Widget _buildImageErrorWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: width > 150 ? 40 : 24),
            SizedBox(height: width > 150 ? 8 : 4),
            Text(
              '图片加载失败',
              style: TextStyle(
                color: Colors.red,
                fontSize: width > 150 ? 16 : 12
              )
            ),
          ],
        ),
      ),
    );
  }

  // 构建图片小部件（用于消息气泡中）
  Widget _buildImageWidget(String imagePath) {
    if (imagePath.isEmpty) {
      return _buildImageErrorWidget(200, 150);
    }

    // 获取图片ID或时间戳作为标识
    final imageId = message['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    // 检查是否是本地文件路径
    if (imagePath.startsWith('file://') || imagePath.startsWith('/')) {
      final filePath = EnhancedFileUtils.getValidFilePath(imagePath);

      return ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 200,
            maxHeight: 250,
          ),
          child: Image.file(
            File(filePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('本地图片加载失败: $error, 路径: $filePath');

              // 尝试从原始URL重新下载
              Future.delayed(Duration.zero, () async {
                final originalUrl = message['original_url'];
                if (originalUrl != null && originalUrl.isNotEmpty &&
                    (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

                  try {
                    final localPath = await EnhancedFileUtils.downloadAndSaveImage(originalUrl);
                    if (localPath.isNotEmpty) {
                      // 更新消息中的图片路径
                      setState(() {
                        message['content'] = localPath;
                      });
                      debugPrint('图片已重新下载并保存到本地: $localPath');
                    }
                  } catch (e) {
                    debugPrint('重新下载图片失败: $e');
                  }
                }
              });

              return _buildImageErrorWidget(200, 150);
            },
          ),
        ),
      );
    }

    // 处理网络URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 200,
            maxHeight: 250,
          ),
          child: CachedNetworkImage(
            imageUrl: imagePath,
            placeholder: (context, url) => Container(
              width: 200,
              height: 150,
              color: Colors.grey[300],
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) {
              debugPrint('网络图片加载失败: $error, URL: $url');

              // 检查是否有服务器URL
              final serverUrl = message['server_url'];
              if (serverUrl != null && serverUrl.isNotEmpty &&
                  serverUrl != url && (serverUrl.startsWith('http://') || serverUrl.startsWith('https://'))) {
                debugPrint('尝试使用服务器URL: $serverUrl');

                // 使用服务器URL重新加载
                Future.delayed(Duration.zero, () {
                  setState(() {
                    message['content'] = serverUrl;
                  });
                });

                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey[300],
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // 尝试下载并保存图片
              Future.delayed(Duration.zero, () async {
                try {
                  final localPath = await EnhancedFileUtils.downloadAndSaveImage(imagePath);
                  if (localPath.isNotEmpty) {
                    // 更新消息中的图片路径
                    setState(() {
                      message['content'] = localPath;
                      message['original_url'] = imagePath;
                      message['server_url'] = imagePath;
                    });
                    debugPrint('图片已下载并保存到本地: $localPath');
                  }
                } catch (e) {
                  debugPrint('下载图片失败: $e');
                }
              });

              return _buildImageErrorWidget(200, 150);
            },
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // 未知类型的路径
    return _buildImageErrorWidget(200, 150);
  }

  // 构建视频错误小部件
  Widget _buildVideoErrorWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white, size: width > 150 ? 40 : 24),
            SizedBox(height: width > 150 ? 8 : 4),
            Text(
              '视频加载失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: width > 150 ? 16 : 12
              )
            ),
          ],
        ),
      ),
    );
  }

  // 显示视频播放器
  void _showVideoPlayer(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_fill, size: 60, color: Colors.white.withOpacity(0.8)),
                    SizedBox(height: 16),
                    Text(
                      '视频播放功能开发中',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      videoUrl.startsWith('file://') || videoUrl.startsWith('/')
                          ? '本地视频: ${EnhancedFileUtils.getFileName(videoUrl)}'
                          : '网络视频',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Persistence.getUserInfo()?.id ?? 0;
    final isMe = message['from_id'] == currentUserId;
    final type = message['type'] ?? 'text';
    final rawContent = message['content'] ?? '';
    // 清理消息内容
    final content = TextSanitizer.sanitize(rawContent);
    final timestamp = message['created_at'] ?? 0;
    final status = message['status'] ?? 1; // 默认为已发送

    // 获取主题颜色
    final theme = ThemeManager.currentTheme;
    final bubbleColor = isMe ? theme.selfMessageBubbleColor : theme.otherMessageBubbleColor;
    final textColor = isMe ? theme.selfMessageTextColor : theme.otherMessageTextColor;

    Widget contentWidget;
    switch (type) {
      case 'image':
        final imagePath = message['content'] ?? '';
        final messageId = message['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

        contentWidget = GestureDetector(
          onTap: () {
            // 点击查看大图
            if (imagePath.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewerPage(
                    imageUrl: imagePath,
                    heroTag: 'image_$messageId',
                  ),
                ),
              );
            }
          },
          child: Hero(
            tag: 'image_$messageId',
            child: _buildImageWidget(imagePath),
          ),
        );
        break;
      case 'video':
        final videoUrl = message['content'] ?? '';
        final thumbnailUrl = message['thumbnail'] ?? 'https://via.placeholder.com/120x120?text=Video';

        contentWidget = GestureDetector(
          onTap: () async {
            // 点击查看视频
            if (videoUrl.isNotEmpty) {
              if (videoUrl.startsWith('file://') || videoUrl.startsWith('/')) {
                // 本地视频，检查是否存在
                final validPath = EnhancedFileUtils.getValidFilePath(videoUrl);
                if (await EnhancedFileUtils.fileExists(validPath)) {
                  // 显示视频播放器
                  _showVideoPlayer(context, validPath);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('视频文件不存在或已被删除')),
                  );
                }
              } else if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
                // 网络视频，尝试下载
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('正在准备视频...')),
                );

                try {
                  final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
                    videoUrl,
                    fileType: 'video',
                    serverUrl: videoUrl
                  );
                  if (result['path']!.isNotEmpty) {
                    // 更新消息中的视频路径
                    setState(() {
                      message['content'] = result['path'];
                      message['original_url'] = videoUrl;
                      message['server_url'] = videoUrl;
                    });

                    // 显示视频播放器
                    _showVideoPlayer(context, result['path']!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('视频加载失败')),
                    );

                    // 显示默认视频播放器
                    _showVideoPlayer(context, videoUrl);
                  }
                } catch (e) {
                  debugPrint('视频下载异常: $e');

                  // 显示默认视频播放器
                  _showVideoPlayer(context, videoUrl);
                }
              } else {
                // 显示默认视频播放器
                _showVideoPlayer(context, videoUrl);
              }
            } else {
              // 没有视频URL，显示提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('视频不可用')),
              );
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _getImageWidget(
                  thumbnailUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow, size: 24, color: Colors.white),
              ),
            ],
          ),
        );
        break;
      case 'file':
        final filePath = message['content'] ?? '';
        final fileName = message['file_name'] ?? message['filename'] ?? FileUtils.getFileName(filePath) ?? '文件';

        // 获取文件大小
        String fileSize = message['filesize'] ?? message['file_size'] ?? '';
        if (fileSize.isEmpty && (filePath.startsWith('file://') || filePath.startsWith('/'))) {
          // 如果没有文件大小信息，尝试从本地文件获取
          final validPath = FileUtils.getValidFilePath(filePath);
          if (validPath.isNotEmpty) {
            try {
              final file = File(validPath);
              if (file.existsSync()) {
                final bytes = file.lengthSync();
                fileSize = FileUtils.formatBytes(bytes);
              }
            } catch (e) {
              debugPrint('获取文件大小失败: $e');
            }
          }
        }

        contentWidget = GestureDetector(
          onTap: () async {
            // 点击查看文件
            if (filePath.isNotEmpty) {
              if (filePath.startsWith('file://') || filePath.startsWith('/')) {
                // 本地文件，检查是否存在
                final validPath = FileUtils.getValidFilePath(filePath);
                if (await FileUtils.fileExists(validPath)) {
                  // 保存文件元数据
                  await EnhancedFileUtils.saveFileMetadata({
                    'path': validPath,
                    'file_name': fileName,
                    'type': 'file',
                    'original_url': message['original_url'] ?? '',
                    'created_at': message['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  });

                  // 显示文件预览或打开文件
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('正在打开文件: $fileName')),
                  );

                  // 尝试打开文件
                  try {
                    final result = await FileUtils.openFile(validPath);
                    if (!result) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('无法打开文件，请使用其他应用打开')),
                      );
                    }
                  } catch (e) {
                    debugPrint('打开文件失败: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('打开文件失败: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('文件不存在，正在尝试恢复...')),
                  );

                  // 尝试从文件元数据中恢复
                  final fileMetadata = await EnhancedFileUtils.getFileMetadataByPath(filePath);
                  if (fileMetadata != null) {
                    // 尝试验证和恢复文件
                    final recoveredPath = await EnhancedFileUtils.verifyAndRecoverFile(fileMetadata);
                    if (recoveredPath.isNotEmpty && await FileUtils.fileExists(recoveredPath)) {
                      setState(() {
                        message['content'] = recoveredPath;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('文件已恢复，正在打开...')),
                      );

                      // 尝试打开恢复的文件
                      try {
                        final result = await FileUtils.openFile(recoveredPath);
                        if (!result) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('无法打开文件，请使用其他应用打开')),
                          );
                        }
                      } catch (e) {
                        debugPrint('打开恢复的文件失败: $e');
                      }
                      return;
                    }
                  }

                  // 如果元数据恢复失败，尝试从原始URL重新下载
                  final originalUrl = message['original_url'];
                  if (originalUrl != null && originalUrl.isNotEmpty &&
                      (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('正在重新下载文件...')),
                    );

                    try {
                      final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
                        originalUrl,
                        customFileName: fileName,
                        fileType: 'file',
                      );

                      if (result['path']!.isNotEmpty) {
                        // 更新消息中的文件路径
                        setState(() {
                          message['content'] = result['path'];
                          message['file_name'] = result['name'];
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('文件已重新下载: ${result['name']}')),
                        );

                        // 尝试打开文件
                        try {
                          final openResult = await FileUtils.openFile(result['path']!);
                          if (!openResult) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('无法打开文件，请使用其他应用打开')),
                            );
                          }
                        } catch (e) {
                          debugPrint('打开下载的文件失败: $e');
                        }
                      }
                    } catch (e) {
                      debugPrint('重新下载文件失败: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('重新下载文件失败: $e')),
                      );
                    }
                  }
                }
              } else if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
                // 网络文件，尝试下载
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('正在下载文件...')),
                );

                try {
                  final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
                    filePath,
                    customFileName: fileName,
                    fileType: 'file',
                  );

                  if (result['path']!.isNotEmpty) {
                    // 更新消息中的文件路径
                    setState(() {
                      message['content'] = result['path'];
                      message['file_name'] = result['name'];
                      message['original_url'] = filePath;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('文件已下载: ${result['name']}')),
                    );

                    // 尝试打开文件
                    try {
                      final openResult = await FileUtils.openFile(result['path']!);
                      if (!openResult) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('无法打开文件，请使用其他应用打开')),
                        );
                      }
                    } catch (e) {
                      debugPrint('打开文件失败: $e');
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('文件下载失败')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('文件下载异常: $e')),
                  );
                }
              }
            }
          },
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, color: textColor, size: 28),
                SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        fileSize.isNotEmpty ? fileSize : '未知大小',
                        style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        filePath.startsWith('file://') || filePath.startsWith('/') ? '点击打开' : '点击下载',
                        style: TextStyle(color: theme.primaryColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case 'redpacket':
        // 解析红包信息
        Map<String, dynamic> redPacketInfo = {};
        try {
          if (message['extra'] != null && message['extra'].isNotEmpty) {
            redPacketInfo = Map<String, dynamic>.from(jsonDecode(message['extra']));
          }
        } catch (e) {
          print('解析红包信息失败: $e');
        }

        final redPacketId = redPacketInfo['red_packet_id'];
        final greeting = redPacketInfo['greeting'] ?? message['content'] ?? '恭喜发财，大吉大利';

        contentWidget = GestureDetector(
          onTap: () {
            if (redPacketId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RedPacketDetailPage(redPacketId: redPacketId),
                ),
              );
            }
          },
          child: Container(
            width: 200,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700, Colors.red.shade500],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.redeem, color: Colors.yellow),
                    SizedBox(width: 8),
                    Text(
                      '红包',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  greeting,
                  style: TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  '点击查看',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
        break;

      case 'transfer':
        // 解析转账信息
        Map<String, dynamic> transferInfo = {};
        try {
          if (message['extra'] != null && message['extra'].isNotEmpty) {
            transferInfo = Map<String, dynamic>.from(jsonDecode(message['extra']));
          }
        } catch (e) {
          print('解析转账信息失败: $e');
        }

        final amount = transferInfo['amount'] ?? 0.0;
        final transferMessage = message['content'] ?? '';

        contentWidget = Container(
          width: 200,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '转账',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '¥${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (transferMessage.isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  transferMessage,
                  style: TextStyle(color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 4),
              Text(
                isMe ? '已转出' : '已收到',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
        break;
      case 'emoji':
        contentWidget = Container(
          padding: EdgeInsets.all(8),
          child: Text(
            content,
            style: TextStyle(fontSize: 32),
          ),
        );
        break;
      default:
        contentWidget = Text(
          content,
          style: TextStyle(fontSize: 16, color: textColor),
        );
    }

    // 根据消息类型构建不同的气泡形状
    BorderRadius bubbleRadius;
    if (isMe) {
      bubbleRadius = BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    } else {
      bubbleRadius = BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

    // 图片消息特殊处理
    final bool isImageMessage = type == 'image';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.isDark ? Colors.grey[700] : theme.primaryColor.withOpacity(0.2),
                    child: Text(
                      TextSanitizer.sanitize(message['from_nickname'] ?? '?').isNotEmpty ?
                        TextSanitizer.sanitize(message['from_nickname'] ?? '?')[0] : '?',
                      style: TextStyle(
                        color: theme.isDark ? Colors.white : theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 发送时间
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                    child: Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ),
                  // 消息气泡
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                    padding: isImageMessage ? EdgeInsets.zero : EdgeInsets.all(type == 'emoji' ? 0 : 12),
                    decoration: BoxDecoration(
                      color: isImageMessage ? Colors.transparent : bubbleColor,
                      borderRadius: bubbleRadius,
                    ),
                    child: contentWidget,
                  ),
                  // 消息ID或时间戳 (仅图片消息显示)
                  if (isImageMessage)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                      child: Text(
                        message['id'] != null ? message['id'].toString() : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  // 消息状态
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: _buildStatusIcon(status),
                    ),
                ],
              ),
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.primaryColor,
                    child: Text(
                      TextSanitizer.sanitize(Persistence.getUserInfo()?.nickname ?? '我').isNotEmpty ?
                        TextSanitizer.sanitize(Persistence.getUserInfo()?.nickname ?? '我')[0] : '我',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(int status) {
    final theme = ThemeManager.currentTheme;

    switch (status) {
      case 0: // 发送中
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.isDark ? Colors.grey[400]! : Colors.grey[600]!,
                ),
              ),
            ),
          ],
        );
      case 1: // 已发送
        return Icon(
          Icons.check,
          size: 14,
          color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
        );
      case 2: // 发送失败
        return Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red[400],
        );
      case 3: // 已送达
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: theme.isDark ? Colors.grey[400] : Colors.grey[600]),
            Icon(Icons.check, size: 14, color: theme.isDark ? Colors.grey[400] : Colors.grey[600]),
          ],
        );
      case 4: // 已读
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: theme.primaryColor),
            Icon(Icons.check, size: 14, color: theme.primaryColor),
          ],
        );
      default:
        return SizedBox.shrink();
    }
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      // 今天
      return DateFormat('HH:mm').format(date);
    } else if (messageDate == yesterday) {
      // 昨天
      return '昨天 ${DateFormat('HH:mm').format(date)}';
    } else if (date.year == now.year) {
      // 今年
      return DateFormat('MM-dd HH:mm').format(date);
    } else {
      // 往年
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    }
  }
}
