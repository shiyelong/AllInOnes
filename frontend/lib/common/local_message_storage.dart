import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'text_sanitizer.dart';
import 'enhanced_file_utils.dart';
import 'enhanced_thumbnail_generator.dart';
import 'thumbnail_manager.dart';
import 'api.dart';
import 'message_formatter.dart';

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
        final filePath = EnhancedFileUtils.getValidFilePath(content);
        if (await EnhancedFileUtils.fileExists(filePath)) {
          // 文件存在，检查是否有缩略图
          await _ensureThumbnailExists(message, filePath);
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

            // 生成缩略图
            await _ensureThumbnailExists(message, localPath);
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
          message['original_url'] = content;
          debugPrint('[LocalMessageStorage] 图片已下载并保存到本地: $localPath');

          // 生成缩略图
          await _ensureThumbnailExists(message, localPath);
        }
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 处理图片内容失败: $e');
    }
  }

  /// 确保图片消息有缩略图
  static Future<void> _ensureThumbnailExists(Map<String, dynamic> message, String imagePath) async {
    try {
      // 检查消息中是否已有缩略图
      String? thumbnailPath = message['thumbnail']?.toString();

      // 如果有缩略图路径，检查文件是否存在
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final validPath = EnhancedFileUtils.getValidFilePath(thumbnailPath);
        if (await EnhancedFileUtils.fileExists(validPath)) {
          // 缩略图存在，不需要重新生成
          return;
        }
      }

      // 生成新的缩略图
      debugPrint('[LocalMessageStorage] 开始生成缩略图: $imagePath');
      final thumbnail = await ThumbnailManager.getThumbnail(
        imagePath,
        width: 200,
        height: 200,
        quality: 80,
      );

      if (thumbnail.isNotEmpty) {
        // 更新消息中的缩略图路径
        message['thumbnail'] = thumbnail;

        // 如果有extra字段，也更新里面的缩略图路径
        if (message['extra'] != null && message['extra'] is String) {
          try {
            final extraData = jsonDecode(message['extra']);
            extraData['thumbnail'] = thumbnail;
            message['extra'] = jsonEncode(extraData);
          } catch (e) {
            debugPrint('[LocalMessageStorage] 更新extra中的缩略图失败: $e');
          }
        }

        debugPrint('[LocalMessageStorage] 缩略图已生成: $thumbnail');
      }
    } catch (e) {
      debugPrint('[LocalMessageStorage] 确保缩略图存在失败: $e');
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
          final thumbnailPath = EnhancedFileUtils.getValidFilePath(thumbnail);
          if (!await EnhancedFileUtils.fileExists(thumbnailPath)) {
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
        final filePath = EnhancedFileUtils.getValidFilePath(content);
        if (await EnhancedFileUtils.fileExists(filePath)) {
          // 文件存在，保存文件元数据
          await EnhancedFileUtils.saveFileMetadata({
            'path': filePath,
            'file_name': fileName,
            'type': 'file',
            'original_url': message['original_url'] ?? '',
            'created_at': message['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          });
          return;
        }

        // 文件不存在，尝试从原始URL重新下载
        final originalUrl = message['original_url'];
        if (originalUrl != null && originalUrl.isNotEmpty &&
            (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

          // 使用增强版下载方法
          final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
            originalUrl,
            customFileName: fileName,
            fileType: 'file',
          );

          if (result['path']!.isNotEmpty) {
            message['content'] = result['path'];
            message['file_name'] = fileName;
            debugPrint('[LocalMessageStorage] 文件已重新下载并保存到本地: ${result['path']}');
          }
        }
      }
      // 处理网络URL
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        // 使用增强版下载方法
        final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
          content,
          customFileName: fileName,
          fileType: 'file',
        );

        if (result['path']!.isNotEmpty) {
          message['content'] = result['path'];
          message['file_name'] = fileName;
          message['original_url'] = content;
          debugPrint('[LocalMessageStorage] 文件已下载并保存到本地: ${result['path']}');
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
        final filePath = EnhancedFileUtils.getValidFilePath(content);
        if (await EnhancedFileUtils.fileExists(filePath)) {
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
      final rawMessages = await Future.wait(messagesJson.map((json) async {
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

      // 过滤掉空消息
      final validMessages = rawMessages.where((msg) => msg.isNotEmpty).toList();

      // 去重处理
      final deduplicatedMessages = _deduplicateMessages(validMessages);

      debugPrint('[LocalMessageStorage] 获取消息成功: 原始消息数=${validMessages.length}, 去重后消息数=${deduplicatedMessages.length}');

      return deduplicatedMessages;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 获取消息失败: $e');
      return [];
    }
  }

  /// 消息去重
  /// 根据消息ID或内容+时间戳去重，保留状态值更高的消息
  static List<Map<String, dynamic>> _deduplicateMessages(List<Map<String, dynamic>> messages) {
    try {
      // 使用Map进行去重，键为消息ID或内容+时间戳
      final Map<String, Map<String, dynamic>> uniqueMessages = {};

      for (var msg in messages) {
        // 确保消息有有效的发送者和接收者ID
        final fromId = msg['from_id'] ?? 0;
        final toId = msg['to_id'] ?? 0;

        // 如果发送者或接收者ID为0，跳过该消息
        if (fromId == 0 || toId == 0) {
          debugPrint('[LocalMessageStorage] 跳过无效消息: fromId=$fromId, toId=$toId');
          continue;
        }

        final String messageId = msg['id']?.toString() ?? '';

        if (messageId.isNotEmpty) {
          // 使用ID作为键
          final key = 'id_${messageId}_${fromId}_${toId}';

          if (uniqueMessages.containsKey(key)) {
            // 如果已存在，保留状态值更高的消息
            final existingStatus = uniqueMessages[key]!['status'] ?? 0;
            final newStatus = msg['status'] ?? 0;

            // 如果状态相同，保留更新时间更新的消息
            if (newStatus > existingStatus) {
              uniqueMessages[key] = msg;
              debugPrint('[LocalMessageStorage] 更新重复消息: id=$messageId, 状态: $existingStatus -> $newStatus');
            } else if (newStatus == existingStatus) {
              // 检查更新时间
              final existingUpdatedAt = uniqueMessages[key]!['updated_at'] ??
                                       uniqueMessages[key]!['created_at'] ?? 0;
              final newUpdatedAt = msg['updated_at'] ?? msg['created_at'] ?? 0;

              if (newUpdatedAt > existingUpdatedAt) {
                uniqueMessages[key] = msg;
                debugPrint('[LocalMessageStorage] 更新重复消息: id=$messageId, 更新时间更新');
              }

              // 如果新消息有缩略图但旧消息没有，使用新消息
              final existingThumbnail = uniqueMessages[key]!['thumbnail'];
              final newThumbnail = msg['thumbnail'];

              if ((existingThumbnail == null || existingThumbnail.toString().isEmpty) &&
                  newThumbnail != null && newThumbnail.toString().isNotEmpty) {
                uniqueMessages[key] = msg;
                debugPrint('[LocalMessageStorage] 更新重复消息: id=$messageId, 新消息有缩略图');
              }

              // 合并extra信息
              try {
                final existingExtra = uniqueMessages[key]!['extra'];
                final newExtra = msg['extra'];

                if (existingExtra != null && newExtra != null) {
                  final existingExtraMap = jsonDecode(existingExtra.toString());
                  final newExtraMap = jsonDecode(newExtra.toString());

                  // 合并两个extra，新的覆盖旧的
                  final mergedExtra = <String, dynamic>{...existingExtraMap, ...newExtraMap};
                  uniqueMessages[key]!['extra'] = jsonEncode(mergedExtra);
                  debugPrint('[LocalMessageStorage] 合并消息extra信息: id=$messageId');
                }
              } catch (e) {
                debugPrint('[LocalMessageStorage] 合并extra信息失败: $e');
              }
            }
          } else {
            uniqueMessages[key] = msg;
          }
        } else {
          // 对于没有ID的消息，使用内容+时间戳+发送者ID+接收者ID作为键
          final content = msg['content']?.toString() ?? '';
          final timestamp = msg['created_at']?.toString() ?? '';
          final compositeKey = 'msg_${fromId}_${toId}_${timestamp}_${content.hashCode}';

          if (compositeKey != 'msg_0_0__0') {
            if (!uniqueMessages.containsKey(compositeKey)) {
              uniqueMessages[compositeKey] = msg;
            } else {
              // 如果已存在，检查是否有缩略图
              final existingThumbnail = uniqueMessages[compositeKey]!['thumbnail'];
              final newThumbnail = msg['thumbnail'];

              if ((existingThumbnail == null || existingThumbnail.toString().isEmpty) &&
                  newThumbnail != null && newThumbnail.toString().isNotEmpty) {
                uniqueMessages[compositeKey] = msg;
                debugPrint('[LocalMessageStorage] 更新重复消息: key=$compositeKey, 新消息有缩略图');
              }
            }
          }
        }
      }

      // 转换回列表
      final List<Map<String, dynamic>> result = uniqueMessages.values.toList();

      // 按时间排序
      result.sort((a, b) {
        final aTime = a['created_at'] ?? 0;
        final bTime = b['created_at'] ?? 0;
        return aTime.compareTo(bTime);
      });

      return result;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 消息去重失败: $e');
      return messages;
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
        final filePath = EnhancedFileUtils.getValidFilePath(content);
        if (!await EnhancedFileUtils.fileExists(filePath)) {
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
        final filePath = EnhancedFileUtils.getValidFilePath(content);
        if (!await EnhancedFileUtils.fileExists(filePath)) {
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
          final thumbnailPath = EnhancedFileUtils.getValidFilePath(thumbnail);
          if (!await EnhancedFileUtils.fileExists(thumbnailPath)) {
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
        final filePath = EnhancedFileUtils.getValidFilePath(content);
        if (!await EnhancedFileUtils.fileExists(filePath)) {
          debugPrint('[LocalMessageStorage] 本地文件不存在: $filePath');

          // 尝试从文件元数据中恢复
          final fileMetadata = await EnhancedFileUtils.getFileMetadataByPath(content);
          if (fileMetadata != null) {
            // 尝试验证和恢复文件
            final recoveredPath = await EnhancedFileUtils.verifyAndRecoverFile(fileMetadata);
            if (recoveredPath.isNotEmpty && await EnhancedFileUtils.fileExists(recoveredPath)) {
              message['content'] = recoveredPath;
              debugPrint('[LocalMessageStorage] 文件已从元数据恢复: $recoveredPath');
              return;
            }
          }

          // 如果元数据恢复失败，尝试从原始URL重新下载
          final originalUrl = message['original_url'];
          if (originalUrl != null && originalUrl.isNotEmpty &&
              (originalUrl.startsWith('http://') || originalUrl.startsWith('https://'))) {

            debugPrint('[LocalMessageStorage] 尝试从原始URL重新下载文件: $originalUrl');

            // 使用增强版下载方法
            final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
              originalUrl,
              customFileName: fileName,
              fileType: 'file',
            );

            if (result['path']!.isNotEmpty) {
              message['content'] = result['path'];
              message['file_name'] = fileName;
              debugPrint('[LocalMessageStorage] 文件已重新下载并保存到本地: ${result['path']}');
            } else {
              // 如果从原始URL下载失败，尝试从API服务器获取
              if (message['id'] != null) {
                final fileUrl = '${Api.baseUrl}/api/chat/file/${message['id']}';
                debugPrint('[LocalMessageStorage] 尝试从API服务器获取文件: $fileUrl');

                final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
                  fileUrl,
                  customFileName: fileName,
                  fileType: 'file',
                );

                if (result['path']!.isNotEmpty) {
                  message['content'] = result['path'];
                  message['file_name'] = fileName;
                  message['original_url'] = fileUrl;
                  debugPrint('[LocalMessageStorage] 文件已从API服务器下载并保存到本地: ${result['path']}');
                }
              }
            }
          }
        } else {
          debugPrint('[LocalMessageStorage] 本地文件存在: $filePath');

          // 确保文件元数据已保存
          await EnhancedFileUtils.saveFileMetadata({
            'path': filePath,
            'file_name': fileName,
            'type': 'file',
            'original_url': message['original_url'] ?? '',
            'created_at': message['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          });
        }
      }
      // 如果内容是网络URL，下载并保存
      else if (content.startsWith('http://') || content.startsWith('https://')) {
        message['original_url'] = content;
        debugPrint('[LocalMessageStorage] 发现网络文件URL，尝试下载: $content');

        // 使用增强版下载方法
        final result = await EnhancedFileUtils.downloadAndSaveFileEnhanced(
          content,
          customFileName: fileName,
          fileType: 'file',
        );

        if (result['path']!.isNotEmpty) {
          message['content'] = result['path'];
          message['file_name'] = fileName;
          debugPrint('[LocalMessageStorage] 文件已下载并保存到本地: ${result['path']}');
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
        final filePath = EnhancedFileUtils.getValidFilePath(content);
        if (!await EnhancedFileUtils.fileExists(filePath)) {
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
  /// [formatPreview] 是否格式化消息预览，默认为false
  static Future<Map<String, dynamic>?> getLastMessage(int userId, int targetId, {bool formatPreview = false}) async {
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
      final verifiedMessage = await _verifyMediaContent(sanitizedMessage);

      // 如果需要格式化预览，处理消息内容
      if (formatPreview) {
        final formattedPreview = MessageFormatter.formatMessagePreview(verifiedMessage);
        verifiedMessage['formatted_preview'] = formattedPreview;
      }

      return verifiedMessage;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 获取最后一条消息失败: $e');
      return null;
    }
  }

  /// 清除本地存储的消息
  /// [userId] 当前用户ID
  /// [targetId] 目标用户ID
  /// [deleteMediaFiles] 是否同时删除媒体文件，默认为false
  static Future<bool> clearMessages(int userId, int targetId, {bool deleteMediaFiles = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 清除消息
      final chatKey = _getChatKey(userId, targetId);
      final lastMessageKey = _getLastMessageKey(userId, targetId);

      // 获取当前消息数量，用于日志记录
      final messagesJson = prefs.getStringList(chatKey) ?? [];
      final messageCount = messagesJson.length;

      // 如果需要删除媒体文件，先解析所有消息并收集媒体文件路径
      if (deleteMediaFiles && messagesJson.isNotEmpty) {
        final mediaFilePaths = <String>[];

        // 解析所有消息，收集媒体文件路径
        for (final json in messagesJson) {
          try {
            final message = Map<String, dynamic>.from(jsonDecode(json));
            final type = message['type'] ?? 'text';
            final content = message['content'] ?? '';

            // 只处理媒体类型的消息
            if (type != 'text' && type != 'emoji' && content.isNotEmpty) {
              // 如果内容是本地文件路径，添加到待删除列表
              if (content.startsWith('file://') || content.startsWith('/')) {
                mediaFilePaths.add(EnhancedFileUtils.getValidFilePath(content));
              }

              // 检查是否有缩略图
              final thumbnail = message['thumbnail'] ?? '';
              if (thumbnail.isNotEmpty && (thumbnail.startsWith('file://') || thumbnail.startsWith('/'))) {
                mediaFilePaths.add(EnhancedFileUtils.getValidFilePath(thumbnail));
              }
            }
          } catch (e) {
            debugPrint('[LocalMessageStorage] 解析消息失败: $e');
          }
        }

        // 删除收集到的媒体文件
        for (final path in mediaFilePaths) {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
              debugPrint('[LocalMessageStorage] 删除媒体文件: $path');
            }
          } catch (e) {
            debugPrint('[LocalMessageStorage] 删除媒体文件失败: $e');
          }
        }
      }

      // 删除消息
      await prefs.remove(chatKey);
      await prefs.remove(lastMessageKey);

      // 检查是否成功删除
      final messagesAfter = prefs.getStringList(chatKey) ?? [];
      final success = messagesAfter.isEmpty;

      debugPrint('[LocalMessageStorage] 清除消息记录: userId=$userId, targetId=$targetId, 消息数=$messageCount, 成功=$success');
      return success;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 清除消息失败: $e');
      return false;
    }
  }

  /// 清除所有聊天记录
  /// [deleteMediaFiles] 是否同时删除媒体文件，默认为true
  /// [clearThumbnailCache] 是否清除缩略图缓存，默认为true
  static Future<bool> clearAllMessages({bool deleteMediaFiles = true, bool clearThumbnailCache = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取所有键
      final allKeys = prefs.getKeys();

      // 筛选出聊天消息相关的键
      final chatKeys = allKeys.where((key) =>
        key.startsWith(_messageKeyPrefix) ||
        key.startsWith(_lastMessageKeyPrefix)
      ).toList();

      debugPrint('[LocalMessageStorage] 找到 ${chatKeys.length} 个聊天相关的键');

      // 如果需要删除媒体文件，收集所有媒体文件路径
      if (deleteMediaFiles) {
        final mediaFilePaths = <String>[];

        // 遍历所有聊天消息键
        for (final key in chatKeys.where((k) => k.startsWith(_messageKeyPrefix))) {
          final messagesJson = prefs.getStringList(key) ?? [];

          // 解析所有消息，收集媒体文件路径
          for (final json in messagesJson) {
            try {
              final message = Map<String, dynamic>.from(jsonDecode(json));
              final type = message['type'] ?? 'text';
              final content = message['content'] ?? '';

              // 只处理媒体类型的消息
              if (type != 'text' && type != 'emoji' && content.isNotEmpty) {
                // 如果内容是本地文件路径，添加到待删除列表
                if (content.startsWith('file://') || content.startsWith('/')) {
                  mediaFilePaths.add(EnhancedFileUtils.getValidFilePath(content));
                }

                // 检查是否有缩略图
                final thumbnail = message['thumbnail'] ?? '';
                if (thumbnail.isNotEmpty && (thumbnail.startsWith('file://') || thumbnail.startsWith('/'))) {
                  mediaFilePaths.add(EnhancedFileUtils.getValidFilePath(thumbnail));
                }
              }
            } catch (e) {
              debugPrint('[LocalMessageStorage] 解析消息失败: $e');
            }
          }
        }

        // 删除收集到的媒体文件
        int deletedCount = 0;
        for (final path in mediaFilePaths) {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
              deletedCount++;
            }
          } catch (e) {
            debugPrint('[LocalMessageStorage] 删除媒体文件失败: $e');
          }
        }

        debugPrint('[LocalMessageStorage] 已删除 $deletedCount 个媒体文件');
      }

      // 清除缩略图缓存
      if (clearThumbnailCache) {
        await _clearThumbnailCache();
      }

      // 删除所有聊天相关的键
      for (final key in chatKeys) {
        await prefs.remove(key);
      }

      debugPrint('[LocalMessageStorage] 已清除所有聊天记录');
      return true;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 清除所有聊天记录失败: $e');
      return false;
    }
  }

  /// 清除缩略图缓存
  static Future<bool> _clearThumbnailCache() async {
    try {
      // 获取缩略图缓存目录
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailDir = Directory('${appDir.path}/thumbnails');

      // 如果目录不存在，直接返回成功
      if (!await thumbnailDir.exists()) {
        return true;
      }

      // 删除目录中的所有文件
      final files = await thumbnailDir.list().toList();
      int deletedCount = 0;

      for (final entity in files) {
        if (entity is File) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (e) {
            debugPrint('[LocalMessageStorage] 删除缩略图文件失败: $e');
          }
        }
      }

      debugPrint('[LocalMessageStorage] 已删除 $deletedCount 个缩略图文件');
      return true;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 清除缩略图缓存失败: $e');
      return false;
    }
  }

  /// 清除缩略图缓存（公开方法）
  static Future<bool> clearThumbnailCache() async {
    return await _clearThumbnailCache();
  }

  /// 获取所有失败的消息
  static Future<List<Map<String, dynamic>>> getFailedMessages(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedMessages = <Map<String, dynamic>>[];

      // 获取所有聊天的键
      final allKeys = prefs.getKeys();
      final chatKeys = allKeys.where((key) => key.startsWith('${_messageKeyPrefix}${userId}_') ||
                                            key.startsWith('${_messageKeyPrefix}_${userId}')).toList();

      // 遍历每个聊天
      for (var chatKey in chatKeys) {
        final messagesJson = prefs.getStringList(chatKey) ?? [];

        // 找出失败的消息
        for (var json in messagesJson) {
          try {
            final message = Map<String, dynamic>.from(jsonDecode(json));

            if (message['status'] == 2 && // 状态为发送失败
                message['from_id'] == userId) { // 只处理自己发送的消息

              // 从聊天键中提取目标ID
              final keyParts = chatKey.substring(_messageKeyPrefix.length).split('_');
              int targetId;
              if (keyParts[0] == userId.toString()) {
                targetId = int.parse(keyParts[1]);
              } else {
                targetId = int.parse(keyParts[0]);
              }

              // 添加目标ID到消息中
              message['to_id'] = targetId;

              failedMessages.add(message);
            }
          } catch (e) {
            debugPrint('[LocalMessageStorage] 解析消息失败: $e');
          }
        }
      }

      // 按时间排序，先发送较早的消息
      failedMessages.sort((a, b) {
        final aTime = a['created_at'] ?? 0;
        final bTime = b['created_at'] ?? 0;
        return aTime.compareTo(bTime);
      });

      debugPrint('[LocalMessageStorage] 找到 ${failedMessages.length} 条失败的消息');
      return failedMessages;
    } catch (e) {
      debugPrint('[LocalMessageStorage] 获取失败消息失败: $e');
      return [];
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
