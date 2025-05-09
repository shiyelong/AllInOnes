import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enhanced_file_utils.dart';

/// 缩略图管理器
/// 专门处理缩略图的生成、存储和加载
class ThumbnailManager {
  /// 缩略图缓存目录名
  static const String _thumbnailDirName = 'thumbnails';

  /// 缩略图映射表存储键
  static const String _thumbnailMappingKey = 'thumbnail_mapping';

  /// 默认缩略图宽度
  static const int defaultWidth = 200;

  /// 默认缩略图高度
  static const int defaultHeight = 200;

  /// 默认缩略图质量
  static const int defaultQuality = 80;

  /// 获取缩略图缓存目录
  static Future<Directory> getThumbnailDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailDir = Directory('${appDir.path}/$_thumbnailDirName');

      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      return thumbnailDir;
    } catch (e) {
      debugPrint('[ThumbnailManager] 获取缩略图目录失败: $e');
      // 如果获取失败，使用临时目录
      final tempDir = await getTemporaryDirectory();
      final thumbnailDir = Directory('${tempDir.path}/$_thumbnailDirName');

      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      return thumbnailDir;
    }
  }

  /// 生成缩略图
  /// [imagePath] 原始图片路径
  /// [width] 缩略图宽度
  /// [height] 缩略图高度
  /// [quality] 缩略图质量 (1-100)
  /// 返回缩略图路径
  static Future<String> generateThumbnail(
    String imagePath, {
    int width = defaultWidth,
    int height = defaultHeight,
    int quality = defaultQuality,
  }) async {
    try {
      // 验证输入
      if (imagePath.isEmpty) {
        debugPrint('[ThumbnailManager] 图片路径为空');
        return '';
      }

      // 获取有效的文件路径
      final validPath = EnhancedFileUtils.getValidFilePath(imagePath);
      if (validPath.isEmpty) {
        debugPrint('[ThumbnailManager] 无效的图片路径: $imagePath');
        return '';
      }

      // 检查文件是否存在
      final imageFile = File(validPath);
      if (!await imageFile.exists()) {
        debugPrint('[ThumbnailManager] 图片文件不存在: $validPath');
        return '';
      }

      // 生成唯一的缩略图文件名（使用MD5哈希）
      final hash = md5.convert(utf8.encode('$validPath-$width-$height')).toString();
      final thumbnailFileName = '${hash}_${width}x${height}.jpg';

      // 获取缩略图目录
      final thumbnailDir = await getThumbnailDir();
      final thumbnailPath = '${thumbnailDir.path}/$thumbnailFileName';

      // 检查缩略图是否已存在
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        try {
          final thumbnailBytes = await thumbnailFile.readAsBytes();
          if (thumbnailBytes.isNotEmpty) {
            debugPrint('[ThumbnailManager] 缩略图已存在: $thumbnailPath');

            // 保存映射关系
            await _saveThumbnailMapping(validPath, thumbnailPath);

            return thumbnailPath;
          }
        } catch (e) {
          debugPrint('[ThumbnailManager] 读取缩略图失败: $e');
          try {
            await thumbnailFile.delete();
          } catch (deleteError) {
            debugPrint('[ThumbnailManager] 删除损坏的缩略图失败: $deleteError');
          }
        }
      }

      // 生成缩略图
      debugPrint('[ThumbnailManager] 开始生成缩略图: $validPath');
      final result = await FlutterImageCompress.compressAndGetFile(
        validPath,
        thumbnailPath,
        minWidth: width,
        minHeight: height,
        quality: quality,
      );

      if (result == null) {
        debugPrint('[ThumbnailManager] 生成缩略图失败');
        return '';
      }

      // 验证生成的缩略图
      final resultFile = File(thumbnailPath);
      if (await resultFile.exists()) {
        final thumbnailSize = await resultFile.length();
        if (thumbnailSize > 0) {
          debugPrint('[ThumbnailManager] 缩略图生成成功: $thumbnailPath, 大小: ${thumbnailSize}字节');

          // 保存映射关系
          await _saveThumbnailMapping(validPath, thumbnailPath);

          return thumbnailPath;
        } else {
          debugPrint('[ThumbnailManager] 生成的缩略图大小为0');
          await resultFile.delete();
          return '';
        }
      } else {
        debugPrint('[ThumbnailManager] 生成的缩略图文件不存在');
        return '';
      }
    } catch (e) {
      debugPrint('[ThumbnailManager] 生成缩略图异常: $e');
      return '';
    }
  }

  /// 获取缩略图
  /// 如果缩略图已存在，直接返回路径
  /// 如果不存在，生成新的缩略图
  static Future<String> getThumbnail(
    String imagePath, {
    int width = defaultWidth,
    int height = defaultHeight,
    int quality = defaultQuality,
  }) async {
    try {
      // 验证输入
      if (imagePath.isEmpty) {
        debugPrint('[ThumbnailManager] 图片路径为空');
        return '';
      }

      // 获取有效的文件路径
      final validPath = EnhancedFileUtils.getValidFilePath(imagePath);
      if (validPath.isEmpty) {
        debugPrint('[ThumbnailManager] 无效的图片路径: $imagePath');
        return '';
      }

      // 检查是否有缓存的缩略图
      final cachedThumbnail = await _getThumbnailFromMapping(validPath);
      if (cachedThumbnail.isNotEmpty) {
        // 验证缩略图是否存在
        final thumbnailFile = File(cachedThumbnail);
        if (await thumbnailFile.exists()) {
          debugPrint('[ThumbnailManager] 使用缓存的缩略图: $cachedThumbnail');
          return cachedThumbnail;
        }
      }

      // 生成新的缩略图
      return await generateThumbnail(
        validPath,
        width: width,
        height: height,
        quality: quality,
      );
    } catch (e) {
      debugPrint('[ThumbnailManager] 获取缩略图异常: $e');
      return '';
    }
  }

  /// 保存缩略图映射关系
  static Future<void> _saveThumbnailMapping(String originalPath, String thumbnailPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有映射
      final mappingJson = prefs.getString(_thumbnailMappingKey) ?? '{}';
      final mapping = jsonDecode(mappingJson) as Map<String, dynamic>;

      // 更新映射
      mapping[originalPath] = thumbnailPath;

      // 保存更新后的映射
      await prefs.setString(_thumbnailMappingKey, jsonEncode(mapping));
      debugPrint('[ThumbnailManager] 缩略图映射已保存: $originalPath -> $thumbnailPath');
    } catch (e) {
      debugPrint('[ThumbnailManager] 保存缩略图映射失败: $e');
    }
  }

  /// 从映射中获取缩略图路径
  static Future<String> _getThumbnailFromMapping(String originalPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有映射
      final mappingJson = prefs.getString(_thumbnailMappingKey) ?? '{}';
      final mapping = jsonDecode(mappingJson) as Map<String, dynamic>;

      // 查找映射
      return mapping[originalPath]?.toString() ?? '';
    } catch (e) {
      debugPrint('[ThumbnailManager] 获取缩略图映射失败: $e');
      return '';
    }
  }

  /// 清理无效的缩略图
  static Future<void> cleanupInvalidThumbnails() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有映射
      final mappingJson = prefs.getString(_thumbnailMappingKey) ?? '{}';
      final mapping = jsonDecode(mappingJson) as Map<String, dynamic>;

      // 新的有效映射
      final validMapping = <String, String>{};

      // 检查每个映射
      for (final entry in mapping.entries) {
        final originalPath = entry.key;
        final thumbnailPath = entry.value.toString();

        // 检查原始文件是否存在
        final originalFile = File(originalPath);
        if (!await originalFile.exists()) {
          debugPrint('[ThumbnailManager] 原始文件不存在，删除映射: $originalPath');
          continue;
        }

        // 检查缩略图是否存在
        final thumbnailFile = File(thumbnailPath);
        if (!await thumbnailFile.exists()) {
          debugPrint('[ThumbnailManager] 缩略图不存在，删除映射: $thumbnailPath');
          continue;
        }

        // 保留有效的映射
        validMapping[originalPath] = thumbnailPath;
      }

      // 保存有效的映射
      await prefs.setString(_thumbnailMappingKey, jsonEncode(validMapping));
      debugPrint('[ThumbnailManager] 清理完成，有效映射数量: ${validMapping.length}');
    } catch (e) {
      debugPrint('[ThumbnailManager] 清理无效缩略图失败: $e');
    }
  }

  /// 生成图片缩略图（兼容旧版本）
  static Future<String> generateImageThumbnail(String imagePath) async {
    return await generateThumbnail(
      imagePath,
      width: defaultWidth,
      height: defaultHeight,
      quality: defaultQuality,
    );
  }

  /// 生成视频缩略图（兼容旧版本）
  static Future<String> generateVideoThumbnail(String videoPath) async {
    try {
      // 这里简单地调用图片缩略图生成方法，实际上应该使用视频缩略图生成库
      // 但为了兼容性，我们先这样处理
      return await generateThumbnail(
        videoPath,
        width: defaultWidth,
        height: defaultHeight,
        quality: defaultQuality,
      );
    } catch (e) {
      debugPrint('[ThumbnailManager] 生成视频缩略图异常: $e');
      return '';
    }
  }
}
