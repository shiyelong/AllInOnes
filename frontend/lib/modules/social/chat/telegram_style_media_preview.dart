import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import '../../../common/theme_manager.dart';
import '../../../common/enhanced_file_utils.dart';

/// Telegram风格的媒体预览和发送组件
class TelegramStyleMediaPreview extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final Function(List<MediaItem> items) onSend;
  final Function() onCancel;
  final bool allowMultiple;
  final bool allowCaption;

  const TelegramStyleMediaPreview({
    Key? key,
    required this.mediaItems,
    required this.onSend,
    required this.onCancel,
    this.allowMultiple = true,
    this.allowCaption = true,
  }) : super(key: key);

  @override
  _TelegramStyleMediaPreviewState createState() => _TelegramStyleMediaPreviewState();
}

class _TelegramStyleMediaPreviewState extends State<TelegramStyleMediaPreview> {
  final TextEditingController _captionController = TextEditingController();
  List<MediaItem> _mediaItems = [];
  int _currentIndex = 0;
  bool _isCompressing = false;

  @override
  void initState() {
    super.initState();
    _mediaItems = List.from(widget.mediaItems);
  }

  @override
  void dispose() {
    _captionController.dispose();
    for (var item in _mediaItems) {
      if (item.type == MediaType.video && item.videoController != null) {
        item.videoController!.dispose();
      }
    }
    super.dispose();
  }

  void _addMoreMedia() async {
    if (!widget.allowMultiple) return;

    final type = _mediaItems.isNotEmpty ? _mediaItems.first.type : null;

    if (type == MediaType.image || type == null) {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          for (var image in images) {
            _mediaItems.add(MediaItem(
              file: File(image.path),
              type: MediaType.image,
              caption: '',
            ));
          }
          _currentIndex = _mediaItems.length - 1;
        });
      }
    } else if (type == MediaType.video) {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        final videoController = VideoPlayerController.file(File(video.path));
        await videoController.initialize();

        setState(() {
          _mediaItems.add(MediaItem(
            file: File(video.path),
            type: MediaType.video,
            caption: '',
            videoController: videoController,
          ));
          _currentIndex = _mediaItems.length - 1;
        });
      }
    }
  }

  void _removeCurrentMedia() {
    if (_mediaItems.isEmpty) return;

    final currentItem = _mediaItems[_currentIndex];
    if (currentItem.type == MediaType.video && currentItem.videoController != null) {
      currentItem.videoController!.dispose();
    }

    setState(() {
      _mediaItems.removeAt(_currentIndex);
      if (_mediaItems.isEmpty) {
        widget.onCancel();
      } else {
        _currentIndex = _currentIndex >= _mediaItems.length ? _mediaItems.length - 1 : _currentIndex;
      }
    });
  }

  void _sendMedia() {
    // 更新当前项的标题
    if (widget.allowCaption && _mediaItems.isNotEmpty) {
      _mediaItems[_currentIndex] = _mediaItems[_currentIndex].copyWith(
        caption: _captionController.text,
      );
    }

    widget.onSend(_mediaItems);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    final isDark = theme.isDark;

    if (_mediaItems.isEmpty) {
      return Container(); // 如果没有媒体项，返回空容器
    }

    final currentItem = _mediaItems[_currentIndex];

    // 确保标题控制器显示当前项的标题
    if (_captionController.text != currentItem.caption) {
      _captionController.text = currentItem.caption;
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        title: Text('发送${_getMediaTypeName(currentItem.type)}'),
        actions: [
          if (widget.allowMultiple)
            IconButton(
              icon: Icon(Icons.add_photo_alternate),
              onPressed: _addMoreMedia,
              tooltip: '添加更多',
            ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _removeCurrentMedia,
            tooltip: '删除',
          ),
        ],
      ),
      body: Column(
        children: [
          // 媒体预览
          Expanded(
            child: _buildMediaPreview(currentItem),
          ),

          // 多媒体指示器
          if (_mediaItems.length > 1)
            Container(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mediaItems.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _currentIndex == index ? theme.primaryColor : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _buildThumbnail(_mediaItems[index]),
                    ),
                  );
                },
              ),
            ),

          // 标题输入
          if (widget.allowCaption)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _captionController,
                decoration: InputDecoration(
                  hintText: '添加标题...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined),
                    onPressed: () {
                      // TODO: 显示表情选择器
                    },
                  ),
                ),
                minLines: 1,
                maxLines: 3,
                onChanged: (value) {
                  // 实时更新当前项的标题
                  _mediaItems[_currentIndex] = _mediaItems[_currentIndex].copyWith(
                    caption: value,
                  );
                },
              ),
            ),

          // 发送按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isCompressing ? null : _sendMedia,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: _isCompressing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('处理中...'),
                      ],
                    )
                  : Text('发送'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(MediaItem item) {
    if (item.type == MediaType.image) {
      return Center(
        child: Image.file(
          item.file,
          fit: BoxFit.contain,
        ),
      );
    } else if (item.type == MediaType.video) {
      if (item.videoController != null && item.videoController!.value.isInitialized) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: item.videoController!.value.aspectRatio,
              child: VideoPlayer(item.videoController!),
            ),
            IconButton(
              icon: Icon(
                item.videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 50,
                color: Colors.white.withOpacity(0.8),
              ),
              onPressed: () {
                setState(() {
                  if (item.videoController!.value.isPlaying) {
                    item.videoController!.pause();
                  } else {
                    item.videoController!.play();
                  }
                });
              },
            ),
          ],
        );
      } else {
        return Center(
          child: CircularProgressIndicator(),
        );
      }
    } else {
      return Center(
        child: Text('不支持的媒体类型'),
      );
    }
  }

  Widget _buildThumbnail(MediaItem item) {
    if (item.type == MediaType.image) {
      return Image.file(
        item.file,
        fit: BoxFit.cover,
      );
    } else if (item.type == MediaType.video) {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (item.videoController != null && item.videoController!.value.isInitialized)
            VideoPlayer(item.videoController!)
          else
            Container(color: Colors.black),
          Icon(
            Icons.play_arrow,
            size: 20,
            color: Colors.white,
          ),
        ],
      );
    } else {
      return Icon(Icons.help_outline);
    }
  }

  String _getMediaTypeName(MediaType type) {
    switch (type) {
      case MediaType.image:
        return '图片';
      case MediaType.video:
        return '视频';
      default:
        return '媒体';
    }
  }
}

