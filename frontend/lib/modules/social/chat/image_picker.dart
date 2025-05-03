import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// 跨平台图片选择方法
///
/// 在移动端使用image_picker，在桌面端使用file_picker
/// 在Web端使用file_picker并返回带有bytes的XFile
Future<XFile?> pickImage() async {
  try {
    if (kIsWeb) {
      // Web端使用file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // 确保获取文件数据
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // 创建一个带有bytes的XFile
          return XFile.fromData(
            file.bytes!,
            name: file.name,
            mimeType: 'image/${file.extension?.toLowerCase() ?? 'jpeg'}',
          );
        }
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      // 移动端使用image_picker
      try {
        final ImagePicker picker = ImagePicker();
        // 尝试使用image_picker
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          return image;
        }
      } catch (mobileError) {
        print('移动端image_picker失败，尝试使用file_picker: $mobileError');
        // 如果image_picker失败，尝试使用file_picker作为备选方案
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );

        if (result != null && result.files.single.path != null) {
          return XFile(result.files.single.path!);
        }
      }
    } else {
      // 桌面端使用file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        return XFile(result.files.single.path!);
      }
    }
  } catch (e) {
    print('选择图片出错: $e');
  }
  return null;
}

/// 跨平台视频选择方法
Future<XFile?> pickVideo() async {
  try {
    if (kIsWeb) {
      // Web端使用file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true, // 确保获取文件数据
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // 创建一个带有bytes的XFile
          return XFile.fromData(
            file.bytes!,
            name: file.name,
            mimeType: 'video/${file.extension?.toLowerCase() ?? 'mp4'}',
          );
        }
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      // 移动端使用image_picker
      try {
        final ImagePicker picker = ImagePicker();
        // 尝试使用image_picker
        final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          return video;
        }
      } catch (mobileError) {
        print('移动端image_picker视频选择失败，尝试使用file_picker: $mobileError');
        // 如果image_picker失败，尝试使用file_picker作为备选方案
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.video,
        );

        if (result != null && result.files.single.path != null) {
          return XFile(result.files.single.path!);
        }
      }
    } else {
      // 桌面端使用file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null && result.files.single.path != null) {
        return XFile(result.files.single.path!);
      }
    }
  } catch (e) {
    print('选择视频出错: $e');
  }
  return null;
}

/// 跨平台文件选择方法
Future<XFile?> pickFile() async {
  try {
    if (kIsWeb) {
      // Web端使用file_picker并获取文件数据
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        withData: true, // 确保获取文件数据
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // 创建一个带有bytes的XFile
          String mimeType = 'application/octet-stream';
          if (file.extension != null) {
            switch (file.extension!.toLowerCase()) {
              case 'pdf':
                mimeType = 'application/pdf';
                break;
              case 'doc':
              case 'docx':
                mimeType = 'application/msword';
                break;
              case 'xls':
              case 'xlsx':
                mimeType = 'application/vnd.ms-excel';
                break;
              case 'ppt':
              case 'pptx':
                mimeType = 'application/vnd.ms-powerpoint';
                break;
              case 'txt':
                mimeType = 'text/plain';
                break;
              case 'zip':
                mimeType = 'application/zip';
                break;
              case 'rar':
                mimeType = 'application/x-rar-compressed';
                break;
            }
          }
          return XFile.fromData(
            file.bytes!,
            name: file.name,
            mimeType: mimeType,
          );
        }
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      // 移动端使用file_picker，但添加更多错误处理
      try {
        // 尝试使用file_picker
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
          dialogTitle: '选择文件',
        );

        if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
          return XFile(result.files.first.path!);
        }
      } catch (mobileError) {
        print('移动端file_picker失败: $mobileError');
        // 尝试使用备选方案
        try {
          // 使用更简单的配置再次尝试
          FilePickerResult? result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.single.path != null) {
            return XFile(result.files.single.path!);
          }
        } catch (fallbackError) {
          print('备选file_picker也失败: $fallbackError');
        }
      }
    } else {
      // 桌面端使用file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        return XFile(result.files.single.path!);
      }
    }
  } catch (e) {
    print('选择文件出错: $e');
  }
  return null;
}

/// 获取文件大小的格式化字符串
String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
