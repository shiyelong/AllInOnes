import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../common/api.dart';
import '../../../common/enhanced_file_utils.dart';
import '../../../common/enhanced_thumbnail_generator.dart';
import '../../../common/thumbnail_manager.dart';
import '../../../common/local_message_storage.dart';
import '../../../common/persistence.dart';
import 'chat_message_manager.dart';

/// 媒体消息处理器
/// 负责处理图片、视频、文件等媒体消息的发送
class MediaMessageHandler {
  static final MediaMessageHandler _instance = MediaMessageHandler._internal();
  factory MediaMessageHandler() => _instance;

  MediaMessageHandler._internal();

  /// 发送图片消息
  Future<Map<String, dynamic>> sendImageMessage({
    required String userId,
    required String targetId,
    required File imageFile,
    required String imagePath,
  }) async {
    try {
      // 生成唯一的消息ID
      final localMessageId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 生成缩略图
      final thumbnailPath = await ThumbnailManager.generateImageThumbnail(imageFile.path);
      final thumbnailData = '';

      // 创建本地消息对象
      final localMessage = {
        'id': localMessageId,
        'from_id': int.parse(userId),
        'to_id': int.parse(targetId),
        'content': imageFile.path,
        'type': 'image',
        'created_at': timestamp,
        'status': 0, // 发送中
        'thumbnail': thumbnailPath,
        'thumbnail_data': thumbnailData,
      };

      // 立即保存到本地存储，确保消息不会丢失
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      debugPrint('[MediaMessageHandler] 发送图片: ${imageFile.path}');
      final response = await Api.uploadImage(
        targetId: targetId,
        filePath: imageFile.path,
      );

      debugPrint('[MediaMessageHandler] 发送图片响应: $response');

      if (response['success'] == true) {
        // 获取服务器返回的消息ID和图片URL
        final serverId = response['data']?['id'];
        final serverUrl = response['data']?['url'];

        if (serverId != null) {
          // 更新本地消息对象
          localMessage['status'] = 1; // 已发送
          localMessage['id'] = serverId;
          if (serverUrl != null) {
            localMessage['server_url'] = serverUrl;
          }

          // 保存更新后的消息
          await _saveMessageToLocalStorage(userId, targetId, localMessage);

          return {
            'success': true,
            'message': localMessage,
            'error': '',
          };
        }
      }

      // 如果发送失败，更新消息状态为发送失败
      localMessage['status'] = 2; // 发送失败
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      return {
        'success': false,
        'message': localMessage,
        'error': response['msg'] ?? '发送图片失败',
      };
    } catch (e) {
      debugPrint('[MediaMessageHandler] 发送图片异常: $e');
      return {
        'success': false,
        'message': null,
        'error': '发送图片出错: $e',
      };
    }
  }

  /// 发送视频消息
  Future<Map<String, dynamic>> sendVideoMessage({
    required String userId,
    required String targetId,
    required File videoFile,
    required String videoPath,
  }) async {
    try {
      // 生成唯一的消息ID
      final localMessageId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 生成缩略图
      final thumbnailPath = await ThumbnailManager.generateVideoThumbnail(videoFile.path);
      final thumbnailData = '';

      // 创建本地消息对象
      final localMessage = {
        'id': localMessageId,
        'from_id': int.parse(userId),
        'to_id': int.parse(targetId),
        'content': videoFile.path,
        'type': 'video',
        'created_at': timestamp,
        'status': 0, // 发送中
        'thumbnail': thumbnailPath,
        'thumbnail_data': thumbnailData,
      };

      // 立即保存到本地存储，确保消息不会丢失
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      debugPrint('[MediaMessageHandler] 发送视频: ${videoFile.path}');
      final response = await Api.uploadVideo(
        targetId: targetId,
        filePath: videoFile.path,
      );

      debugPrint('[MediaMessageHandler] 发送视频响应: $response');

      if (response['success'] == true) {
        // 获取服务器返回的消息ID和视频URL
        final serverId = response['data']?['id'];
        final serverUrl = response['data']?['url'];

        if (serverId != null) {
          // 更新本地消息对象
          localMessage['status'] = 1; // 已发送
          localMessage['id'] = serverId;
          if (serverUrl != null) {
            localMessage['server_url'] = serverUrl;
          }

          // 保存更新后的消息
          await _saveMessageToLocalStorage(userId, targetId, localMessage);

          return {
            'success': true,
            'message': localMessage,
            'error': '',
          };
        }
      }

      // 如果发送失败，更新消息状态为发送失败
      localMessage['status'] = 2; // 发送失败
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      return {
        'success': false,
        'message': localMessage,
        'error': response['msg'] ?? '发送视频失败',
      };
    } catch (e) {
      debugPrint('[MediaMessageHandler] 发送视频异常: $e');
      return {
        'success': false,
        'message': null,
        'error': '发送视频出错: $e',
      };
    }
  }

