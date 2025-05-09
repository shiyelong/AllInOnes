import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/modules/social/chat/group/create_group_page.dart';
import 'package:frontend/modules/social/chat/group/group_chat_page.dart';
import 'package:frontend/widgets/app_avatar.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({Key? key}) : super(key: key);

  @override
  _GroupListPageState createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        throw Exception('用户未登录');
      }

      final result = await Api.getGroupList(userId: userInfo.id.toString());
      if (result['success'] == true) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
      } else {
        setState(() {
          _errorMessage = result['msg'] ?? '获取群组列表失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载群组列表失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createNewGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateGroupPage()),
    );

    if (result != null) {
      // 刷新群组列表
      _loadGroups();
    }
  }

  void _openGroupChat(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatPage(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('群聊'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _createNewGroup,
            tooltip: '创建群聊',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadGroups,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无群聊',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: Icon(Icons.add),
                            label: Text('创建群聊'),
                            onPressed: _createNewGroup,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadGroups,
                      child: ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: AppAvatar(
                                imageUrl: group['avatar'],
                                name: group['name'] ?? '群聊',
                                size: 50,
                                isGroup: true,
                              ),
                              title: Text(
                                group['name'] ?? '群聊',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                group['notice'] ?? '暂无群公告',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                '${group['member_count'] ?? 0}人',
                                style: TextStyle(color: Colors.grey),
                              ),
                              onTap: () => _openGroupChat(group),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _groups.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createNewGroup,
              child: Icon(Icons.add),
              tooltip: '创建群聊',
            )
          : null,
    );
  }
}
