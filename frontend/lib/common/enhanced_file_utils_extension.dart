import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'enhanced_file_utils.dart';

/// EnhancedFileUtils的扩展方法
/// 提供额外的文件操作功能
extension EnhancedFileUtilsExtension on EnhancedFileUtils {
  /// 保存图片到相册
  static Future<bool> saveImageToGallery(String imagePath) async {
    try {
      final validPath = EnhancedFileUtils.getValidFilePath(imagePath);
      if (validPath.isEmpty) return false;

      // 尝试使用image_gallery_saver保存图片
      try {
        final file = File(validPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final result = await ImageGallerySaver.saveImage(
            Uint8List.fromList(bytes),
            quality: 100,
            name: path.basename(validPath),
          );
          return result['isSuccess'] == true;
        }
      } catch (e) {
        debugPrint('[EnhancedFileUtils] 保存图片到相册失败: $e');
      }

      return false;
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 保存图片到相册失败: $e');
      return false;
    }
  }

  /// 打开文件
  static Future<bool> openFile(String filePath) async {
    try {
      final validPath = EnhancedFileUtils.getValidFilePath(filePath);
      if (validPath.isEmpty) {
        return false;
      }

      try {
        final result = await OpenFile.open(validPath);
        return result.type == 'done';
      } catch (e) {
        debugPrint('[EnhancedFileUtils] 打开文件失败: $e');
        return false;
      }
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 打开文件失败: $e');
      return false;
    }
  }

  /// 分享文件
  static Future<bool> shareFile(String filePath, {String? text}) async {
    try {
      final validPath = EnhancedFileUtils.getValidFilePath(filePath);
      if (validPath.isEmpty) {
        return false;
      }

      try {
        await Share.shareFiles([validPath], text: text);
        return true;
      } catch (e) {
        debugPrint('[EnhancedFileUtils] 分享文件失败: $e');
        return false;
      }
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 分享文件失败: $e');
      return false;
    }
  }

  /// 下载网络图片并保存到相册
  static Future<bool> downloadAndSaveImageToGallery(String imageUrl) async {
    try {
      // 下载图片
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        debugPrint('[EnhancedFileUtils] 下载图片失败，状态码: ${response.statusCode}');
        return false;
      }

      // 保存到相册
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(response.bodyBytes),
        quality: 100,
        name: 'image_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result['isSuccess'] == true;
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 下载并保存图片到相册失败: $e');
      return false;
    }
  }

  /// 获取图片缓存路径
  static Future<String> getImageCachePath(String imageUrl) async {
    try {
      // 检查是否已有缓存
      final cachedPath = await EnhancedFileUtils.getLocalPathByUrl(imageUrl);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          return cachedPath;
        }
      }

      // 下载并缓存
      final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced2(
        imageUrl,
        fileType: 'image',
      );

      if (result['success'] == true && result['path'] != null) {
        return result['path'];
      }

      return '';
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 获取图片缓存路径失败: $e');
      return '';
    }
  }

  /// 清理图片缓存
  static Future<void> clearImageCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/images');

      if (await imageDir.exists()) {
        await imageDir.delete(recursive: true);
        await imageDir.create(recursive: true);
        debugPrint('[EnhancedFileUtils] 图片缓存已清理');
      }
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 清理图片缓存失败: $e');
    }
  }
}
