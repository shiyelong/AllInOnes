import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:frontend/common/enhanced_file_utils.dart';

/// 增强版缩略图生成器
/// 用于生成图片的缩略图，支持本地文件和网络URL
/// 包含更健壮的错误处理和重试机制
class EnhancedThumbnailGenerator {
  /// 默认缩略图宽度
  static const int defaultThumbnailWidth = 200;

  /// 默认缩略图高度
  static const int defaultThumbnailHeight = 200;

  /// 默认缩略图质量
  static const int defaultQuality = 80;

  /// 缩略图缓存目录名
  static const String thumbnailCacheDirName = 'enhanced_thumbnails';

  /// 最大重试次数
  static const int maxRetries = 3;

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
  /// 使用MD5哈希确保唯一性和一致性
  static String _generateThumbnailFileName(String originalPath, int width, int height) {
    // 提取文件名和扩展名
    final fileName = path.basename(originalPath);

    // 创建哈希 - 使用完整路径生成哈希，确保唯一性
    final hash = md5.convert(utf8.encode('$originalPath-$width-$height')).toString();

    // 返回格式化的文件名 - 只使用哈希，避免文件名中的特殊字符
    return '${hash}_${width}x${height}.jpg';
  }

  /// 从本地文件生成缩略图
  /// [imagePath] 原始图片路径
  /// [width] 缩略图宽度
  /// [height] 缩略图高度
  /// [quality] 缩略图质量 (1-100)
  /// 返回缩略图路径
  static Future<String> generateFromFile(
    String imagePath, {
    int width = defaultThumbnailWidth,
    int height = defaultThumbnailHeight,
    int quality = defaultQuality,
    int retryCount = 0,
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
        throw Exception('图片文件不存在: $validPath');
      }

      // 获取缩略图缓存目录
      final cacheDir = await _getThumbnailCacheDir();

      // 生成缩略图文件名
      final thumbnailFileName = _generateThumbnailFileName(validPath, width, height);
      final thumbnailPath = '${cacheDir.path}/$thumbnailFileName';

      // 检查缩略图是否已存在
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        // 验证缩略图文件是否有效
        try {
          final thumbnailBytes = await thumbnailFile.readAsBytes();
          if (thumbnailBytes.isNotEmpty) {
            debugPrint('[EnhancedThumbnailGenerator] 缩略图已存在且有效: $thumbnailPath');
            return thumbnailPath;
          } else {
            // 缩略图文件存在但为空，删除并重新生成
            await thumbnailFile.delete();
          }
        } catch (e) {
          // 缩略图文件存在但无法读取，删除并重新生成
          debugPrint('[EnhancedThumbnailGenerator] 缩略图文件损坏，将重新生成: $e');
          try {
            await thumbnailFile.delete();
          } catch (deleteError) {
            debugPrint('[EnhancedThumbnailGenerator] 删除损坏的缩略图失败: $deleteError');
          }
        }
      }

