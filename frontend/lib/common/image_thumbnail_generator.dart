import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'enhanced_file_utils.dart';

/// 图片缩略图生成器
/// 用于生成图片的缩略图，支持本地文件和网络URL
class ImageThumbnailGenerator {
  /// 默认缩略图宽度
  static const int defaultThumbnailWidth = 200;

  /// 默认缩略图高度
  static const int defaultThumbnailHeight = 200;

  /// 默认缩略图质量
  static const int defaultQuality = 80;

  /// 缩略图缓存目录名
  static const String thumbnailCacheDirName = 'thumbnails';

  /// 获取缩略图缓存目录
  static Future<Directory> _getThumbnailCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$thumbnailCacheDirName');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// 生成缩略图文件名
  static String _generateThumbnailFileName(String originalPath, int width, int height) {
    final fileName = path.basename(originalPath);
    final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
    final fileExt = path.extension(fileName);

    return '${fileNameWithoutExt}_${width}x${height}$fileExt';
  }

  /// 从本地文件生成缩略图
  /// [imagePath] 原始图片路径
  /// [width] 缩略图宽度
  /// [height] 缩略图高度
  /// [quality] 缩略图质量 (1-100)
  /// 返回缩略图路径
  static Future<String> generateThumbnailFromFile(
    String imagePath, {
    int width = defaultThumbnailWidth,
    int height = defaultThumbnailHeight,
    int quality = defaultQuality,
  }) async {
    try {
      // 验证文件路径
      final validPath = EnhancedFileUtils.getValidFilePath(imagePath);
      if (validPath.isEmpty) {
        throw Exception('无效的图片路径');
      }

      // 检查文件是否存在
      final file = File(validPath);
      if (!await file.exists()) {
        throw Exception('图片文件不存在');
      }

      // 获取缩略图缓存目录
      final cacheDir = await _getThumbnailCacheDir();

      // 生成缩略图文件名
      final thumbnailFileName = _generateThumbnailFileName(validPath, width, height);
      final thumbnailPath = '${cacheDir.path}/$thumbnailFileName';

      // 检查缩略图是否已存在
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        debugPrint('[ImageThumbnailGenerator] 缩略图已存在: $thumbnailPath');
        return thumbnailPath;
      }

      // 读取原始图片
      final bytes = await file.readAsBytes();

      // 使用compute在后台线程处理图片
      final thumbnailBytes = await compute(_resizeImage, {
        'bytes': bytes,
        'width': width,
        'height': height,
        'quality': quality,
      });

      // 保存缩略图
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      debugPrint('[ImageThumbnailGenerator] 缩略图已生成: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      debugPrint('[ImageThumbnailGenerator] 生成缩略图失败: $e');
      return '';
    }
  }

  /// 从网络URL生成缩略图
  /// [imageUrl] 原始图片URL
  /// [width] 缩略图宽度
  /// [height] 缩略图高度
  /// [quality] 缩略图质量 (1-100)
  /// 返回缩略图路径
  static Future<String> generateThumbnailFromUrl(
    String imageUrl, {
    int width = defaultThumbnailWidth,
    int height = defaultThumbnailHeight,
    int quality = defaultQuality,
  }) async {
    try {
      // 验证URL
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        throw Exception('无效的图片URL');
      }

      // 获取缩略图缓存目录
      final cacheDir = await _getThumbnailCacheDir();

      // 生成缩略图文件名
      final urlHash = imageUrl.hashCode.toString();
      final thumbnailFileName = '${urlHash}_${width}x${height}.jpg';
      final thumbnailPath = '${cacheDir.path}/$thumbnailFileName';

      // 检查缩略图是否已存在
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        debugPrint('[ImageThumbnailGenerator] 缩略图已存在: $thumbnailPath');
        return thumbnailPath;
      }

