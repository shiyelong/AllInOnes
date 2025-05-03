import 'package:flutter/material.dart';
import 'package:frontend/common/search_service.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/widgets/app_search_bar.dart';
import 'package:frontend/widgets/app_avatar.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/modules/social/chat/chat_detail_page.dart';
import 'package:frontend/modules/social/chat/add_friend_dialog.dart';

/// 搜索结果页面
class SearchResultsPage extends StatefulWidget {
  /// 初始搜索关键词
  final String initialKeyword;

  /// 搜索类型
  final SearchType searchType;

  /// 构造函数
  const SearchResultsPage({
    Key? key,
    required this.initialKeyword,
    required this.searchType,
  }) : super(key: key);

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialKeyword;
    _performSearch(widget.initialKeyword);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _error = '请输入搜索关键词';
        _isLoading = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await SearchService.search(
        keyword: keyword,
        type: widget.searchType,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            _searchResults = result['data'] ?? [];
            if (_searchResults.isEmpty) {
              _error = '未找到匹配的结果';
            }
          } else {
            _error = result['msg'] ?? '搜索失败';
            _searchResults = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '搜索出错: $e';
          _searchResults = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          searchType: widget.searchType,
          controller: _searchController,
          width: 400,
          onSearch: _performSearch,
          autofocus: true,
          showSearchButton: true,
        ),
        backgroundColor: theme.isDark ? Color(0xFF1E1E1E) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('无搜索结果', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 根据搜索类型显示不同的结果列表
    switch (widget.searchType) {
      case SearchType.social:
      case SearchType.friend:
        return _buildUserList();
      case SearchType.chat:
        return _buildChatMessageList();
      case SearchType.game:
        return _buildGameList();
      case SearchType.plaza:
        return _buildPlazaList();
      case SearchType.global:
        return _buildGlobalResults();
      default:
        return _buildUserList();
    }
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final bool isFriend = user['is_friend'] == true;

        return ListTile(
          leading: AppAvatar(
            name: user['nickname'] ?? user['account'] ?? '用户',
            size: 40,
            imageUrl: user['avatar'],
          ),
          title: Text(user['nickname'] ?? user['account'] ?? '用户'),
          subtitle: Text(user['account'] ?? ''),
          trailing: isFriend
              ? ElevatedButton(
                  onPressed: () {
                    // 打开聊天页面
                    final currentUserId = Persistence.getUserInfo()?.id.toString() ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailPage(
                          userId: currentUserId,
                          targetId: user['id'].toString(),
                          targetName: user['nickname'] ?? user['account'] ?? '好友',
                          targetAvatar: user['avatar'] ?? '',
                        ),
                      ),
                    );
                  },
                  child: Text('发消息'),
                )
              : OutlinedButton(
                  onPressed: () {
                    // 显示添加好友对话框
                    showDialog(
                      context: context,
                      builder: (ctx) => AddFriendDialog(
                        onAdd: (friendData) {
                          // 刷新搜索结果
                          _performSearch(_searchController.text);
                          // 显示成功消息
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已发送好友请求'), backgroundColor: Colors.green),
                          );
                        },
                      ),
                    );
                  },
                  child: Text('加好友'),
                ),
          onTap: () {
            // 查看用户资料
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('查看用户资料功能开发中')),
            );
          },
        );
      },
    );
  }

  Widget _buildChatMessageList() {
    return Center(
      child: Text('聊天记录搜索功能开发中'),
    );
  }

  Widget _buildGameList() {
    return Center(
      child: Text('游戏搜索功能开发中'),
    );
  }

  Widget _buildPlazaList() {
    return Center(
      child: Text('广场搜索功能开发中'),
    );
  }

  Widget _buildGlobalResults() {
    return _buildUserList();
  }
}
