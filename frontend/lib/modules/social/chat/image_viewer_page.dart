import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../common/file_utils.dart';

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String heroTag;

  const ImageViewerPage({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
  }) : super(key: key);

  @override
  _ImageViewerPageState createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  bool _showControls = true;

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls ? AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded),
            onPressed: () async {
              try {
                final result = await FileUtils.saveImageToGallery(widget.imageUrl);
                if (result) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('图片已保存到相册')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存图片失败')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('保存图片失败: $e')),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('分享功能开发中')),
              );
            },
          ),
        ],
      ) : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: Hero(
            tag: widget.heroTag,
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: _buildImage(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _showControls ? BottomAppBar(
        color: Colors.black.withOpacity(0.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('编辑功能开发中')),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除功能开发中')),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.star_border, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('收藏功能开发中')),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.more_horiz, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('更多功能开发中')),
                );
              },
            ),
          ],
        ),
      ) : null,
    );
  }

  Widget _buildImage() {
    // 处理本地文件路径
    if (widget.imageUrl.startsWith('file://') || widget.imageUrl.startsWith('/')) {
      final filePath = FileUtils.getValidFilePath(widget.imageUrl);
      if (filePath.isNotEmpty) {
        return Image.file(
          File(filePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('本地图片加载失败: $error');
            return _buildErrorWidget();
          },
        );
      } else {
        return _buildErrorWidget();
      }
    }

    // 处理网络URL
    if (widget.imageUrl.startsWith('http://') || widget.imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) {
          debugPrint('网络图片加载失败: $error, URL: $url');

          // 尝试下载图片
          Future.delayed(Duration.zero, () async {
            try {
              final localPath = await FileUtils.downloadAndSaveImage(widget.imageUrl);
              if (localPath.isNotEmpty && mounted) {
                setState(() {
                  // 强制刷新
                });
              }
            } catch (e) {
              debugPrint('下载图片失败: $e');
            }
          });

          return _buildErrorWidget();
        },
        fit: BoxFit.contain,
      );
    }

    // 未知类型的路径
    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white70, size: 60),
            SizedBox(height: 16),
            Text(
              '图片加载失败',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // 强制刷新
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
              child: Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}