      // 下载原始图片
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('下载图片失败，状态码: ${response.statusCode}');
      }

      // 使用compute在后台线程处理图片
      final thumbnailBytes = await compute(_resizeImage, {
        'bytes': response.bodyBytes,
        'width': width,
        'height': height,
        'quality': quality,
      });

      // 保存缩略图
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      debugPrint('[ImageThumbnailGenerator] 缩略图已生成: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      debugPrint('[ImageThumbnailGenerator] 生成缩略图失败: $e');
      return '';
    }
  }

  /// 从图片路径生成缩略图（自动判断本地文件或网络URL）
  /// [imagePath] 原始图片路径或URL
  /// [width] 缩略图宽度
  /// [height] 缩略图高度
  /// [quality] 缩略图质量 (1-100)
  /// 返回缩略图路径
  static Future<String> generateThumbnail(
    String imagePath, {
    int width = defaultThumbnailWidth,
    int height = defaultThumbnailHeight,
    int quality = defaultQuality,
  }) async {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return generateThumbnailFromUrl(
        imagePath,
        width: width,
        height: height,
        quality: quality,
      );
    } else {
      return generateThumbnailFromFile(
        imagePath,
        width: width,
        height: height,
        quality: quality,
      );
    }
  }

  /// 清理缩略图缓存
  /// 返回删除的文件数量
  static Future<int> clearThumbnailCache() async {
    try {
      final cacheDir = await _getThumbnailCacheDir();
      if (await cacheDir.exists()) {
        // 获取所有缩略图文件
        final files = await cacheDir.list().toList();
        int deletedCount = 0;

        // 逐个删除文件，而不是删除整个目录
        // 这样可以避免在删除过程中有新文件创建导致的问题
        for (final entity in files) {
          if (entity is File) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (e) {
              debugPrint('[ImageThumbnailGenerator] 删除缩略图文件失败: $e');
            }
          }
        }

        debugPrint('[ImageThumbnailGenerator] 缩略图缓存已清理，删除了 $deletedCount 个文件');
        return deletedCount;
      }
      return 0;
    } catch (e) {
      debugPrint('[ImageThumbnailGenerator] 清理缩略图缓存失败: $e');
      return 0;
    }
  }

  /// 获取缩略图缓存大小
  /// 返回缓存大小（字节）
  static Future<int> getThumbnailCacheSize() async {
    try {
      final cacheDir = await _getThumbnailCacheDir();
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        int totalSize = 0;

        for (final entity in files) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }

        return totalSize;
      }
      return 0;
    } catch (e) {
      debugPrint('[ImageThumbnailGenerator] 获取缩略图缓存大小失败: $e');
      return 0;
    }
  }

  /// 获取缩略图缓存文件数量
  static Future<int> getThumbnailCacheCount() async {
    try {
      final cacheDir = await _getThumbnailCacheDir();
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        return files.where((entity) => entity is File).length;
      }
      return 0;
    } catch (e) {
      debugPrint('[ImageThumbnailGenerator] 获取缩略图缓存文件数量失败: $e');
      return 0;
    }
  }

  /// 删除指定图片的所有缩略图
  static Future<bool> deleteThumbnailsForImage(String imagePath) async {
    try {
      // 获取文件名（不含路径）
      final fileName = path.basename(imagePath);
      final fileNameWithoutExt = path.basenameWithoutExtension(fileName);

      // 获取缩略图缓存目录
      final cacheDir = await _getThumbnailCacheDir();
      if (await cacheDir.exists()) {
        // 获取所有缩略图文件
        final files = await cacheDir.list().toList();
        int deletedCount = 0;

        // 查找并删除与指定图片相关的缩略图
        for (final entity in files) {
          if (entity is File) {
            final thumbnailName = path.basename(entity.path);
            // 检查缩略图文件名是否包含原始文件名
            if (thumbnailName.startsWith(fileNameWithoutExt + '_')) {
              try {
                await entity.delete();
                deletedCount++;
              } catch (e) {
                debugPrint('[ImageThumbnailGenerator] 删除缩略图文件失败: $e');
              }
            }
          }
        }

        debugPrint('[ImageThumbnailGenerator] 已删除 $deletedCount 个与 $fileName 相关的缩略图');
        return deletedCount > 0;
      }
      return false;
    } catch (e) {
      debugPrint('[ImageThumbnailGenerator] 删除图片缩略图失败: $e');
      return false;
    }
  }
}

/// 在后台线程中调整图片大小
/// 参数是一个Map，包含以下字段：
/// - bytes: 原始图片字节
/// - width: 目标宽度
/// - height: 目标高度
/// - quality: 目标质量
Uint8List _resizeImage(Map<String, dynamic> params) {
  final bytes = params['bytes'] as Uint8List;
  final width = params['width'] as int;
  final height = params['height'] as int;
  final quality = params['quality'] as int;

  // 解码图片
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('解码图片失败');
  }

  // 调整图片大小
  final resized = img.copyResize(
    image,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );

  // 编码为JPEG
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}
