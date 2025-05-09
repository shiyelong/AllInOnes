import 'package:flutter/material.dart';
import '../tools/complete_data_cleaner.dart';

/// 数据清理页面
/// 提供用户界面来清理聊天记录和相关数据
class DataCleanupPage extends StatefulWidget {
  const DataCleanupPage({Key? key}) : super(key: key);

  @override
  _DataCleanupPageState createState() => _DataCleanupPageState();
}

class _DataCleanupPageState extends State<DataCleanupPage> {
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('数据清理工具'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '聊天记录清理',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '清理所有聊天记录和相关媒体文件，包括图片、视频、音频和文件。此操作不可撤销。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _cleanChatData,
                      child: Text('清理聊天记录'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '应用重置',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '完全重置应用，清除所有数据，包括聊天记录、登录状态和应用设置。此操作不可撤销，应用将自动关闭。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _resetApp,
                      child: Text('重置应用'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_statusMessage.isNotEmpty) ...[
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
            Spacer(),
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在处理，请稍候...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 清理聊天数据
  Future<void> _cleanChatData() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认清理'),
        content: Text('确定要清理所有聊天记录和相关媒体文件吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('确定'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在清理聊天记录...';
    });

    try {
      final result = await CompleteDataCleaner.cleanAllData(context);

      setState(() {
        _isLoading = false;
        if (result['success']) {
          _statusMessage = '清理完成！已清理 ${result['cleanedPrefs']} 条聊天记录，'
              '删除 ${result['deletedMediaFiles']} 个媒体文件和 '
              '${result['deletedThumbnails']} 个缩略图。';
        } else {
          _statusMessage = '清理失败: ${result['error']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '清理过程中发生错误: $e';
      });
    }
  }

  /// 重置应用
  Future<void> _resetApp() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认重置'),
        content: Text('确定要完全重置应用吗？所有数据将被清除，应用将自动关闭。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('确定'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在重置应用...';
    });

    try {
      await CompleteDataCleaner.resetApp(context);
      // 注意：resetApp会自动关闭应用，所以这里不需要设置状态
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '重置过程中发生错误: $e';
      });
    }
  }
}
