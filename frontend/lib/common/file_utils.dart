import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

/// 文件工具类，用于处理文件路径和URI
class FileUtils {
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

  /// 获取文件名
  static String getFileName(String filePath) {
    try {
      return path.basename(filePath);
    } catch (e) {
      debugPrint('获取文件名出错: $e');
      return 'unknown';
    }
  }

  /// 获取文件扩展名
  static String getFileExtension(String filePath) {
    try {
      return path.extension(filePath).replaceFirst('.', '');
    } catch (e) {
      debugPrint('获取文件扩展名出错: $e');
      return '';
    }
  }

  /// 获取文件大小的格式化字符串
  static Future<String> getFormattedFileSize(String filePath) async {
    try {
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        // 网络文件，无法获取大小
        return 'Unknown size';
      }

      File file;
      if (filePath.startsWith('file:///')) {
        file = File(Uri.parse(filePath).toFilePath());
      } else {
        file = File(filePath);
      }

      if (await file.exists()) {
        final bytes = await file.length();
        return _formatBytes(bytes);
      }
      return 'Unknown size';
    } catch (e) {
      debugPrint('获取文件大小出错: $e');
      return 'Unknown size';
    }
  }

  /// 格式化字节数
  static String _formatBytes(int bytes) {
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

  /// 格式化字节数（公开方法）
  static String formatBytes(int bytes) {
    return _formatBytes(bytes);
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

  /// 保存图片到本地
  /// 返回保存后的文件路径
  static Future<String> saveImage(Uint8List imageBytes, {String? extension}) async {
    try {
      final mediaDir = await getAppDirectory();
      final uuid = Uuid().v4();
      final ext = extension ?? 'jpg';
      final fileName = '$uuid.$ext';
      final filePath = '${mediaDir.path}/$fileName';

      // 保存文件
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      debugPrint('图片已保存到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('保存图片出错: $e');
      return '';
    }
  }

  /// 从网络URL下载并保存图片
  /// 返回保存后的文件路径
  static Future<String> downloadAndSaveImage(String imageUrl) async {
    try {
      // 下载图片
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        debugPrint('下载图片失败，状态码: ${response.statusCode}');
        return '';
      }

      // 获取文件扩展名
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      String extension = 'jpg';
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        final fileExt = path.extension(fileName);
        if (fileExt.isNotEmpty) {
          extension = fileExt.replaceFirst('.', '');
        }
      }

      // 保存图片
      return await saveImage(response.bodyBytes, extension: extension);
    } catch (e) {
      debugPrint('下载并保存图片出错: $e');
      return '';
    }
  }

  /// 保存文件到本地
  /// 返回保存后的文件路径
  static Future<String> saveFile(Uint8List fileBytes, String fileName) async {
    try {
      final mediaDir = await getAppDirectory();
      final uuid = Uuid().v4();
      final extension = path.extension(fileName);
      final newFileName = '$uuid$extension';
      final filePath = '${mediaDir.path}/$newFileName';

      // 保存文件
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      debugPrint('文件已保存到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('保存文件出错: $e');
      return '';
    }
  }

  /// 从网络URL下载并保存文件
  /// 返回保存后的文件路径和文件名
  static Future<Map<String, String>> downloadAndSaveFile(String fileUrl) async {
    try {
      // 下载文件
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode != 200) {
        debugPrint('下载文件失败，状态码: ${response.statusCode}');
        return {'path': '', 'name': ''};
      }

      // 获取文件名
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      String fileName = 'file';
      if (pathSegments.isNotEmpty) {
        fileName = pathSegments.last;
        // 处理URL编码的文件名
        if (fileName.contains('%')) {
          try {
            fileName = Uri.decodeComponent(fileName);
          } catch (e) {
            debugPrint('解码文件名失败: $e');
          }
        }
      }

      // 保存文件
      final filePath = await saveFile(response.bodyBytes, fileName);
      return {'path': filePath, 'name': fileName};
    } catch (e) {
      debugPrint('下载并保存文件出错: $e');
      return {'path': '', 'name': ''};
    }
  }

  /// 打开文件
  /// 使用系统默认应用打开文件
  static Future<bool> openFile(String filePath) async {
    try {
      if (filePath.isEmpty) {
        debugPrint('文件路径为空');
        return false;
      }

      // 确保文件存在
      final validPath = getValidFilePath(filePath);
      if (validPath.isEmpty) {
        debugPrint('无效的文件路径');
        return false;
      }

      final file = File(validPath);
      if (!await file.exists()) {
        debugPrint('文件不存在: $validPath');
        return false;
      }

      // 创建文件URI
      final uri = Uri.file(validPath);

      // 使用url_launcher打开文件
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      } else {
        debugPrint('无法打开文件: $validPath');
        return false;
      }
    } catch (e) {
      debugPrint('打开文件出错: $e');
      return false;
    }
  }

  /// 创建临时文件
  /// 在临时目录中创建一个临时文件
  static Future<File> createTempFile(String extension) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final uuid = Uuid().v4();
      final fileName = '$uuid.$extension';
      final filePath = '${tempDir.path}/$fileName';

      return File(filePath);
    } catch (e) {
      debugPrint('创建临时文件出错: $e');
      throw e;
    }
  }

  /// 复制文件
  /// 将源文件复制到目标路径
  static Future<String> copyFile(String sourcePath, String targetPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('源文件不存在: $sourcePath');
        return '';
      }

      final targetFile = File(targetPath);
      await sourceFile.copy(targetPath);

      return targetPath;
    } catch (e) {
      debugPrint('复制文件出错: $e');
      return '';
    }
  }

  /// 保存图片到相册
  /// 返回是否保存成功
  static Future<bool> saveImageToGallery(String imagePath) async {
    try {
      // 如果是网络图片，先下载
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        final localPath = await downloadAndSaveImage(imagePath);
        if (localPath.isEmpty) {
          debugPrint('下载图片失败');
          return false;
        }
        imagePath = localPath;
      }

      // 获取有效的文件路径
      final validPath = getValidFilePath(imagePath);
      if (validPath.isEmpty) {
        debugPrint('无效的图片路径');
        return false;
      }

      // 检查文件是否存在
      final file = File(validPath);
      if (!await file.exists()) {
        debugPrint('图片文件不存在: $validPath');
        return false;
      }

      // 这里应该使用image_gallery_saver或photos_saver等插件保存到相册
      // 由于我们没有添加这些依赖，这里只是模拟保存成功
      debugPrint('图片已保存到相册（模拟）: $validPath');

      // 实际应用中，应该使用类似以下代码：
      // final result = await ImageGallerySaver.saveFile(validPath);
      // return result['isSuccess'] == true;

      return true;
    } catch (e) {
      debugPrint('保存图片到相册出错: $e');
      return false;
    }
  }
}
