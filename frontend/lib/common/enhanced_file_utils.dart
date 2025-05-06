import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
/// 增强版文件工具类，用于处理文件的持久化和恢复
class EnhancedFileUtils {

  /// 文件元数据存储键
  static const String _fileMetadataKey = 'file_metadata';

  /// 将本地文件路径转换为可用于Flutter的URI
  ///
  /// 处理不同平台的文件路径格式，确保它们可以被Flutter正确加载
  static String getValidFilePath(String? filePath) {
    if (filePath == null || filePath.isEmpty) {
      return '';
    }

    try {
      // 如果已经是有效的URI格式，直接返回
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        return filePath;
      }

      // 处理file:///开头的URI
      if (filePath.startsWith('file:///')) {
        // 在macOS和iOS上，确保路径格式正确
        if (Platform.isMacOS || Platform.isIOS) {
          final file = File(Uri.parse(filePath).toFilePath());
          if (file.existsSync()) {
            return file.path;
          }
        }

        // 在其他平台上尝试直接使用
        return filePath;
      }

      // 处理普通文件路径
      final file = File(filePath);
      if (file.existsSync()) {
        // 返回标准化的路径
        return file.path;
      }

      // 如果文件不存在，返回空字符串
      debugPrint('文件不存在: $filePath');
      return '';
    } catch (e) {
      debugPrint('处理文件路径出错: $e');
      return '';
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return false;
    }

    try {
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        // 网络文件，假设存在
        return true;
      }

      // 处理file:///开头的URI
      if (filePath.startsWith('file:///')) {
        final file = File(Uri.parse(filePath).toFilePath());
        return await file.exists();
      }

