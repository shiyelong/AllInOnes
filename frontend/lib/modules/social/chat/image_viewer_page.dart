import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../common/file_utils.dart';

class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const ImageViewerPage({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded),
            onPressed: () async {
              try {
                final result = await FileUtils.saveImageToGallery(imageUrl);
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
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: _buildImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    // 处理本地文件路径
    if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
      final filePath = FileUtils.getValidFilePath(imageUrl);
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
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) {
          debugPrint('网络图片加载失败: $error, URL: $url');
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
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(
              '图片加载失败',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
