import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../common/persistence.dart';

/// 完全数据清理工具
/// 用于彻底清理所有聊天记录和相关数据
class CompleteDataCleaner {
  /// 清理所有数据
  static Future<Map<String, dynamic>> cleanAllData(BuildContext context) async {
    try {
      // 显示进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('正在清理数据'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在清理所有聊天记录和相关数据，请稍候...'),
            ],
          ),
        ),
      );

      // 清理SharedPreferences中的聊天记录
      final result1 = await _cleanSharedPreferences();

      // 清理文件系统中的媒体文件
      final result2 = await _cleanMediaFiles();

      // 清理缩略图缓存
      final result3 = await _cleanThumbnailCache();

      // 关闭进度对话框
      Navigator.of(context).pop();

      // 显示结果对话框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('数据清理完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('清理结果:'),
              SizedBox(height: 8),
              Text('• 聊天记录: ${result1['cleanedKeys']} 条'),
              Text('• 媒体文件: ${result2['deletedFiles']} 个'),
              Text('• 缩略图缓存: ${result3['deletedFiles']} 个'),
              SizedBox(height: 16),
              Text('所有聊天数据已清理完毕，请重启应用以确保更改生效。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );

      return {
        'success': true,
        'cleanedPrefs': result1['cleanedKeys'],
        'deletedMediaFiles': result2['deletedFiles'],
        'deletedThumbnails': result3['deletedFiles'],
      };
    } catch (e) {
      // 关闭进度对话框（如果存在）
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // 显示错误对话框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('清理失败'),
          content: Text('清理数据时发生错误: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 清理SharedPreferences中的聊天记录
  static Future<Map<String, dynamic>> _cleanSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // 需要清理的键前缀
      final prefixesToClean = [
        'chat_messages_', // 聊天消息
        'last_message_', // 最后一条消息
        'thumbnail_mapping', // 缩略图映射
        'video_thumbnail_mapping', // 视频缩略图映射
        'file_preview_mapping', // 文件预览映射
        'url_path_mapping', // URL路径映射
        'file_metadata', // 文件元数据
      ];

      // 找出需要清理的键
      final keysToClean = allKeys.where((key) =>
        prefixesToClean.any((prefix) => key.startsWith(prefix)) ||
        key == 'recent' // 最近使用的表情符号
      ).toList();

      // 清理键
      for (final key in keysToClean) {
        await prefs.remove(key);
        debugPrint('[CompleteDataCleaner] 已删除键: $key');
      }

      return {
        'success': true,
        'cleanedKeys': keysToClean.length,
      };
    } catch (e) {
      debugPrint('[CompleteDataCleaner] 清理SharedPreferences失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 清理文件系统中的媒体文件
  static Future<Map<String, dynamic>> _cleanMediaFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      int deletedFiles = 0;

      // 需要清理的目录
      final dirsToClean = [
        'chat_media', // 聊天媒体文件
        'downloads', // 下载的文件
        'images', // 图片
        'videos', // 视频
        'audios', // 音频
        'files', // 文件
        'temp_files', // 临时文件
      ];

      // 清理每个目录
      for (final dirName in dirsToClean) {
        final dir = Directory('${appDir.path}/$dirName');
        if (await dir.exists()) {
          // 获取目录中的所有文件
          final files = await dir.list().toList();

          // 删除所有文件
          for (final entity in files) {
            if (entity is File) {
              await entity.delete();
              deletedFiles++;
            } else if (entity is Directory) {
              // 递归删除子目录
              await entity.delete(recursive: true);
            }
          }

          debugPrint('[CompleteDataCleaner] 已清理目录: $dirName');
        }
      }

      return {
        'success': true,
        'deletedFiles': deletedFiles,
      };
    } catch (e) {
      debugPrint('[CompleteDataCleaner] 清理媒体文件失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 清理缩略图缓存
  static Future<Map<String, dynamic>> _cleanThumbnailCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      int deletedFiles = 0;

      // 需要清理的缩略图目录
      final dirsToClean = [
        'thumbnails', // 图片缩略图
        'enhanced_thumbnails', // 增强版图片缩略图
        'video_thumbnails', // 视频缩略图
        'file_previews', // 文件预览
      ];

      // 清理每个目录
      for (final dirName in dirsToClean) {
        final dir = Directory('${appDir.path}/$dirName');
        if (await dir.exists()) {
          // 获取目录中的所有文件
          final files = await dir.list().toList();

          // 删除所有文件
          for (final entity in files) {
            if (entity is File) {
              await entity.delete();
              deletedFiles++;
            }
          }

          debugPrint('[CompleteDataCleaner] 已清理缩略图目录: $dirName');
        }
      }

      return {
        'success': true,
        'deletedFiles': deletedFiles,
      };
    } catch (e) {
      debugPrint('[CompleteDataCleaner] 清理缩略图缓存失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 重置应用
  static Future<void> resetApp(BuildContext context) async {
    try {
      // 清理所有数据
      await cleanAllData(context);

      // 清除登录状态
      await Persistence.clearToken();
      await Persistence.clearUserInfo();

      // 显示重启提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('重置完成'),
          content: Text('应用已重置，请手动重启应用以完成重置过程。'),
          actions: [
            TextButton(
              onPressed: () {
                // 退出应用
                exit(0);
              },
              child: Text('退出应用'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[CompleteDataCleaner] 重置应用失败: $e');

      // 显示错误对话框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('重置失败'),
          content: Text('重置应用时发生错误: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }
}
