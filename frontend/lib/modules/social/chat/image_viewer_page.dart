import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import '../../../common/enhanced_file_utils.dart';
import '../../../common/enhanced_file_utils_extension.dart';
import '../../../common/theme_manager.dart';

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String? heroTag; // 可以为null，表示不使用Hero动画
  final List<String>? imageUrls; // 可选的图片列表，用于多图查看
  final int initialIndex; // 初始索引，用于多图查看

  const ImageViewerPage({
    Key? key,
    required this.imageUrl,
    this.heroTag,
    this.imageUrls,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _ImageViewerPageState createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showControls = true;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _imageUrls => widget.imageUrls ?? [widget.imageUrl];

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Future<void> _shareImage(String imageUrl) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String localPath = '';

      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        // 网络图片，下载到本地
        final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
          imageUrl,
          fileType: 'image',
          serverUrl: imageUrl,
        );

        if (result['success'] == true && result['path'] != null) {
          localPath = result['path'];
        } else {
          throw Exception(result['msg'] ?? '下载图片失败');
        }
      } else if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
        // 本地图片，直接使用路径
        localPath = EnhancedFileUtils.getValidFilePath(imageUrl);
      } else {
        throw Exception('不支持的图片路径格式');
      }

      if (localPath.isNotEmpty) {
        // 使用扩展方法分享图片
        final success = await EnhancedFileUtilsExtension.shareFile(localPath, text: '分享图片');
        if (!success) {
          throw Exception('分享图片失败');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片分享成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('分享图片失败：无效的文件路径');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '分享图片失败: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分享图片失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 图片查看器
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                try {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: _getImageProvider(_imageUrls[index]),
                    // 只在初始索引的图片上使用Hero动画，且只在heroTag不为null时使用
                    heroAttributes: (index == widget.initialIndex && widget.heroTag != null)
                        ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                        : null,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3, // 增加最大缩放比例
                    initialScale: PhotoViewComputedScale.contained, // 初始显示完整图片
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('[ImageViewerPage] 加载图片出错: $error');
                      return _buildErrorWidget();
                    },
                    tightMode: true, // 使用紧凑模式，提高性能
                    filterQuality: FilterQuality.high, // 高质量滤镜
                    basePosition: Alignment.center, // 居中显示
                    gestureDetectorBehavior: HitTestBehavior.translucent, // 透明手势检测
                  );
                } catch (e) {
                  debugPrint('[ImageViewerPage] 创建图片查看选项出错: $e');
                  return PhotoViewGalleryPageOptions(
                    imageProvider: AssetImage('assets/images/image_error.png'),
                    errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                  );
                }
              },
              itemCount: _imageUrls.length,
              loadingBuilder: (context, event) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                    ),
                    if (event != null && event.expectedTotalBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          '${(event.cumulativeBytesLoaded / 1024).toStringAsFixed(1)}KB / ${(event.expectedTotalBytes! / 1024).toStringAsFixed(1)}KB',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _scale = 1.0; // 重置缩放比例
                });
              },
              backgroundDecoration: BoxDecoration(color: Colors.black), // 黑色背景
              gaplessPlayback: true, // 无缝播放，提高性能
            ),

            // 顶部控制栏
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  color: Colors.black.withOpacity(0.5),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          '${_currentIndex + 1} / ${_imageUrls.length}',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.save_alt, color: Colors.white),
                        onPressed: _isLoading ? null : () async {
                          try {
                            final result = await EnhancedFileUtilsExtension.saveImageToGallery(_imageUrls[_currentIndex]);
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
                        icon: Icon(Icons.share, color: Colors.white),
                        onPressed: _isLoading ? null : () => _shareImage(_imageUrls[_currentIndex]),
                      ),
                    ],
                  ),
                ),
              ),

            // 加载指示器
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ),

            // 错误消息
            if (_errorMessage.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // 使用CachedNetworkImageProvider，添加错误处理和重试机制
      return CachedNetworkImageProvider(
        imageUrl,
        errorListener: (exception) {
          debugPrint('[ImageViewerPage] 网络图片加载失败: $exception, URL: $imageUrl');

          // 尝试重新下载图片
          Future.delayed(Duration.zero, () async {
            try {
              final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
                imageUrl,
                fileType: 'image',
                serverUrl: imageUrl,
                overwrite: true,
              );

              if (result['success'] == true && result['path'] != null && mounted) {
                setState(() {
                  // 强制刷新
                  _pageController.jumpToPage(_currentIndex);
                });
                debugPrint('[ImageViewerPage] 图片已重新下载并保存到本地: ${result['path']}');
              }
            } catch (e) {
              debugPrint('[ImageViewerPage] 重新下载图片失败: $e');
            }
          });
        },
      );
    } else if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
      // 处理本地文件路径
      final filePath = EnhancedFileUtils.getValidFilePath(imageUrl);
      if (filePath.isEmpty) {
        debugPrint('[ImageViewerPage] 无效的本地文件路径: $imageUrl');
        throw Exception('无效的本地文件路径');
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[ImageViewerPage] 本地文件不存在: $filePath');
        throw Exception('本地文件不存在');
      }

      return FileImage(file);
    } else {
      debugPrint('[ImageViewerPage] 不支持的图片路径格式: $imageUrl');
      throw Exception('不支持的图片路径格式');
    }
  }

  Widget _buildImage() {
    // 处理本地文件路径
    if (widget.imageUrl.startsWith('file://') || widget.imageUrl.startsWith('/')) {
      final filePath = EnhancedFileUtils.getValidFilePath(widget.imageUrl);
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
              final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
                widget.imageUrl,
                fileType: 'image',
                serverUrl: widget.imageUrl,
              );

              if (result['success'] == true && result['path'] != null && mounted) {
                setState(() {
                  // 强制刷新
                });
                debugPrint('[ImageViewerPage] 图片已下载并保存到本地: ${result['path']}');
              } else {
                debugPrint('[ImageViewerPage] 下载图片失败: ${result['msg']}');
              }
            } catch (e) {
              debugPrint('[ImageViewerPage] 下载图片失败: $e');
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
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    // 尝试重新下载图片
                    setState(() {
                      _isLoading = true;
                      _errorMessage = '';
                    });

                    try {
                      final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
                        _imageUrls[_currentIndex],
                        fileType: 'image',
                        overwrite: true,
                      );

                      if (result['success'] == true && result['path'] != null) {
                        setState(() {
                          _isLoading = false;
                          // 刷新页面
                          _pageController.jumpToPage(_currentIndex);
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('图片已重新下载'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        setState(() {
                          _isLoading = false;
                          _errorMessage = '重新下载失败: ${result['msg']}';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        _isLoading = false;
                        _errorMessage = '重新下载失败: $e';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('重新下载'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