      // 普通文件路径
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('检查文件是否存在出错: $e');
      return false;
    }
  }

  /// 获取应用文档目录
  static Future<Directory> getAppDirectory() async {
    try {
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();

      // 创建媒体文件目录
      final mediaDir = Directory('${appDir.path}/media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      return mediaDir;
    } catch (e) {
      debugPrint('获取应用目录出错: $e');
      // 如果出错，返回临时目录
      return await getTemporaryDirectory();
    }
  }

  /// 下载并保存文件
  /// 返回保存后的文件路径和文件名
  static Future<Map<String, String>> downloadAndSaveFile(String url) async {
    try {
      // 创建HTTP客户端
      final client = http.Client();

      try {
        // 发送GET请求
        final response = await client.get(Uri.parse(url));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // 获取文件名
          String fileName = '';

          // 尝试从URL中提取文件名
          final uri = Uri.parse(url);
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            fileName = pathSegments.last;
          }

          // 如果无法从URL中提取文件名，生成一个随机文件名
          if (fileName.isEmpty) {
            final uuid = Uuid().v4();
            fileName = '$uuid.dat';
          }

          // 获取应用目录
          final mediaDir = await getAppDirectory();

          // 保存文件
          final filePath = '${mediaDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          debugPrint('文件已下载并保存到: $filePath');
          return {'path': filePath, 'name': fileName};
        } else {
          debugPrint('下载文件失败，状态码: ${response.statusCode}');
          return {'path': '', 'name': ''};
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('下载文件出错: $e');
      return {'path': '', 'name': ''};
    }
  }

  /// 格式化字节大小
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    final i = (log(bytes) / log(1024)).floor();

    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  /// 保存文件元数据
  /// 用于在应用重启后恢复文件信息
  static Future<void> saveFileMetadata(Map<String, dynamic> fileInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有元数据
      final metadataJson = prefs.getString(_fileMetadataKey) ?? '{}';
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      // 生成唯一ID作为键
      final fileId = fileInfo['id'] ?? Uuid().v4();

      // 更新元数据
      metadata[fileId] = {
        'id': fileId,
        'path': fileInfo['path'] ?? fileInfo['content'],
        'name': fileInfo['file_name'] ?? fileInfo['filename'] ?? path.basename(fileInfo['path'] ?? fileInfo['content'] ?? ''),
        'size': fileInfo['file_size'] ?? fileInfo['filesize'] ?? '',
        'type': fileInfo['type'] ?? 'file',
        'original_url': fileInfo['original_url'] ?? '',
        'created_at': fileInfo['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      // 保存更新后的元数据
      await prefs.setString(_fileMetadataKey, jsonEncode(metadata));
      debugPrint('[EnhancedFileUtils] 文件元数据已保存: $fileId');
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 保存文件元数据失败: $e');
    }
  }

  /// 获取文件元数据
  /// 返回所有已保存的文件元数据
  static Future<Map<String, dynamic>> getFileMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString(_fileMetadataKey) ?? '{}';
      return jsonDecode(metadataJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 获取文件元数据失败: $e');
      return {};
    }
  }

  /// 获取文件元数据
  /// 根据文件路径获取元数据
  static Future<Map<String, dynamic>?> getFileMetadataByPath(String filePath) async {
    try {
      final metadata = await getFileMetadata();

      // 查找匹配的文件元数据
      for (var entry in metadata.entries) {
        final fileInfo = entry.value as Map<String, dynamic>;
        if (fileInfo['path'] == filePath) {
          return fileInfo;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 根据路径获取文件元数据失败: $e');
      return null;
    }
  }

  /// 删除文件元数据
  /// 根据文件ID删除元数据
  static Future<void> deleteFileMetadata(String fileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString(_fileMetadataKey) ?? '{}';
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      if (metadata.containsKey(fileId)) {
        metadata.remove(fileId);
        await prefs.setString(_fileMetadataKey, jsonEncode(metadata));
        debugPrint('[EnhancedFileUtils] 文件元数据已删除: $fileId');
      }
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 删除文件元数据失败: $e');
    }
  }

  /// 验证文件是否存在
  /// 如果文件不存在，尝试从原始URL重新下载
  static Future<String> verifyAndRecoverFile(Map<String, dynamic> fileInfo) async {
    final filePath = fileInfo['path'] ?? fileInfo['content'] ?? '';
    if (filePath.isEmpty) return '';

    // 检查文件是否存在
    if (filePath.startsWith('file://') || filePath.startsWith('/')) {
      final validPath = getValidFilePath(filePath);
      if (await fileExists(validPath)) {
        return validPath;
      }

      // 文件不存在，尝试从原始URL重新下载
      final originalUrl = fileInfo['original_url'];
      if (originalUrl != null && originalUrl.isNotEmpty &&
          (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

        debugPrint('[EnhancedFileUtils] 文件不存在，尝试从原始URL重新下载: $originalUrl');

        try {
          final result = await downloadAndSaveFile(originalUrl);
          if (result['path']!.isNotEmpty) {
            // 更新文件元数据
            fileInfo['path'] = result['path'];
            await saveFileMetadata(fileInfo);

            debugPrint('[EnhancedFileUtils] 文件已重新下载: ${result['path']}');
            return result['path']!;
          }
        } catch (e) {
          debugPrint('[EnhancedFileUtils] 重新下载文件失败: $e');
        }
      }

      // 尝试从服务器URL重新下载
      final serverUrl = fileInfo['server_url'];
      if (serverUrl != null && serverUrl.isNotEmpty &&
          (serverUrl.startsWith('http://') || serverUrl.startsWith('https://'))) {

        debugPrint('[EnhancedFileUtils] 尝试从服务器URL重新下载: $serverUrl');

        try {
          final result = await downloadAndSaveFile(serverUrl);
          if (result['path']!.isNotEmpty) {
            // 更新文件元数据
            fileInfo['path'] = result['path'];
            await saveFileMetadata(fileInfo);

            debugPrint('[EnhancedFileUtils] 文件已从服务器URL重新下载: ${result['path']}');
            return result['path']!;
          }
        } catch (e) {
          debugPrint('[EnhancedFileUtils] 从服务器URL重新下载文件失败: $e');
        }
      }
    }

    return filePath;
  }

  /// 增强版下载并保存文件
  /// 不仅下载文件，还保存元数据
  static Future<Map<String, String>> downloadAndSaveFileEnhanced(
    String fileUrl, {
    String? customFileName,
    String? fileType,
    String? serverUrl,
  }) async {
    try {
      // 下载文件
      final result = await downloadAndSaveFile(fileUrl);
      if (result['path']!.isNotEmpty) {
        // 保存文件元数据
        await saveFileMetadata({
          'path': result['path'],
          'file_name': customFileName ?? result['name'],
          'type': fileType ?? 'file',
          'original_url': fileUrl,
          'server_url': serverUrl ?? fileUrl,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });

        debugPrint('[EnhancedFileUtils] 文件已下载并保存元数据: ${result['path']}');
      }

      return result;
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 下载并保存文件失败: $e');
      return {'path': '', 'name': ''};
    }
  }

  /// 下载并保存图片
  /// 专门用于处理图片文件
  static Future<String> downloadAndSaveImage(String imageUrl) async {
    try {
      final result = await downloadAndSaveFile(imageUrl);
      if (result['path']!.isNotEmpty) {
        // 保存图片元数据
        await saveFileMetadata({
          'path': result['path'],
          'file_name': result['name'],
          'type': 'image',
          'original_url': imageUrl,
          'server_url': imageUrl,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });

        return result['path']!;
      }
      return '';
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 下载并保存图片失败: $e');
      return '';
    }
  }

  /// 获取文件名
  static String getFileName(String filePath) {
    if (filePath.isEmpty) return '';

    try {
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        final uri = Uri.parse(filePath);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          return pathSegments.last;
        }
        return '';
      } else {
        return path.basename(filePath);
      }
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 获取文件名失败: $e');
      return '';
    }
  }

  /// 打开文件
  static Future<bool> openFile(String filePath) async {
    try {
      final validPath = getValidFilePath(filePath);
      if (validPath.isEmpty) return false;

      final uri = Uri.file(validPath);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 打开文件失败: $e');
      return false;
    }
  }

  /// 清理过期文件
  /// 删除超过指定天数的临时文件
  static Future<void> cleanupExpiredFiles(int expirationDays) async {
    try {
      final mediaDir = await getAppDirectory();
      final now = DateTime.now();

      // 获取目录中的所有文件
      final files = mediaDir.listSync();

      for (var fileEntity in files) {
        if (fileEntity is File) {
          final stat = await fileEntity.stat();
          final fileAge = now.difference(stat.modified);

          // 如果文件超过指定天数，删除它
          if (fileAge.inDays > expirationDays) {
            try {
              await fileEntity.delete();
              debugPrint('[EnhancedFileUtils] 删除过期文件: ${fileEntity.path}');
            } catch (e) {
              debugPrint('[EnhancedFileUtils] 删除过期文件失败: $e');
            }
          }
        }
      }

      debugPrint('[EnhancedFileUtils] 清理过期文件完成');
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 清理过期文件失败: $e');
    }
  }

  /// 获取文件大小的格式化字符串
  static String getFormattedFileSize(String filePath) {
    try {
      if (filePath.isEmpty) return '未知大小';

      if (filePath.startsWith('file://') || filePath.startsWith('/')) {
        final validPath = getValidFilePath(filePath);
        if (validPath.isNotEmpty) {
          final file = File(validPath);
          if (file.existsSync()) {
            final bytes = file.lengthSync();
            return formatBytes(bytes);
          }
        }
      }

      return '未知大小';
    } catch (e) {
      debugPrint('[EnhancedFileUtils] 获取文件大小失败: $e');
      return '未知大小';
    }
  }
}
