import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'telegram_style_media_preview.dart';
import '../../../common/theme_manager.dart';
import '../../../common/enhanced_file_utils.dart';

/// Telegram风格的媒体选择器
class TelegramStyleMediaPicker {
  /// 选择图片并显示预览
  static Future<List<MediaItem>?> pickImage({
    required BuildContext context,
    bool allowMultiple = true,
    bool allowCaption = true,
  }) async {
    try {
      // 选择图片
      final List<XFile> images;
      if (allowMultiple) {
        final ImagePicker picker = ImagePicker();
        images = await picker.pickMultiImage();
      } else {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        images = image != null ? [image] : [];
      }

      if (images.isEmpty) return null;

      // 转换为MediaItem列表
      final List<MediaItem> mediaItems = images.map((image) => MediaItem(
        file: File(image.path),
        type: MediaType.image,
        caption: '',
      )).toList();

      // 显示预览
      return await _showMediaPreview(
        context: context,
        mediaItems: mediaItems,
        allowMultiple: allowMultiple,
        allowCaption: allowCaption,
      );
    } catch (e) {
      debugPrint('[TelegramStyleMediaPicker] 选择图片出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  /// 选择视频并显示预览
  static Future<List<MediaItem>?> pickVideo({
    required BuildContext context,
    bool allowMultiple = false,
    bool allowCaption = true,
  }) async {
    try {
      // 选择视频
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return null;

      // 初始化视频控制器
      final videoController = VideoPlayerController.file(File(video.path));
      await videoController.initialize();

      // 创建MediaItem
      final MediaItem mediaItem = MediaItem(
        file: File(video.path),
        type: MediaType.video,
        caption: '',
        videoController: videoController,
      );

      // 显示预览
      return await _showMediaPreview(
        context: context,
        mediaItems: [mediaItem],
        allowMultiple: allowMultiple,
        allowCaption: allowCaption,
      );
    } catch (e) {
      debugPrint('[TelegramStyleMediaPicker] 选择视频出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择视频失败: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  /// 拍照并显示预览
  static Future<List<MediaItem>?> takePhoto({
    required BuildContext context,
    bool allowCaption = true,
  }) async {
    try {
      // 拍照
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo == null) return null;

      // 创建MediaItem
      final MediaItem mediaItem = MediaItem(
        file: File(photo.path),
        type: MediaType.image,
        caption: '',
      );

      // 显示预览
      return await _showMediaPreview(
        context: context,
        mediaItems: [mediaItem],
        allowMultiple: false,
        allowCaption: allowCaption,
      );
    } catch (e) {
      debugPrint('[TelegramStyleMediaPicker] 拍照出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  /// 录制视频并显示预览
  static Future<List<MediaItem>?> recordVideo({
    required BuildContext context,
    bool allowCaption = true,
  }) async {
    try {
      // 录制视频
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.camera);

      if (video == null) return null;

      // 初始化视频控制器
      final videoController = VideoPlayerController.file(File(video.path));
      await videoController.initialize();

      // 创建MediaItem
      final MediaItem mediaItem = MediaItem(
        file: File(video.path),
        type: MediaType.video,
        caption: '',
        videoController: videoController,
      );

      // 显示预览
      return await _showMediaPreview(
        context: context,
        mediaItems: [mediaItem],
        allowMultiple: false,
        allowCaption: allowCaption,
      );
    } catch (e) {
      debugPrint('[TelegramStyleMediaPicker] 录制视频出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录制视频失败: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  /// 选择文件并显示预览
  static Future<List<MediaItem>?> pickFile({
    required BuildContext context,
    bool allowMultiple = false,
    bool allowCaption = true,
  }) async {
    try {
      // 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
      );

      if (result == null || result.files.isEmpty) return null;

      // 转换为MediaItem列表
      final List<MediaItem> mediaItems = [];
      for (var file in result.files) {
        if (file.path == null) continue;

        final extension = path.extension(file.path!).toLowerCase();
        final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(extension);
        final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv', '.webm'].contains(extension);

        if (isImage) {
          mediaItems.add(MediaItem(
            file: File(file.path!),
            type: MediaType.image,
            caption: '',
          ));
        } else if (isVideo) {
          final videoController = VideoPlayerController.file(File(file.path!));
          await videoController.initialize();
          
          mediaItems.add(MediaItem(
            file: File(file.path!),
            type: MediaType.video,
            caption: '',
            videoController: videoController,
          ));
        } else {
          mediaItems.add(MediaItem(
            file: File(file.path!),
            type: MediaType.file,
            caption: '',
          ));
        }
      }

      if (mediaItems.isEmpty) return null;

      // 显示预览
      return await _showMediaPreview(
        context: context,
        mediaItems: mediaItems,
        allowMultiple: allowMultiple,
        allowCaption: allowCaption,
      );
    } catch (e) {
      debugPrint('[TelegramStyleMediaPicker] 选择文件出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  /// 显示媒体预览
  static Future<List<MediaItem>?> _showMediaPreview({
    required BuildContext context,
    required List<MediaItem> mediaItems,
    required bool allowMultiple,
    required bool allowCaption,
  }) async {
    if (mediaItems.isEmpty) return null;

    return await showModalBottomSheet<List<MediaItem>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          child: TelegramStyleMediaPreview(
            mediaItems: mediaItems,
            allowMultiple: allowMultiple,
            allowCaption: allowCaption,
            onSend: (items) {
              Navigator.of(context).pop(items);
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}
