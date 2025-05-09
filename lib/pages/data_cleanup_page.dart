import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../common/theme_manager.dart';

/// 数据清理页面
/// 用于清理应用缓存、聊天记录等数据
class DataCleanupPage extends StatefulWidget {
  const DataCleanupPage({Key? key}) : super(key: key);

  @override
  _DataCleanupPageState createState() => _DataCleanupPageState();
}

class _DataCleanupPageState extends State<DataCleanupPage> {
  bool _isLoading = true;
  Map<String, int> _cacheSize = {};
  int _totalCacheSize = 0;
  
  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }
  
  /// 加载缓存大小
  Future<void> _loadCacheSize() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      
      // 获取应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      
      // 计算图片缓存大小
      final imageCacheSize = await _calculateDirectorySize('${tempDir.path}/image_cache');
      
      // 计算语音缓存大小
      final voiceCacheSize = await _calculateDirectorySize('${tempDir.path}/voice_cache');
      
      // 计算视频缓存大小
      final videoCacheSize = await _calculateDirectorySize('${tempDir.path}/video_cache');
      
      // 计算文件缓存大小
      final fileCacheSize = await _calculateDirectorySize('${tempDir.path}/file_cache');
      
      // 计算聊天记录大小
      final chatHistorySize = await _calculateDirectorySize('${appDocDir.path}/chat_history');
      
      // 计算其他缓存大小
      final otherCacheSize = await _calculateDirectorySize(tempDir.path) - imageCacheSize - voiceCacheSize - videoCacheSize - fileCacheSize;
      
      // 更新缓存大小
      setState(() {
        _cacheSize = {
          '图片缓存': imageCacheSize,
          '语音缓存': voiceCacheSize,
          '视频缓存': videoCacheSize,
          '文件缓存': fileCacheSize,
          '聊天记录': chatHistorySize,
          '其他缓存': otherCacheSize > 0 ? otherCacheSize : 0,
        };
        
        _totalCacheSize = _cacheSize.values.fold(0, (sum, size) => sum + size);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[DataCleanupPage] 加载缓存大小失败: $e');
      
      setState(() {
        _cacheSize = {
          '图片缓存': 0,
          '语音缓存': 0,
          '视频缓存': 0,
          '文件缓存': 0,
          '聊天记录': 0,
          '其他缓存': 0,
        };
        
        _totalCacheSize = 0;
        _isLoading = false;
      });
    }
  }
  
  /// 计算目录大小
  Future<int> _calculateDirectorySize(String path) async {
    try {
      final directory = Directory(path);
      
      // 如果目录不存在，返回0
      if (!await directory.exists()) {
        return 0;
      }
      
      int size = 0;
      
      // 遍历目录中的所有文件
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      
      return size;
    } catch (e) {
      debugPrint('[DataCleanupPage] 计算目录大小失败: $path, $e');
      return 0;
    }
  }
  
  /// 清理缓存
  Future<void> _cleanCache(String type) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      
      // 获取应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      
      String path;
      
      switch (type) {
        case '图片缓存':
          path = '${tempDir.path}/image_cache';
          break;
        case '语音缓存':
          path = '${tempDir.path}/voice_cache';
          break;
        case '视频缓存':
          path = '${tempDir.path}/video_cache';
          break;
        case '文件缓存':
          path = '${tempDir.path}/file_cache';
          break;
        case '聊天记录':
          path = '${appDocDir.path}/chat_history';
          break;
        case '其他缓存':
          path = tempDir.path;
          
          // 清理其他缓存时，不删除特定的缓存目录
          await _cleanDirectory(path, excludeDirs: [
            '${tempDir.path}/image_cache',
            '${tempDir.path}/voice_cache',
            '${tempDir.path}/video_cache',
            '${tempDir.path}/file_cache',
          ]);
          
          // 重新加载缓存大小
          await _loadCacheSize();
          return;
        case '全部缓存':
          // 清理所有缓存
          await _cleanDirectory('${tempDir.path}/image_cache');
          await _cleanDirectory('${tempDir.path}/voice_cache');
          await _cleanDirectory('${tempDir.path}/video_cache');
          await _cleanDirectory('${tempDir.path}/file_cache');
          await _cleanDirectory(tempDir.path, excludeDirs: [
            '${tempDir.path}/image_cache',
            '${tempDir.path}/voice_cache',
            '${tempDir.path}/video_cache',
            '${tempDir.path}/file_cache',
          ]);
          
          // 重新加载缓存大小
          await _loadCacheSize();
          return;
        default:
          return;
      }
      
      // 清理指定目录
      await _cleanDirectory(path);
      
      // 重新加载缓存大小
      await _loadCacheSize();
    } catch (e) {
      debugPrint('[DataCleanupPage] 清理缓存失败: $type, $e');
      
      setState(() {
        _isLoading = false;
      });
      
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理缓存失败: $e')),
      );
    }
  }
  
  /// 清理目录
  Future<void> _cleanDirectory(String path, {List<String> excludeDirs = const []}) async {
    try {
      final directory = Directory(path);
      
      // 如果目录不存在，返回
      if (!await directory.exists()) {
        return;
      }
      
      // 遍历目录中的所有文件和子目录
      await for (final entity in directory.list()) {
        // 如果是排除的目录，跳过
        if (excludeDirs.contains(entity.path)) {
          continue;
        }
        
        try {
          // 删除文件或目录
          await entity.delete(recursive: true);
        } catch (e) {
          debugPrint('[DataCleanupPage] 删除文件或目录失败: ${entity.path}, $e');
        }
      }
    } catch (e) {
      debugPrint('[DataCleanupPage] 清理目录失败: $path, $e');
    }
  }
  
  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('数据清理'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCacheSize,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 总缓存大小
                Container(
                  padding: EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Text(
                        '总缓存大小',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _formatFileSize(_totalCacheSize),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _totalCacheSize > 0
                            ? () => _showCleanConfirmDialog('全部缓存')
                            : null,
                        child: Text('一键清理'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Divider(),
                
                // 缓存列表
                Expanded(
                  child: ListView.builder(
                    itemCount: _cacheSize.length,
                    itemBuilder: (context, index) {
                      final type = _cacheSize.keys.elementAt(index);
                      final size = _cacheSize.values.elementAt(index);
                      
                      return ListTile(
                        title: Text(type),
                        subtitle: Text(_formatFileSize(size)),
                        trailing: TextButton(
                          onPressed: size > 0
                              ? () => _showCleanConfirmDialog(type)
                              : null,
                          child: Text('清理'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
  
  /// 显示清理确认对话框
  void _showCleanConfirmDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清理确认'),
        content: Text('确定要清理$type吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cleanCache(type);
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}