enum MediaType {
  image,
  video,
  file,
}

class MediaItem {
  final File file;
  final MediaType type;
  final String caption;
  final VideoPlayerController? videoController;
  final String? thumbnailPath;

  MediaItem({
    required this.file,
    required this.type,
    this.caption = '',
    this.videoController,
    this.thumbnailPath,
  });

  MediaItem copyWith({
    File? file,
    MediaType? type,
    String? caption,
    VideoPlayerController? videoController,
    String? thumbnailPath,
  }) {
    return MediaItem(
      file: file ?? this.file,
      type: type ?? this.type,
      caption: caption ?? this.caption,
      videoController: videoController ?? this.videoController,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  // 转换为可序列化的Map
  Map<String, dynamic> toJson() {
    return {
      'path': file.path,
      'type': type.toString(),
      'caption': caption,
      'thumbnailPath': thumbnailPath,
    };
  }

  // 从Map创建MediaItem
  static MediaItem fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String;
    final typeStr = json['type'] as String;
    final caption = json['caption'] as String? ?? '';
    final thumbnailPath = json['thumbnailPath'] as String?;

    MediaType type;
    if (typeStr.contains('MediaType.image')) {
      type = MediaType.image;
    } else if (typeStr.contains('MediaType.video')) {
      type = MediaType.video;
    } else {
      type = MediaType.file;
    }

    return MediaItem(
      file: File(path),
      type: type,
      caption: caption,
      thumbnailPath: thumbnailPath,
    );
  }
}