      // 读取原始图片
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('图片文件为空');
      }

      // 使用compute在后台线程处理图片
      final thumbnailBytes = await compute(_resizeImage, {
        'bytes': bytes,
        'width': width,
        'height': height,
        'quality': quality,
      });

      // 保存缩略图
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      debugPrint('[EnhancedThumbnailGenerator] 缩略图已生成: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      debugPrint('[EnhancedThumbnailGenerator] 生成缩略图失败: $e');

      // 重试逻辑
      if (retryCount < maxRetries) {
        debugPrint('[EnhancedThumbnailGenerator] 尝试重新生成缩略图 (${retryCount + 1}/$maxRetries)');
        return generateFromFile(
          imagePath,
          width: width,
          height: height,
          quality: quality,
          retryCount: retryCount + 1,
        );
      }

      return '';
    }
  }

  /// 从网络URL生成缩略图
  /// [imageUrl] 原始图片URL
  /// [width] 缩略图宽度
  /// [height] 缩略图高度
  /// [quality] 缩略图质量 (1-100)
  /// 返回缩略图路径
  static Future<String> generateFromUrl(
    String imageUrl, {
    int width = defaultThumbnailWidth,
    int height = defaultThumbnailHeight,
    int quality = defaultQuality,
    int retryCount = 0,
  }) async {
    try {
      // 验证URL
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        throw Exception('无效的图片URL');
      }

      // 获取缩略图缓存目录
      final cacheDir = await _getThumbnailCacheDir();

      // 生成缩略图文件名 - 使用完整URL生成哈希
      final urlHash = md5.convert(utf8.encode(imageUrl)).toString();
      final thumbnailFileName = 'url_${urlHash}_${width}x${height}.jpg';
      final thumbnailPath = '${cacheDir.path}/$thumbnailFileName';

      // 检查缩略图是否已存在
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        // 验证缩略图文件是否有效
        try {
          final thumbnailBytes = await thumbnailFile.readAsBytes();
          if (thumbnailBytes.isNotEmpty) {
            debugPrint('[EnhancedThumbnailGenerator] 缩略图已存在且有效: $thumbnailPath');
            return thumbnailPath;
          } else {
            // 缩略图文件存在但为空，删除并重新生成
            await thumbnailFile.delete();
          }
        } catch (e) {
          // 缩略图文件存在但无法读取，删除并重新生成
          debugPrint('[EnhancedThumbnailGenerator] 缩略图文件损坏，将重新生成: $e');
          try {
            await thumbnailFile.delete();
          } catch (deleteError) {
            debugPrint('[EnhancedThumbnailGenerator] 删除损坏的缩略图失败: $deleteError');
          }
        }
      }

      // 下载原始图片
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('下载图片失败，状态码: ${response.statusCode}');
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('下载的图片为空');
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

      debugPrint('[EnhancedThumbnailGenerator] 缩略图已生成: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      debugPrint('[EnhancedThumbnailGenerator] 生成缩略图失败: $e');

      // 重试逻辑
      if (retryCount < maxRetries) {
        debugPrint('[EnhancedThumbnailGenerator] 尝试重新生成缩略图 (${retryCount + 1}/$maxRetries)');
        return generateFromUrl(
          imageUrl,
          width: width,
          height: height,
          quality: quality,
          retryCount: retryCount + 1,
        );
      }

      return '';
    }
  }

  /// 从图片路径生成缩略图（自动判断本地文件或网络URL）
  /// [imagePath] 原始图片路径或URL
  /// [width] 缩略图宽度
  /// [height] 缩略图高度
  /// [quality] 缩略图质量 (1-100)
  /// 返回缩略图路径
  static Future<String> generate(
    String imagePath, {
    int width = defaultThumbnailWidth,
    int height = defaultThumbnailHeight,
    int quality = defaultQuality,
  }) async {
    try {
      // 验证输入
      if (imagePath.isEmpty) {
        debugPrint('[EnhancedThumbnailGenerator] 图片路径为空');
        return '';
      }

      // 获取缩略图目录
      final cacheDir = await _getThumbnailCacheDir();

      // 生成缩略图文件名 - 使用完整路径生成哈希
      final hash = md5.convert(utf8.encode('$imagePath-$width-$height')).toString();
      final thumbnailFileName = '${hash}_${width}x${height}.jpg';
      final thumbnailPath = '${cacheDir.path}/$thumbnailFileName';

      // 检查缩略图是否已存在
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        try {
          final thumbnailBytes = await thumbnailFile.readAsBytes();
          if (thumbnailBytes.isNotEmpty) {
            debugPrint('[EnhancedThumbnailGenerator] 缩略图已存在且有效: $thumbnailPath');
            return thumbnailPath;
          }
        } catch (e) {
          debugPrint('[EnhancedThumbnailGenerator] 读取缩略图失败: $e');
          try {
            await thumbnailFile.delete();
          } catch (deleteError) {
            debugPrint('[EnhancedThumbnailGenerator] 删除损坏的缩略图失败: $deleteError');
          }
        }
      }

      // 根据路径类型生成缩略图
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return generateFromUrl(
          imagePath,
          width: width,
          height: height,
          quality: quality,
        );
      } else {
        return generateFromFile(
          imagePath,
          width: width,
          height: height,
          quality: quality,
        );
      }
    } catch (e) {
      debugPrint('[EnhancedThumbnailGenerator] 生成缩略图失败: $e');
      return '';
    }
  }

  /// 清理缩略图缓存
  static Future<int> clearCache() async {
    try {
      final cacheDir = await _getThumbnailCacheDir();
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        int deletedCount = 0;

        for (final entity in files) {
          if (entity is File) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (e) {
              debugPrint('[EnhancedThumbnailGenerator] 删除缩略图文件失败: $e');
            }
          }
        }

        debugPrint('[EnhancedThumbnailGenerator] 缩略图缓存已清理，删除了 $deletedCount 个文件');
        return deletedCount;
      }
      return 0;
    } catch (e) {
      debugPrint('[EnhancedThumbnailGenerator] 清理缩略图缓存失败: $e');
      return 0;
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

  try {
    // 解码图片
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('解码图片失败');
    }

    // 计算缩放比例，保持宽高比
    final double widthRatio = width / image.width;
    final double heightRatio = height / image.height;
    final double ratio = min(widthRatio, heightRatio);

    final int newWidth = (image.width * ratio).round();
    final int newHeight = (image.height * ratio).round();

    // 调整图片大小
    final resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.average,
    );

    // 编码为JPEG
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  } catch (e) {
    // 如果处理失败，返回原始图片
    debugPrint('调整图片大小失败: $e，返回原始图片');
    return bytes;
  }
}
