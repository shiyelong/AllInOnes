import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:frontend/common/file_utils.dart';

/// 增强版文件工具类，用于处理文件的持久化和恢复
class EnhancedFileUtils extends FileUtils {
  
  /// 文件元数据存储键
  static const String _fileMetadataKey = 'file_metadata';
  
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
      final validPath = FileUtils.getValidFilePath(filePath);
      if (await FileUtils.fileExists(validPath)) {
        return validPath;
      }
      
      // 文件不存在，尝试从原始URL重新下载
      final originalUrl = fileInfo['original_url'];
      if (originalUrl != null && originalUrl.isNotEmpty &&
          (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {
        
        debugPrint('[EnhancedFileUtils] 文件不存在，尝试从原始URL重新下载: $originalUrl');
        
        try {
          final result = await FileUtils.downloadAndSaveFile(originalUrl);
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
    }
    
    return filePath;
  }
  
  /// 增强版下载并保存文件
  /// 不仅下载文件，还保存元数据
  static Future<Map<String, String>> downloadAndSaveFileEnhanced(
    String fileUrl, {
    String? customFileName,
    String? fileType,
  }) async {
    try {
      // 下载文件
      final result = await FileUtils.downloadAndSaveFile(fileUrl);
      if (result['path']!.isNotEmpty) {
        // 保存文件元数据
        await saveFileMetadata({
          'path': result['path'],
          'file_name': customFileName ?? result['name'],
          'type': fileType ?? 'file',
          'original_url': fileUrl,
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
  
  /// 清理过期文件
  /// 删除超过指定天数的临时文件
  static Future<void> cleanupExpiredFiles(int expirationDays) async {
    try {
      final mediaDir = await FileUtils.getAppDirectory();
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
        final validPath = FileUtils.getValidFilePath(filePath);
        if (validPath.isNotEmpty) {
          final file = File(validPath);
          if (file.existsSync()) {
            final bytes = file.lengthSync();
            return FileUtils.formatBytes(bytes);
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
