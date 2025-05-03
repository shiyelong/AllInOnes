import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../common/theme.dart';
import '../../../common/theme_manager.dart';
import '../../../common/persistence.dart';
import '../../../common/api.dart';

class CleanChatMessages extends StatefulWidget {
  @override
  _CleanChatMessagesState createState() => _CleanChatMessagesState();
}

class _CleanChatMessagesState extends State<CleanChatMessages> {
  List<Map<String, dynamic>> _chatList = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  Set<String> _selectedChats = {};

  @override
  void initState() {
    super.initState();
    _loadChatList();
  }

  Future<void> _loadChatList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfo = Persistence.getUserInfo();

      if (userInfo == null) {
        setState(() {
          _isLoading = false;
          _chatList = [];
        });
        return;
      }

      final userId = userInfo.id.toString();
      final allKeys = prefs.getKeys();
      final chatKeys = allKeys.where((key) => key.startsWith('chat_messages_${userId}_')).toList();

      List<Map<String, dynamic>> chats = [];

      for (var key in chatKeys) {
        try {
          // 从键中提取目标用户ID
          final parts = key.split('_');
          if (parts.length < 3) {
            debugPrint('无效的聊天记录键: $key');
            continue;
          }
          final targetId = parts.last;

          // 获取最后一条消息
          final messagesJson = prefs.getString(key) ?? '[]';
          List<Map<String, dynamic>> messages = [];
          try {
            final List<dynamic> parsed = json.decode(messagesJson);
            messages = List<Map<String, dynamic>>.from(parsed);
          } catch (e) {
            debugPrint('解析消息失败: $e');
          }

          if (messages.isNotEmpty) {
            // 获取最后一条消息
            final lastMessage = messages.last;

            // 获取目标用户信息
            Map<String, dynamic>? targetInfo;
            try {
              final response = await Api.getUserById(targetId);
              if (response['success'] == true) {
                targetInfo = response['data'];
              }
            } catch (e) {
              debugPrint('获取用户信息失败: $e');
            }

            final targetName = targetInfo?['nickname'] ?? '用户$targetId';
            final targetAvatar = targetInfo?['avatar'] ?? '';

            chats.add({
              'key': key,
              'targetId': targetId,
              'targetName': targetName,
              'targetAvatar': targetAvatar,
              'lastMessage': lastMessage['content'] ?? '',
              'lastMessageTime': lastMessage['created_at'] ?? 0,
              'messageCount': messages.length,
            });
          } else {
            // 如果没有消息，也添加到列表中
            Map<String, dynamic>? targetInfo;
            try {
              final response = await Api.getUserById(targetId);
              if (response['success'] == true) {
                targetInfo = response['data'];
              }
            } catch (e) {
              debugPrint('获取用户信息失败: $e');
            }

            final targetName = targetInfo?['nickname'] ?? '用户$targetId';
            final targetAvatar = targetInfo?['avatar'] ?? '';

            chats.add({
              'key': key,
              'targetId': targetId,
              'targetName': targetName,
              'targetAvatar': targetAvatar,
              'lastMessage': '',
              'lastMessageTime': 0,
              'messageCount': 0,
            });
          }
        } catch (e) {
          debugPrint('处理聊天记录 $key 时出错: $e');
        }
      }

      // 按最后消息时间排序
      chats.sort((a, b) => (b['lastMessageTime'] as int).compareTo(a['lastMessageTime'] as int));

      setState(() {
        _chatList = chats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载聊天列表出错: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSelectedChats() async {
    if (_selectedChats.isEmpty) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      for (var key in _selectedChats) {
        try {
          await prefs.remove(key);

          // 同时删除对应的最后一条消息记录
          if (key.startsWith('chat_messages_')) {
            final parts = key.split('_');
            if (parts.length >= 3) {
              final fromId = parts[parts.length - 2];
              final toId = parts[parts.length - 1];
              final lastMessageKey = 'last_message_${fromId}_${toId}';
              if (prefs.containsKey(lastMessageKey)) {
                await prefs.remove(lastMessageKey);
                debugPrint('已删除最后一条消息记录: $lastMessageKey');
              }
            }
          }
        } catch (e) {
          debugPrint('删除聊天记录 $key 失败: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 ${_selectedChats.length} 个聊天记录')),
      );

      // 重新加载聊天列表
      _selectedChats.clear();
      await _loadChatList();
    } catch (e) {
      debugPrint('删除聊天记录出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理聊天记录失败: $e')),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  // 清理文本，确保是有效的 UTF-16 字符串
  String _sanitizeText(String text) {
    if (text.isEmpty) return '未知';

    try {
      // 尝试检测无效的 UTF-16 字符
      text.runes.toList();
      return text;
    } catch (e) {
      debugPrint('检测到无效的 UTF-16 字符: $e');

      // 尝试清理文本
      try {
        // 移除可能导致问题的字符
        return text
            .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '') // 控制字符
            .replaceAll(RegExp(r'[\uD800-\uDFFF]'), ''); // 代理对字符
      } catch (e) {
        debugPrint('清理文本失败: $e');
        return '无法显示的名称';
      }
    }
  }

  // 安全地获取文本的第一个字符
  String _getFirstChar(dynamic text) {
    if (text == null) return '?';

    String strText = text.toString();
    if (strText.isEmpty) return '?';

    try {
      // 尝试获取第一个字符
      return strText[0];
    } catch (e) {
      debugPrint('获取第一个字符失败: $e');
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('清理聊天记录'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedChats.isNotEmpty)
            TextButton(
              onPressed: _isDeleting ? null : _deleteSelectedChats,
              child: Text(
                '清理(${_selectedChats.length})',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _chatList.isEmpty
              ? Center(child: Text('没有聊天记录'))
              : ListView.builder(
                  itemCount: _chatList.length,
                  itemBuilder: (context, index) {
                    final chat = _chatList[index];
                    final isSelected = _selectedChats.contains(chat['key']);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.primaryColor.withOpacity(0.2),
                        child: Text(
                          _getFirstChar(chat['targetName']),
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        // 确保目标名称是有效的 UTF-16 字符串
                        _sanitizeText(chat['targetName'] ?? '未知用户'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${chat['messageCount']} 条消息',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: _isDeleting
                            ? null
                            : (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedChats.add(chat['key']);
                                  } else {
                                    _selectedChats.remove(chat['key']);
                                  }
                                });
                              },
                      ),
                      onTap: _isDeleting
                          ? null
                          : () {
                              setState(() {
                                if (isSelected) {
                                  _selectedChats.remove(chat['key']);
                                } else {
                                  _selectedChats.add(chat['key']);
                                }
                              });
                            },
                    );
                  },
                ),
      bottomNavigationBar: _selectedChats.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.primaryColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已选择 ${_selectedChats.length} 个聊天',
                      style: TextStyle(color: Colors.white),
                    ),
                    ElevatedButton(
                      onPressed: _isDeleting ? null : _deleteSelectedChats,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.primaryColor,
                      ),
                      child: Text(_isDeleting ? '清理中...' : '清理聊天记录'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
