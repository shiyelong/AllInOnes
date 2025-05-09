import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enhanced_file_utils.dart';

/// 文件预览管理器
/// 专门处理文件预览的生成、存储和加载
class FilePreviewManager {
  /// 预览缓存目录名
  static const String _previewDirName = 'file_previews';
  
  /// 预览映射表存储键
  static const String _previewMappingKey = 'file_preview_mapping';
  
  /// 获取预览缓存目录
  static Future<Directory> getPreviewDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final previewDir = Directory('${appDir.path}/$_previewDirName');
      
      if (!await previewDir.exists()) {
        await previewDir.create(recursive: true);
      }
      
      return previewDir;
    } catch (e) {
      debugPrint('[FilePreviewManager] 获取预览目录失败: $e');
      // 如果获取失败，使用临时目录
      final tempDir = await getTemporaryDirectory();
      final previewDir = Directory('${tempDir.path}/$_previewDirName');
      
      if (!await previewDir.exists()) {
        await previewDir.create(recursive: true);
      }
      
      return previewDir;
    }
  }
  
  /// 生成文件预览信息
  /// [filePath] 文件路径
  /// 返回预览信息
  static Future<Map<String, dynamic>> generatePreview(String filePath) async {
    try {
      // 验证输入
      if (filePath.isEmpty) {
        debugPrint('[FilePreviewManager] 文件路径为空');
        return {};
      }
      
      // 获取有效的文件路径
      final validPath = EnhancedFileUtils.getValidFilePath(filePath);
      if (validPath.isEmpty) {
        debugPrint('[FilePreviewManager] 无效的文件路径: $filePath');
        return {};
      }
      
      // 检查文件是否存在
      final file = File(validPath);
      if (!await file.exists()) {
        debugPrint('[FilePreviewManager] 文件不存在: $validPath');
        return {};
      }
      
      // 获取文件信息
      final fileName = path.basename(validPath);
      final fileExtension = path.extension(validPath).toLowerCase();
      final fileSize = await file.length();
      
      // 生成唯一的预览ID（使用MD5哈希）
      final hash = md5.convert(utf8.encode('$validPath-$fileSize')).toString();
      
      // 获取文件类型
      final fileType = _getFileType(fileExtension);
      
      // 创建预览信息
      final previewInfo = {
        'id': hash,
        'path': validPath,
        'name': fileName,
        'extension': fileExtension,
        'size': fileSize,
        'type': fileType,
        'icon': _getFileIcon(fileType, fileExtension),
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      
      // 保存预览信息
      await _savePreviewMapping(validPath, previewInfo);
      
      return previewInfo;
    } catch (e) {
      debugPrint('[FilePreviewManager] 生成文件预览异常: $e');
      return {};
    }
  }
  
  /// 获取文件预览信息
  /// 如果预览信息已存在，直接返回
  /// 如果不存在，生成新的预览信息
  static Future<Map<String, dynamic>> getPreview(String filePath) async {
    try {
      // 验证输入
      if (filePath.isEmpty) {
        debugPrint('[FilePreviewManager] 文件路径为空');
        return {};
      }
      
      // 获取有效的文件路径
      final validPath = EnhancedFileUtils.getValidFilePath(filePath);
      if (validPath.isEmpty) {
        debugPrint('[FilePreviewManager] 无效的文件路径: $filePath');
        return {};
      }
      
      // 检查是否有缓存的预览信息
      final cachedPreview = await _getPreviewFromMapping(validPath);
      if (cachedPreview.isNotEmpty) {
        // 验证文件是否存在
        final file = File(validPath);
        if (await file.exists()) {
          debugPrint('[FilePreviewManager] 使用缓存的文件预览信息');
          return cachedPreview;
        }
      }
      
      // 生成新的预览信息
      return await generatePreview(validPath);
    } catch (e) {
      debugPrint('[FilePreviewManager] 获取文件预览异常: $e');
      return {};
    }
  }
  
  /// 保存预览映射关系
  static Future<void> _savePreviewMapping(String filePath, Map<String, dynamic> previewInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有映射
      final mappingJson = prefs.getString(_previewMappingKey) ?? '{}';
      final mapping = jsonDecode(mappingJson) as Map<String, dynamic>;
      
      // 更新映射
      mapping[filePath] = previewInfo;
      
      // 保存更新后的映射
      await prefs.setString(_previewMappingKey, jsonEncode(mapping));
      debugPrint('[FilePreviewManager] 文件预览映射已保存: $filePath');
    } catch (e) {
      debugPrint('[FilePreviewManager] 保存文件预览映射失败: $e');
    }
  }
  
  /// 从映射中获取预览信息
  static Future<Map<String, dynamic>> _getPreviewFromMapping(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有映射
      final mappingJson = prefs.getString(_previewMappingKey) ?? '{}';
      final mapping = jsonDecode(mappingJson) as Map<String, dynamic>;
      
      // 查找映射
      final preview = mapping[filePath];
      if (preview != null && preview is Map<String, dynamic>) {
        return preview;
      }
      
      return {};
    } catch (e) {
      debugPrint('[FilePreviewManager] 获取文件预览映射失败: $e');
      return {};
    }
  }
  
  /// 清理无效的预览信息
  static Future<void> cleanupInvalidPreviews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有映射
      final mappingJson = prefs.getString(_previewMappingKey) ?? '{}';
      final mapping = jsonDecode(mappingJson) as Map<String, dynamic>;
      
      // 新的有效映射
      final validMapping = <String, dynamic>{};
      
      // 检查每个映射
      for (final entry in mapping.entries) {
        final filePath = entry.key;
        final previewInfo = entry.value;
        
        // 检查文件是否存在
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('[FilePreviewManager] 文件不存在，删除映射: $filePath');
          continue;
        }
        
        // 保留有效的映射
        validMapping[filePath] = previewInfo;
      }
      
      // 保存有效的映射
      await prefs.setString(_previewMappingKey, jsonEncode(validMapping));
      debugPrint('[FilePreviewManager] 清理完成，有效映射数量: ${validMapping.length}');
    } catch (e) {
      debugPrint('[FilePreviewManager] 清理无效文件预览失败: $e');
    }
  }
  
  /// 获取文件类型
  static String _getFileType(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    
    // 图片类型
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif'].contains(ext)) {
      return 'image';
    }
    
    // 视频类型
    if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm', '3gp'].contains(ext)) {
      return 'video';
    }
    
    // 音频类型
    if (['mp3', 'wav', 'ogg', 'aac', 'flac', 'm4a', 'wma'].contains(ext)) {
      return 'audio';
    }
    
    // 文档类型
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'md'].contains(ext)) {
      return 'document';
    }
    
    // 压缩文件类型
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].contains(ext)) {
      return 'archive';
    }
    
    // 代码类型
    if (['html', 'css', 'js', 'json', 'xml', 'java', 'py', 'c', 'cpp', 'h', 'swift', 'dart', 'go', 'php', 'rb'].contains(ext)) {
      return 'code';
    }
    
    // 默认类型
    return 'other';
  }
  
  /// 获取文件图标
  static String _getFileIcon(String fileType, String extension) {
    // 根据文件类型返回图标名称
    // 这里只是返回图标名称，实际使用时需要映射到具体的图标资源
    switch (fileType) {
      case 'image':
        return 'image_file';
      case 'video':
        return 'video_file';
      case 'audio':
        return 'audio_file';
      case 'document':
        if (extension.contains('pdf')) {
          return 'pdf_file';
        } else if (extension.contains('doc')) {
          return 'word_file';
        } else if (extension.contains('xls')) {
          return 'excel_file';
        } else if (extension.contains('ppt')) {
          return 'powerpoint_file';
        } else {
          return 'text_file';
        }
      case 'archive':
        return 'archive_file';
      case 'code':
        return 'code_file';
      default:
        return 'unknown_file';
    }
  }
  
  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(2);
      return '$kb KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
      return '$mb MB';
    } else {
      final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
      return '$gb GB';
    }
  }
}
