import 'package:flutter/material.dart';
import '../../../common/message_cleaner.dart';
import '../../../common/thumbnail_manager.dart';
import '../../../common/video_thumbnail_manager.dart';
import '../../../common/file_preview_manager.dart';
import '../../../common/local_message_storage.dart';
import '../../../common/enhanced_file_utils.dart';
import '../../../common/persistence.dart';

/// 聊天记录清理工具页面
class ChatCleanerPage extends StatefulWidget {
  const ChatCleanerPage({Key? key}) : super(key: key);

  @override
  State<ChatCleanerPage> createState() => _ChatCleanerPageState();
}

class _ChatCleanerPageState extends State<ChatCleanerPage> {
  bool _isLoading = false;
  String _statusMessage = '';
  List<String> _logMessages = [];
  double _progress = 0.0;
  
  // 清理结果
  int _totalChats = 0;
  int _totalMessages = 0;
  int _cleanedMessages = 0;
  int _fixedMediaFiles = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天记录清理工具'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '聊天记录清理工具',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              '此工具将清理无效的聊天记录和修复媒体文件引用。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            
            // 进度条
            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text(_statusMessage),
                ],
              ),
            
            // 清理结果
            if (!_isLoading && _totalChats > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '清理结果',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('总聊天数: $_totalChats'),
                      Text('总消息数: $_totalMessages'),
                      Text('清理的消息数: $_cleanedMessages'),
                      Text('修复的媒体文件: $_fixedMediaFiles'),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _cleanAllMessages,
                  child: const Text('清理所有聊天记录'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _cleanupThumbnails,
                  child: const Text('清理缩略图缓存'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 日志区域
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '操作日志',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _logMessages.length,
                          itemBuilder: (context, index) {
                            return Text(
                              _logMessages[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 添加日志
  void _addLog(String message) {
    setState(() {
      _logMessages.add('[${DateTime.now().toString().split('.').first}] $message');
    });
  }
  
  /// 清理所有聊天记录
  Future<void> _cleanAllMessages() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在清理聊天记录...';
      _progress = 0.1;
      _logMessages = [];
    });
    
    try {
      _addLog('开始清理聊天记录');
      
      // 清理聊天记录
      final result = await MessageCleaner.cleanAllMessages();
      
      if (result['success'] == true) {
        setState(() {
          _totalChats = result['totalChats'] ?? 0;
          _totalMessages = result['totalMessages'] ?? 0;
          _cleanedMessages = result['cleanedMessages'] ?? 0;
          _fixedMediaFiles = result['fixedMediaFiles'] ?? 0;
          _progress = 0.7;
          _statusMessage = '聊天记录清理完成，正在清理缓存...';
        });
        
        _addLog('聊天记录清理完成');
        _addLog('总聊天数: $_totalChats');
        _addLog('总消息数: $_totalMessages');
        _addLog('清理的消息数: $_cleanedMessages');
        _addLog('修复的媒体文件: $_fixedMediaFiles');
        
        // 清理缩略图缓存
        await _cleanupThumbnailsInternal();
        
        setState(() {
          _isLoading = false;
          _progress = 1.0;
          _statusMessage = '清理完成';
        });
        
        _addLog('清理完成');
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = '清理失败: ${result['error']}';
        });
        
        _addLog('清理失败: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '清理异常: $e';
      });
      
      _addLog('清理异常: $e');
    }
  }
  
  /// 清理缩略图缓存
  Future<void> _cleanupThumbnails() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在清理缩略图缓存...';
      _progress = 0.1;
      _logMessages = [];
    });
    
    try {
      await _cleanupThumbnailsInternal();
      
      setState(() {
        _isLoading = false;
        _progress = 1.0;
        _statusMessage = '缩略图缓存清理完成';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '清理缩略图缓存异常: $e';
      });
      
      _addLog('清理缩略图缓存异常: $e');
    }
  }
  
  /// 清理缩略图缓存（内部方法）
  Future<void> _cleanupThumbnailsInternal() async {
    _addLog('开始清理缩略图缓存');
    
    // 清理图片缩略图
    setState(() {
      _progress = 0.3;
      _statusMessage = '正在清理图片缩略图...';
    });
    
    await ThumbnailManager.cleanupInvalidThumbnails();
    _addLog('图片缩略图清理完成');
    
    // 清理视频缩略图
    setState(() {
      _progress = 0.5;
      _statusMessage = '正在清理视频缩略图...';
    });
    
    await VideoThumbnailManager.cleanupInvalidThumbnails();
    _addLog('视频缩略图清理完成');
    
    // 清理文件预览
    setState(() {
      _progress = 0.7;
      _statusMessage = '正在清理文件预览...';
    });
    
    await FilePreviewManager.cleanupInvalidPreviews();
    _addLog('文件预览清理完成');
    
    // 清理临时文件
    setState(() {
      _progress = 0.9;
      _statusMessage = '正在清理临时文件...';
    });
    
    await EnhancedFileUtils.cleanupTemporaryFiles();
    _addLog('临时文件清理完成');
    
    setState(() {
      _progress = 1.0;
      _statusMessage = '缩略图缓存清理完成';
    });
    
    _addLog('缩略图缓存清理完成');
  }
}
