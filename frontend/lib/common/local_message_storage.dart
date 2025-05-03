import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'text_sanitizer.dart';
import 'file_utils.dart';
import 'api.dart';

/// 本地消息存储服务
/// 用于在本地存储和检索消息，支持离线查看
class LocalMessageStorage {
  static const String _messageKeyPrefix = 'chat_messages_';
  static const String _lastMessageKeyPrefix = 'last_message_';
  static const String _mediaDirectoryName = 'chat_media';
  static const int _maxCachedMessages = 200; // 每个聊天最多缓存的消息数量

  /// 获取媒体文件存储目录
  static Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/$_mediaDirectoryName');

    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    return mediaDir;
  }

  /// 生成唯一的文件名
  static String _generateUniqueFileName(String originalName) {
    final uuid = Uuid().v4();
    final extension = originalName.contains('.')
        ? originalName.substring(originalName.lastIndexOf('.'))
        : '';
    return '$uuid$extension';
  }

  /// 保存消息到本地
  /// [userId] 当前用户ID
  /// [targetId] 目标用户ID
  /// [message] 消息内容
  static Future<bool> saveMessage(int userId, int targetId, Map<String, dynamic> message) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 清理消息内容，确保它是有效的 UTF-16 字符串
      final sanitizedMessage = TextSanitizer.sanitizeMessage(message);

      // 处理媒体文件
      final processedMessage = await _processMediaContent(sanitizedMessage);

      // 获取现有消息
      final chatKey = _getChatKey(userId, targetId);
      final existingMessagesJson = prefs.getStringList(chatKey) ?? [];

      // 将消息转换为JSON字符串
      final messageJson = jsonEncode(processedMessage);

      // 添加新消息
      List<String> updatedMessages = [...existingMessagesJson, messageJson];

      // 如果消息数量超过限制，删除最旧的消息
      if (updatedMessages.length > _maxCachedMessages) {
        updatedMessages = updatedMessages.sublist(
          updatedMessages.length - _maxCachedMessages
        );
      }

      // 保存更新后的消息列表
      await prefs.setStringList(chatKey, updatedMessages);

      // 保存最后一条消息，用于聊天列表预览
      await _saveLastMessage(userId, targetId, processedMessage);

      return true;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 保存消息失败: $e');
      return false;
    }
  }

  /// 处理消息中的媒体内容
  /// 如果消息包含图片、视频或文件，确保它们被保存到本地
  static Future<Map<String, dynamic>> _processMediaContent(Map<String, dynamic> message) async {
    try {
      final type = message['type'] ?? 'text';
      final content = message['content'] ?? '';

      // 如果不是媒体类型或内容为空，直接返回
      if (type == 'text' || type == 'emoji' || content.isEmpty) {
        return message;
      }

      // 保存原始URL，用于后续可能需要重新下载
      if (content.startsWith('http://') || content.startsWith('https://')) {
        message['original_url'] = content;
      }

      // 获取媒体文件存储目录
      final mediaDir = await _getMediaDirectory();

      // 根据消息类型处理
      switch (type) {
        case 'image':
          await _processImageContent(message, mediaDir);
          break;

        case 'video':
          await _processVideoContent(message, mediaDir);
          break;

        case 'file':
          await _processFileContent(message, mediaDir);
          break;

        case 'voice':
          await _processVoiceContent(message, mediaDir);
          break;
      }

      return message;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 处理媒体内容失败: $e');
      return message;
    }
  }

  /// 处理图片消息内容
  static Future<void> _processImageContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';

    // 如果内容为空，直接返回
    if (content.isEmpty) return;

    try {
      // 如果内容已经是本地文件路径，检查文件是否存在
      if (content.startsWith('file://') || content.startsWith('/')) {
        final filePath = FileUtils.getValidFilePath(content);
        if (await FileUtils.fileExists(filePath)) {
          // 文件存在，直接返回
          return;
        }

        // 文件不存在，尝试从原始URL重新下载
        final originalUrl = message['original_url'];
        if (originalUrl != null && originalUrl.isNotEmpty &&
            (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

          // 生成唯一文件名
          final fileName = _generateUniqueFileName('image.jpg');
          final localPath = '${mediaDir.path}/$fileName';

          // 下载图片
          final success = await _downloadFile(originalUrl, localPath);
          if (success) {
            message['content'] = localPath;
            debugPrint('[LocalMessageStorage] 图片已重新下载并保存到本地: $localPath');
          }
        }
      }
      // 处理网络URL
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        // 生成唯一文件名
        final fileName = _generateUniqueFileName('image.jpg');
        final localPath = '${mediaDir.path}/$fileName';

        // 下载图片
        final success = await _downloadFile(content, localPath);
        if (success) {
          message['content'] = localPath;
          debugPrint('[LocalMessageStorage] 图片已下载并保存到本地: $localPath');
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 处理图片内容失败: $e');
    }
  }

  /// 处理视频消息内容
  static Future<void> _processVideoContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';
    final thumbnail = message['thumbnail'] ?? '';

    try {
      // 保存原始视频URL
      if (content.startsWith('http://') || content.startsWith('https://')) {
        message['original_url'] = content;

        // 视频文件较大，不自动下载，但可以在用户点击时下载
        // 这里只处理缩略图
      }

      // 处理缩略图
      if (thumbnail.isNotEmpty) {
        // 如果缩略图是本地路径，检查是否存在
        if (thumbnail.startsWith('file://') || thumbnail.startsWith('/')) {
          final thumbnailPath = FileUtils.getValidFilePath(thumbnail);
          if (!await FileUtils.fileExists(thumbnailPath)) {
            // 缩略图不存在，尝试从原始URL重新下载
            final originalThumbnail = message['original_thumbnail'];
            if (originalThumbnail != null && originalThumbnail.isNotEmpty &&
                (originalThumbnail.startsWith('http://') || originalThumbnail.startsWith('https://'))) {

              // 生成唯一文件名
              final fileName = _generateUniqueFileName('thumbnail.jpg');
              final localPath = '${mediaDir.path}/$fileName';

              // 下载缩略图
              final success = await _downloadFile(originalThumbnail, localPath);
              if (success) {
                message['thumbnail'] = localPath;
                debugPrint('[LocalMessageStorage] 视频缩略图已重新下载并保存到本地: $localPath');
              }
            }
          }
        }
        // 如果缩略图是网络URL，下载并保存
        else if (thumbnail.startsWith('http://') || thumbnail.startsWith('https://')) {
          message['original_thumbnail'] = thumbnail;

          // 生成唯一文件名
          final fileName = _generateUniqueFileName('thumbnail.jpg');
          final localPath = '${mediaDir.path}/$fileName';

          // 下载缩略图
          final success = await _downloadFile(thumbnail, localPath);
          if (success) {
            message['thumbnail'] = localPath;
            debugPrint('[LocalMessageStorage] 视频缩略图已下载并保存到本地: $localPath');
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 处理视频内容失败: $e');
    }
  }

  /// 处理文件消息内容
  static Future<void> _processFileContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';
    final fileName = message['file_name'] ?? message['filename'] ?? 'file';

    try {
      // 如果内容已经是本地文件路径，检查文件是否存在
      if (content.startsWith('file://') || content.startsWith('/')) {
        final filePath = FileUtils.getValidFilePath(content);
        if (await FileUtils.fileExists(filePath)) {
          // 文件存在，直接返回
          return;
        }

        // 文件不存在，尝试从原始URL重新下载
        final originalUrl = message['original_url'];
        if (originalUrl != null && originalUrl.isNotEmpty &&
            (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

          // 生成唯一文件名，保留原始扩展名
          final uniqueFileName = _generateUniqueFileName(fileName);
          final localPath = '${mediaDir.path}/$uniqueFileName';

          // 下载文件
          final success = await _downloadFile(originalUrl, localPath);
          if (success) {
            message['content'] = localPath;
            message['file_name'] = fileName;
            debugPrint('[LocalMessageStorage] 文件已重新下载并保存到本地: $localPath');
          }
        }
      }
      // 处理网络URL
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        // 生成唯一文件名，保留原始扩展名
        final uniqueFileName = _generateUniqueFileName(fileName);
        final localPath = '${mediaDir.path}/$uniqueFileName';

        // 下载文件
        final success = await _downloadFile(content, localPath);
        if (success) {
          message['content'] = localPath;
          message['file_name'] = fileName;
          debugPrint('[LocalMessageStorage] 文件已下载并保存到本地: $localPath');
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 处理文件内容失败: $e');
    }
  }

  /// 处理语音消息内容
  static Future<void> _processVoiceContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';

    try {
      // 如果内容已经是本地文件路径，检查文件是否存在
      if (content.startsWith('file://') || content.startsWith('/')) {
        final filePath = FileUtils.getValidFilePath(content);
        if (await FileUtils.fileExists(filePath)) {
          // 文件存在，直接返回
          return;
        }

        // 文件不存在，尝试从原始URL重新下载
        final originalUrl = message['original_url'];
        if (originalUrl != null && originalUrl.isNotEmpty &&
            (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

          // 生成唯一文件名
          final fileName = _generateUniqueFileName('voice.aac');
          final localPath = '${mediaDir.path}/$fileName';

          // 下载语音文件
          final success = await _downloadFile(originalUrl, localPath);
          if (success) {
            message['content'] = localPath;
            debugPrint('[LocalMessageStorage] 语音文件已重新下载并保存到本地: $localPath');
          }
        }
      }
      // 处理网络URL
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        // 生成唯一文件名
        final fileName = _generateUniqueFileName('voice.aac');
        final localPath = '${mediaDir.path}/$fileName';

        // 下载语音文件
        final success = await _downloadFile(content, localPath);
        if (success) {
          message['content'] = localPath;
          debugPrint('[LocalMessageStorage] 语音文件已下载并保存到本地: $localPath');
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 处理语音内容失败: $e');
    }
  }

  /// 下载文件并保存到指定路径
  static Future<bool> _downloadFile(String url, String savePath) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        debugPrint('[LocalMessageStorage] 下载文件失败，状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 下载文件异常: $e');
      return false;
    }
  }

  /// 获取本地存储的消息
  /// [userId] 当前用户ID
  /// [targetId] 目标用户ID
  static Future<List<Map<String, dynamic>>> getMessages(int userId, int targetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取消息
      final chatKey = _getChatKey(userId, targetId);
      final messagesJson = prefs.getStringList(chatKey) ?? [];

      // 将JSON字符串转换为消息对象
      final messages = await Future.wait(messagesJson.map((json) async {
        try {
          final message = Map<String, dynamic>.from(jsonDecode(json));
          // 清理消息内容，确保它是有效的 UTF-16 字符串
          final sanitizedMessage = TextSanitizer.sanitizeMessage(message);

          // 验证媒体文件是否存在，如果不存在则尝试重新下载
          return await _verifyMediaContent(sanitizedMessage);
        } catch (e) {
          debugPrint('[LocalMessageStorage] 解析消息失败: $e');
          return <String, dynamic>{};
        }
      }));

      return messages.where((msg) => msg.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[LocalMessageStorage] 获取消息失败: $e');
      return [];
    }
  }

  /// 验证消息中的媒体内容
  /// 检查媒体文件是否存在，如果不存在则尝试重新下载
  static Future<Map<String, dynamic>> _verifyMediaContent(Map<String, dynamic> message) async {
    try {
      final type = message['type'] ?? 'text';
      final content = message['content'] ?? '';

      // 如果不是媒体类型或内容为空，直接返回
      if (type == 'text' || type == 'emoji' || content.isEmpty) {
        return message;
      }

      // 获取媒体文件存储目录
      final mediaDir = await _getMediaDirectory();

      // 根据消息类型处理
      switch (type) {
        case 'image':
          await _verifyImageContent(message, mediaDir);
          break;

        case 'video':
          await _verifyVideoContent(message, mediaDir);
          break;

        case 'file':
          await _verifyFileContent(message, mediaDir);
          break;

        case 'voice':
          await _verifyVoiceContent(message, mediaDir);
          break;
      }

      return message;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 验证媒体内容失败: $e');
      return message;
    }
  }

  /// 验证图片消息内容
  static Future<void> _verifyImageContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';

    // 如果内容为空，直接返回
    if (content.isEmpty) return;

    try {
      // 如果内容是本地文件路径，检查文件是否存在
      if (content.startsWith('file://') || content.startsWith('/')) {
        final filePath = FileUtils.getValidFilePath(content);
        if (!await FileUtils.fileExists(filePath)) {
          debugPrint('[LocalMessageStorage] 本地图片文件不存在: $filePath');

          // 尝试从原始URL重新下载
          await _tryRedownloadImage(message, mediaDir);
        } else {
          debugPrint('[LocalMessageStorage] 本地图片文件存在: $filePath');
        }
      }
      // 如果内容是网络URL，下载并保存
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        message['original_url'] = content;
        debugPrint('[LocalMessageStorage] 发现网络图片URL，尝试下载: $content');

        // 生成唯一文件名
        final fileName = _generateUniqueFileName('image.jpg');
        final localPath = '${mediaDir.path}/$fileName';

        // 下载图片
        final success = await _downloadFile(content, localPath);
        if (success) {
          message['content'] = localPath;
          debugPrint('[LocalMessageStorage] 图片已下载并保存到本地: $localPath');
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 验证图片内容失败: $e');
    }
  }

  /// 尝试从原始URL或API服务器重新下载图片
  static Future<void> _tryRedownloadImage(Map<String, dynamic> message, Directory mediaDir) async {
    // 尝试从原始URL重新下载
    final originalUrl = message['original_url'];
    if (originalUrl != null && originalUrl.isNotEmpty &&
        (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

      debugPrint('[LocalMessageStorage] 尝试从原始URL重新下载图片: $originalUrl');

      // 生成唯一文件名
      final fileName = _generateUniqueFileName('image.jpg');
      final localPath = '${mediaDir.path}/$fileName';

      // 下载图片
      final success = await _downloadFile(originalUrl, localPath);
      if (success) {
        message['content'] = localPath;
        debugPrint('[LocalMessageStorage] 图片已重新下载并保存到本地: $localPath');
        return;
      }
    }

    // 如果从原始URL下载失败，尝试从API服务器获取
    if (message['id'] != null) {
      final imageUrl = '${Api.baseUrl}/api/chat/image/${message['id']}';
      debugPrint('[LocalMessageStorage] 尝试从API服务器获取图片: $imageUrl');

      // 生成唯一文件名
      final fileName = _generateUniqueFileName('image.jpg');
      final localPath = '${mediaDir.path}/$fileName';

      // 下载图片
      final success = await _downloadFile(imageUrl, localPath);
      if (success) {
        message['content'] = localPath;
        message['original_url'] = imageUrl;
        debugPrint('[LocalMessageStorage] 图片已从API服务器下载并保存到本地: $localPath');
      }
    }
  }

  /// 验证视频消息内容
  static Future<void> _verifyVideoContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';
    final thumbnail = message['thumbnail'] ?? '';

    try {
      // 如果内容是本地文件路径，检查文件是否存在
      if (content.startsWith('file://') || content.startsWith('/')) {
        final filePath = FileUtils.getValidFilePath(content);
        if (!await FileUtils.fileExists(filePath)) {
          debugPrint('[LocalMessageStorage] 本地视频文件不存在: $filePath');

          // 视频文件较大，不自动重新下载，但保存原始URL以便用户点击时下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty) {
            debugPrint('[LocalMessageStorage] 保存原始视频URL: $originalUrl');
          }
        } else {
          debugPrint('[LocalMessageStorage] 本地视频文件存在: $filePath');
        }
      }
      // 如果内容是网络URL，保存原始URL但不自动下载
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        message['original_url'] = content;
        debugPrint('[LocalMessageStorage] 保存原始视频URL: $content');
      }

      // 验证缩略图
      if (thumbnail.isNotEmpty) {
        if (thumbnail.startsWith('file://') || thumbnail.startsWith('/')) {
          final thumbnailPath = FileUtils.getValidFilePath(thumbnail);
          if (!await FileUtils.fileExists(thumbnailPath)) {
            debugPrint('[LocalMessageStorage] 本地视频缩略图不存在: $thumbnailPath');

            // 尝试从原始URL重新下载缩略图
            final originalThumbnail = message['original_thumbnail'];
            if (originalThumbnail != null && originalThumbnail.isNotEmpty &&
                (originalThumbnail.startsWith('http://') || originalThumbnail.startsWith('https://'))) {

              // 生成唯一文件名
              final fileName = _generateUniqueFileName('thumbnail.jpg');
              final localPath = '${mediaDir.path}/$fileName';

              // 下载缩略图
              final success = await _downloadFile(originalThumbnail, localPath);
              if (success) {
                message['thumbnail'] = localPath;
                debugPrint('[LocalMessageStorage] 视频缩略图已重新下载并保存到本地: $localPath');
              }
            }
          } else {
            debugPrint('[LocalMessageStorage] 本地视频缩略图存在: $thumbnailPath');
          }
        }
        // 如果缩略图是网络URL，下载并保存
        else if (thumbnail.startsWith('http://') || thumbnail.startsWith('https://')) {
          message['original_thumbnail'] = thumbnail;

          // 生成唯一文件名
          final fileName = _generateUniqueFileName('thumbnail.jpg');
          final localPath = '${mediaDir.path}/$fileName';

          // 下载缩略图
          final success = await _downloadFile(thumbnail, localPath);
          if (success) {
            message['thumbnail'] = localPath;
            debugPrint('[LocalMessageStorage] 视频缩略图已下载并保存到本地: $localPath');
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 验证视频内容失败: $e');
    }
  }

  /// 验证文件消息内容
  static Future<void> _verifyFileContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';
    final fileName = message['file_name'] ?? message['filename'] ?? 'file';

    try {
      // 如果内容是本地文件路径，检查文件是否存在
      if (content.startsWith('file://') || content.startsWith('/')) {
        final filePath = FileUtils.getValidFilePath(content);
        if (!await FileUtils.fileExists(filePath)) {
          debugPrint('[LocalMessageStorage] 本地文件不存在: $filePath');

          // 尝试从原始URL重新下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty &&
              (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

            debugPrint('[LocalMessageStorage] 尝试从原始URL重新下载文件: $originalUrl');

            // 生成唯一文件名
            final uniqueFileName = _generateUniqueFileName(fileName);
            final localPath = '${mediaDir.path}/$uniqueFileName';

            // 下载文件
            final success = await _downloadFile(originalUrl, localPath);
            if (success) {
              message['content'] = localPath;
              message['file_name'] = fileName;
              debugPrint('[LocalMessageStorage] 文件已重新下载并保存到本地: $localPath');
            } else {
              // 如果从原始URL下载失败，尝试从API服务器获取
              if (message['id'] != null) {
                final fileUrl = '${Api.baseUrl}/api/chat/file/${message['id']}';
                debugPrint('[LocalMessageStorage] 尝试从API服务器获取文件: $fileUrl');

                final success = await _downloadFile(fileUrl, localPath);
                if (success) {
                  message['content'] = localPath;
                  message['file_name'] = fileName;
                  message['original_url'] = fileUrl;
                  debugPrint('[LocalMessageStorage] 文件已从API服务器下载并保存到本地: $localPath');
                }
              }
            }
          }
        } else {
          debugPrint('[LocalMessageStorage] 本地文件存在: $filePath');
        }
      }
      // 如果内容是网络URL，下载并保存
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        message['original_url'] = content;
        debugPrint('[LocalMessageStorage] 发现网络文件URL，尝试下载: $content');

        // 生成唯一文件名
        final uniqueFileName = _generateUniqueFileName(fileName);
        final localPath = '${mediaDir.path}/$uniqueFileName';

        // 下载文件
        final success = await _downloadFile(content, localPath);
        if (success) {
          message['content'] = localPath;
          message['file_name'] = fileName;
          debugPrint('[LocalMessageStorage] 文件已下载并保存到本地: $localPath');
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 验证文件内容失败: $e');
    }
  }

  /// 验证语音消息内容
  static Future<void> _verifyVoiceContent(Map<String, dynamic> message, Directory mediaDir) async {
    final content = message['content'] ?? '';

    try {
      // 如果内容是本地文件路径，检查文件是否存在
      if (content.startsWith('file://') || content.startsWith('/')) {
        final filePath = FileUtils.getValidFilePath(content);
        if (!await FileUtils.fileExists(filePath)) {
          debugPrint('[LocalMessageStorage] 本地语音文件不存在: $filePath');

          // 尝试从原始URL重新下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty &&
              (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

            debugPrint('[LocalMessageStorage] 尝试从原始URL重新下载语音文件: $originalUrl');

            // 生成唯一文件名
            final fileName = _generateUniqueFileName('voice.aac');
            final localPath = '${mediaDir.path}/$fileName';

            // 下载语音文件
            final success = await _downloadFile(originalUrl, localPath);
            if (success) {
              message['content'] = localPath;
              debugPrint('[LocalMessageStorage] 语音文件已重新下载并保存到本地: $localPath');
            }
          }
        } else {
          debugPrint('[LocalMessageStorage] 本地语音文件存在: $filePath');
        }
      }
      // 如果内容是网络URL，下载并保存
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        message['original_url'] = content;
        debugPrint('[LocalMessageStorage] 发现网络语音URL，尝试下载: $content');

        // 生成唯一文件名
        final fileName = _generateUniqueFileName('voice.aac');
        final localPath = '${mediaDir.path}/$fileName';

        // 下载语音文件
        final success = await _downloadFile(content, localPath);
        if (success) {
          message['content'] = localPath;
          debugPrint('[LocalMessageStorage] 语音文件已下载并保存到本地: $localPath');
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 验证语音内容失败: $e');
    }
  }

  /// 获取最后一条消息，用于聊天列表预览
  /// [userId] 当前用户ID
  /// [targetId] 目标用户ID
  static Future<Map<String, dynamic>?> getLastMessage(int userId, int targetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取最后一条消息
      final lastMessageKey = _getLastMessageKey(userId, targetId);
      final lastMessageJson = prefs.getString(lastMessageKey);

      if (lastMessageJson == null) {
        return null;
      }

      // 将JSON字符串转换为消息对象
      final message = Map<String, dynamic>.from(jsonDecode(lastMessageJson));
      // 清理消息内容，确保它是有效的 UTF-16 字符串
      final sanitizedMessage = TextSanitizer.sanitizeMessage(message);

      // 验证媒体文件是否存在
      return await _verifyMediaContent(sanitizedMessage);
    } catch (e) {
      debugPrint('[LocalMessageStorage] 获取最后一条消息失败: $e');
      return null;
    }
  }

  /// 清除本地存储的消息
  /// [userId] 当前用户ID
  /// [targetId] 目标用户ID
  static Future<bool> clearMessages(int userId, int targetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 清除消息
      final chatKey = _getChatKey(userId, targetId);
      final lastMessageKey = _getLastMessageKey(userId, targetId);

      await prefs.remove(chatKey);
      await prefs.remove(lastMessageKey);

      return true;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 清除消息失败: $e');
      return false;
    }
  }

  /// 保存最后一条消息
  static Future<void> _saveLastMessage(int userId, int targetId, Map<String, dynamic> message) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 清理消息内容，确保它是有效的 UTF-16 字符串
      final sanitizedMessage = TextSanitizer.sanitizeMessage(message);

      // 保存最后一条消息
      final lastMessageKey = _getLastMessageKey(userId, targetId);
      await prefs.setString(lastMessageKey, jsonEncode(sanitizedMessage));
    } catch (e) {
      debugPrint('[LocalMessageStorage] 保存最后一条消息失败: $e');
    }
  }

  /// 获取聊天消息的键
  static String _getChatKey(int userId, int targetId) {
    // 确保键的一致性，无论是A发给B还是B发给A
    final sortedIds = [userId, targetId]..sort();
    return '$_messageKeyPrefix${sortedIds[0]}_${sortedIds[1]}';
  }

  /// 获取最后一条消息的键
  static String _getLastMessageKey(int userId, int targetId) {
    // 确保键的一致性，无论是A发给B还是B发给A
    final sortedIds = [userId, targetId]..sort();
    return '$_lastMessageKeyPrefix${sortedIds[0]}_${sortedIds[1]}';
  }
}
