import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'camera_page.dart';

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

/// 跨平台拍照方法
///
/// 使用camera包实现的摄像头页面，提供更稳定的拍照体验
/// 在移动端和桌面端都使用自定义摄像头页面
/// 在Web端不支持
Future<XFile?> takePhoto({BuildContext? context}) async {
  try {
    if (kIsWeb) {
      // Web端暂不支持直接拍照
      print('Web端暂不支持直接拍照');
      return null;
    }

    // 确保有context
    if (context == null) {
      print('拍照需要提供BuildContext');
      return null;
    }

    // 检查摄像头权限
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      try {
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          print('摄像头权限被拒绝');

          // 显示权限提示对话框
          final bool shouldRetry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('需要摄像头权限'),
              content: Text('拍照功能需要访问您的摄像头。请在系统设置中允许应用访问摄像头。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('去设置'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldRetry) {
            await openAppSettings();
            // 用户可能已经更改了权限设置，重新检查
            final newStatus = await Permission.camera.status;
            if (newStatus.isDenied || newStatus.isPermanentlyDenied) {
              // 用户仍然拒绝权限，回退到图片选择
              return await _fallbackToGallery(context);
            }
          } else {
            // 用户取消，回退到图片选择
            return await _fallbackToGallery(context);
          }
        }
      } catch (e) {
        print('请求摄像头权限出错: $e');
        // 继续执行，因为在某些平台上可能不需要显式请求权限
      }
    }

    try {
      // 使用自定义摄像头页面
      final XFile? result = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraPage(),
        ),
      );

      if (result != null) {
        return result;
      }

      // 用户取消了拍照
      return null;
    } catch (e) {
      print('摄像头页面出错: $e');

      // 显示错误对话框
      final bool shouldRetry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('摄像头错误'),
          content: Text('无法访问摄像头: $e\n\n您可以重试或从相册选择图片。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('从相册选择'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('重试'),
            ),
          ],
        ),
      ) ?? false;

      if (shouldRetry) {
        // 用户选择重试
        return await takePhoto(context: context);
      } else {
        // 用户选择从相册选择
        return await _fallbackToGallery(context);
      }
    }
  } catch (e) {
    print('拍照出错: $e');

    // 如果有context，显示错误提示
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
      );

      // 回退到图片选择
      return await _fallbackToGallery(context);
    }
  }
  return null;
}

/// 回退到从相册选择图片
Future<XFile?> _fallbackToGallery(BuildContext context) async {
  try {
    final ImagePicker picker = ImagePicker();
    return await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
  } catch (e) {
    print('从相册选择图片失败: $e');

    // 尝试使用file_picker作为最后的备选方案
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        dialogTitle: '选择图片',
      );

      if (result != null && result.files.single.path != null) {
        return XFile(result.files.single.path!);
      }
    } catch (fallbackError) {
      print('备选文件选择也失败: $fallbackError');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法选择图片: $fallbackError'), backgroundColor: Colors.red),
      );
    }
    return null;
  }
}

/// 显示图片来源选择对话框
Future<XFile?> showImageSourceDialog(BuildContext context) async {
  final bool isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  // 在桌面平台上，我们提供更多选项
  if (isDesktop) {
    final String? option = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('选择图片来源'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'camera');
              },
              child: ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('拍照'),
                subtitle: Text('使用摄像头拍摄照片'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'gallery');
              },
              child: ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('从相册选择'),
                subtitle: Text('从图片库中选择照片'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'file');
              },
              child: ListTile(
                leading: Icon(Icons.folder_open),
                title: Text('浏览文件'),
                subtitle: Text('从文件系统选择图片文件'),
              ),
            ),
          ],
        );
      },
    );

    if (option == null) return null;

    try {
      if (option == 'camera') {
        // 尝试使用摄像头，传递context参数
        return await takePhoto(context: context);
      } else if (option == 'gallery') {
        // 使用图片库
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);

        // 如果选择了图片，显示预览和确认对话框
        if (image != null) {
          final bool shouldSend = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('发送图片'),
              content: Image.file(
                File(image.path),
                height: 200,
                fit: BoxFit.contain,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('发送'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldSend) {
            return image;
          } else {
            return null; // 用户取消发送
          }
        }
        return null;
      } else if (option == 'file') {
        // 使用文件选择器
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          dialogTitle: '选择图片文件',
        );

        if (result != null && result.files.single.path != null) {
          final path = result.files.single.path!;

          // 显示预览和确认对话框
          final bool shouldSend = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('发送图片'),
              content: Image.file(
                File(path),
                height: 200,
                fit: BoxFit.contain,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('发送'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldSend) {
            return XFile(path);
          } else {
            return null; // 用户取消发送
          }
        }
      }
    } catch (e) {
      print('选择/拍摄图片失败: $e');
      return null;
    }

    return null;
  } else {
    // 在移动平台上，使用标准的图片选择对话框
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('选择图片来源'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, ImageSource.camera);
              },
              child: ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('拍照'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, ImageSource.gallery);
              },
              child: ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('从相册选择'),
              ),
            ),
          ],
        );
      },
    );

    if (source == null) return null;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      // 如果选择了图片，显示预览和确认对话框
      if (image != null) {
        final bool shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('发送图片'),
            content: Image.file(
              File(image.path),
              height: 200,
              fit: BoxFit.contain,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('发送'),
              ),
            ],
          ),
        ) ?? false;

        if (shouldSend) {
          return image;
        } else {
          return null; // 用户取消发送
        }
      }
      return null;
    } catch (e) {
      print('选择/拍摄图片失败: $e');
      return null;
    }
  }
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
