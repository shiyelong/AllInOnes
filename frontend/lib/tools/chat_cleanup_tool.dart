import 'package:flutter/material.dart';
import 'package:frontend/common/local_message_storage.dart';
import 'package:frontend/common/image_thumbnail_generator.dart';
import 'package:frontend/common/enhanced_file_utils.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/theme_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 聊天清理工具
/// 用于清理聊天记录、缩略图缓存等
class ChatCleanupTool extends StatefulWidget {
  const ChatCleanupTool({Key? key}) : super(key: key);

  @override
  State<ChatCleanupTool> createState() => _ChatCleanupToolState();
}

class _ChatCleanupToolState extends State<ChatCleanupTool> {
  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;
  bool _deleteMediaFiles = true;
  bool _clearThumbnailCache = true;
  bool _clearServerMessages = false;

  // 存储统计信息
  int _totalChats = 0;
  num _totalMessages = 0;
  int _totalMediaFiles = 0;
  int _totalThumbnails = 0;
  int _totalCacheSize = 0; // 单位：字节

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  // 加载统计信息
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在加载统计信息...';
      _progress = 0.0;
    });

    try {
      // 获取聊天数量和消息数量
      await _countChatsAndMessages();

      // 获取媒体文件数量和缩略图数量
      await _countMediaFilesAndThumbnails();

      // 计算缓存大小
      await _calculateCacheSize();

      setState(() {
        _isLoading = false;
        _statusMessage = '统计信息加载完成';
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '加载统计信息失败: $e';
        _progress = 0.0;
      });
    }
  }

  // 统计聊天数量和消息数量
  Future<void> _countChatsAndMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    // 统计聊天数量
    final chatKeys = allKeys.where((key) =>
      key.startsWith('chat_messages_')
    ).toList();

    _totalChats = chatKeys.length;
    _totalMessages = 0;

    // 统计消息数量
    for (final key in chatKeys) {
      final messagesJson = prefs.getStringList(key) ?? [];
      _totalMessages += messagesJson.length;
    }
  }

  // 统计媒体文件数量和缩略图数量
  Future<void> _countMediaFilesAndThumbnails() async {
    try {
      // 获取媒体文件目录
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/chat_media');
      final thumbnailDir = Directory('${appDir.path}/thumbnails');

      // 统计媒体文件数量
      if (await mediaDir.exists()) {
        final files = await mediaDir.list().toList();
        _totalMediaFiles = files.where((entity) => entity is File).length;
      } else {
        _totalMediaFiles = 0;
      }

      // 统计缩略图数量
      if (await thumbnailDir.exists()) {
        final files = await thumbnailDir.list().toList();
        _totalThumbnails = files.where((entity) => entity is File).length;
      } else {
        _totalThumbnails = 0;
      }
    } catch (e) {
      debugPrint('统计媒体文件和缩略图数量失败: $e');
    }
  }

  // 计算缓存大小
  Future<void> _calculateCacheSize() async {
    try {
      // 获取媒体文件目录
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/chat_media');
      final thumbnailDir = Directory('${appDir.path}/thumbnails');

      int totalSize = 0;

      // 计算媒体文件大小
      if (await mediaDir.exists()) {
        final files = await mediaDir.list().toList();
        for (final entity in files) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      // 计算缩略图大小
      if (await thumbnailDir.exists()) {
        final files = await thumbnailDir.list().toList();
        for (final entity in files) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      _totalCacheSize = totalSize;
    } catch (e) {
      debugPrint('计算缓存大小失败: $e');
    }
  }

  // 清理所有聊天记录
  Future<void> _cleanupAllChats() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清理所有聊天记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要清理所有聊天记录吗？此操作不可恢复。'),
            SizedBox(height: 8),
            CheckboxListTile(
              title: Text('同时删除媒体文件'),
              value: _deleteMediaFiles,
              onChanged: (value) {
                setState(() {
                  _deleteMediaFiles = value ?? true;
                });
                Navigator.pop(context);
                _cleanupAllChats();
              },
            ),
            CheckboxListTile(
              title: Text('清除缩略图缓存'),
              value: _clearThumbnailCache,
              onChanged: (value) {
                setState(() {
                  _clearThumbnailCache = value ?? true;
                });
                Navigator.pop(context);
                _cleanupAllChats();
              },
            ),
            CheckboxListTile(
              title: Text('同时清除服务器消息'),
              value: _clearServerMessages,
              onChanged: (value) {
                setState(() {
                  _clearServerMessages = value ?? false;
                });
                Navigator.pop(context);
                _cleanupAllChats();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在清理聊天记录...';
      _progress = 0.0;
    });

    try {
      // 清除本地聊天记录
      final success = await LocalMessageStorage.clearAllMessages(
        deleteMediaFiles: _deleteMediaFiles,
        clearThumbnailCache: _clearThumbnailCache,
      );

      // 如果需要清除服务器消息，调用API
      if (_clearServerMessages) {
        final userInfo = Persistence.getUserInfo();
        if (userInfo != null) {
          try {
            final response = await Api.post('/chat/clear/all', data: {});
            if (response['success'] != true) {
              setState(() {
                _statusMessage = '清除服务器消息失败: ${response['msg']}';
              });
            }
          } catch (e) {
            setState(() {
              _statusMessage = '清除服务器消息失败: $e';
            });
          }
        }
      }

      // 重新加载统计信息
      await _loadStatistics();

      setState(() {
        _isLoading = false;
        _statusMessage = success ? '聊天记录清理成功' : '聊天记录清理失败';
        _progress = 1.0;
      });

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '聊天记录清理成功' : '聊天记录清理失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '清理聊天记录失败: $e';
        _progress = 0.0;
      });

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清理聊天记录失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 清理缩略图缓存
  Future<void> _cleanupThumbnailCache() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清理缩略图缓存'),
        content: Text('确定要清理缩略图缓存吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在清理缩略图缓存...';
      _progress = 0.0;
    });

    try {
      // 清除缩略图缓存
      final success = await LocalMessageStorage.clearThumbnailCache();

      // 重新加载统计信息
      await _loadStatistics();

      setState(() {
        _isLoading = false;
        _statusMessage = success ? '缩略图缓存清理成功' : '缩略图缓存清理失败';
        _progress = 1.0;
      });

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '缩略图缓存清理成功' : '缩略图缓存清理失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '清理缩略图缓存失败: $e';
        _progress = 0.0;
      });

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清理缩略图缓存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 格式化文件大小
  String _formatFileSize(int bytes) {
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('聊天清理工具'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStatistics,
            tooltip: '刷新统计信息',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计信息卡片
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('统计信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('聊天数量: $_totalChats'),
                    Text('消息数量: $_totalMessages'),
                    Text('媒体文件数量: $_totalMediaFiles'),
                    Text('缩略图数量: $_totalThumbnails'),
                    Text('缓存总大小: ${_formatFileSize(_totalCacheSize)}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.delete),
                  label: Text('清理所有聊天记录'),
                  onPressed: _isLoading ? null : _cleanupAllChats,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.image),
                  label: Text('清理缩略图缓存'),
                  onPressed: _isLoading ? null : _cleanupThumbnailCache,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 进度指示器
            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                  SizedBox(height: 8),
                  Text(_statusMessage),
                ],
              ),

            // 警告信息
            SizedBox(height: 16),
            Card(
              color: Colors.yellow[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('注意事项', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('1. 清理聊天记录后，所有聊天历史将被永久删除，无法恢复。'),
                    Text('2. 清理缩略图缓存不会删除原始图片，但可能需要重新生成缩略图。'),
                    Text('3. 如果选择"同时删除媒体文件"，所有聊天中的图片、视频和文件将被删除。'),
                    Text('4. 如果选择"同时清除服务器消息"，服务器上的聊天记录也将被删除。'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