  /// 发送文件消息
  Future<Map<String, dynamic>> sendFileMessage({
    required String userId,
    required String targetId,
    required File file,
    required String filePath,
    required String fileName,
  }) async {
    try {
      // 生成唯一的消息ID
      final localMessageId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 创建本地消息对象
      final localMessage = {
        'id': localMessageId,
        'from_id': int.parse(userId),
        'to_id': int.parse(targetId),
        'content': filePath,
        'type': 'file',
        'created_at': timestamp,
        'status': 0, // 发送中
        'file_name': fileName,
        'file_size': await file.length(),
      };

      // 立即保存到本地存储，确保消息不会丢失
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      debugPrint('[MediaMessageHandler] 发送文件: $filePath');
      final response = await Api.uploadFile(
        targetId: targetId,
        filePath: filePath,
        fileName: fileName,
      );

      debugPrint('[MediaMessageHandler] 发送文件响应: $response');

      if (response['success'] == true) {
        // 获取服务器返回的消息ID和文件URL
        final serverId = response['data']?['id'];
        final serverUrl = response['data']?['url'];

        if (serverId != null) {
          // 更新本地消息对象
          localMessage['status'] = 1; // 已发送
          localMessage['id'] = serverId;
          if (serverUrl != null) {
            localMessage['server_url'] = serverUrl;
          }

          // 保存更新后的消息
          await _saveMessageToLocalStorage(userId, targetId, localMessage);

          return {
            'success': true,
            'message': localMessage,
            'error': '',
          };
        }
      }

      // 如果发送失败，更新消息状态为发送失败
      localMessage['status'] = 2; // 发送失败
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      return {
        'success': false,
        'message': localMessage,
        'error': response['msg'] ?? '发送文件失败',
      };
    } catch (e) {
      debugPrint('[MediaMessageHandler] 发送文件异常: $e');
      return {
        'success': false,
        'message': null,
        'error': '发送文件出错: $e',
      };
    }
  }

  /// 保存消息到本地存储
  Future<void> _saveMessageToLocalStorage(
    String userId,
    String targetId,
    Map<String, dynamic> message,
  ) async {
    try {
      // 获取当前消息列表
      final messages = await Persistence.getChatMessages(userId, targetId);

      // 查找是否已存在相同ID的消息
      final index = messages.indexWhere((msg) => msg['id'] == message['id']);
      if (index != -1) {
        // 更新现有消息
        messages[index] = message;
      } else {
        // 添加新消息
        messages.add(message);
      }

      // 保存到Persistence
      await Persistence.saveChatMessages(userId, targetId, messages);

      // 同时保存到LocalMessageStorage
      try {
        await LocalMessageStorage.saveMessage(
          userId,
          targetId,
          message
        );
      } catch (e) {
        debugPrint('[MediaMessageHandler] 保存到LocalMessageStorage失败: $e');
      }
    } catch (e) {
      debugPrint('[MediaMessageHandler] 保存消息到本地存储失败: $e');
    }
  }
}
