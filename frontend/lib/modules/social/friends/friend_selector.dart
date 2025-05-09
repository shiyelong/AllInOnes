import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme_manager.dart';

class FriendSelector extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onSelectionChanged;
  final List<Map<String, dynamic>>? initialSelection;
  final bool showSearch;

  const FriendSelector({
    Key? key,
    required this.onSelectionChanged,
    this.initialSelection,
    this.showSearch = true,
  }) : super(key: key);

  @override
  _FriendSelectorState createState() => _FriendSelectorState();
}

class _FriendSelectorState extends State<FriendSelector> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  List<Map<String, dynamic>> _selectedFriends = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSelection != null) {
      _selectedFriends = List.from(widget.initialSelection!);
    }
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        throw Exception('用户未登录');
      }

      final result = await Api.getFriendsList(userId: userInfo.id.toString());
      if (result['success'] == true) {
        setState(() {
          _friends = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _filteredFriends = List.from(_friends);
        });
      } else {
        setState(() {
          _errorMessage = result['msg'] ?? '获取好友列表失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载好友列表失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = List.from(_friends);
      } else {
        _filteredFriends = _friends.where((friend) {
          final nickname = friend['nickname'] ?? '';
          final remark = friend['remark'] ?? '';
          return nickname.toLowerCase().contains(query.toLowerCase()) ||
              remark.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleFriendSelection(Map<String, dynamic> friend) {
    setState(() {
      final index = _selectedFriends.indexWhere((f) => f['friend_id'] == friend['friend_id']);
      if (index >= 0) {
        _selectedFriends.removeAt(index);
      } else {
        _selectedFriends.add(friend);
      }
      widget.onSelectionChanged(_selectedFriends);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Column(
      children: [
        // 搜索框
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索好友',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterFriends,
            ),
          ),

        // 已选择的好友
        if (_selectedFriends.isNotEmpty)
          Container(
            height: 90,
            margin: EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFriends.length,
              itemBuilder: (context, index) {
                final friend = _selectedFriends[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: friend['avatar'] != null && friend['avatar'].isNotEmpty
                                ? NetworkImage(friend['avatar'])
                                : null,
                            child: friend['avatar'] == null || friend['avatar'].isEmpty
                                ? Text(
                                    (friend['nickname'] ?? '').isNotEmpty
                                        ? (friend['nickname'] ?? '')[0]
                                        : '?',
                                    style: TextStyle(fontSize: 24),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => _toggleFriendSelection(friend),
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        friend['remark'] ?? friend['nickname'] ?? '',
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // 好友列表
        _isLoading
            ? Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                : _filteredFriends.isEmpty
                    ? Center(
                        child: Text('没有找到好友'),
                      )
                    : Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, index) {
                            final friend = _filteredFriends[index];
                            final isSelected = _selectedFriends.any(
                                (f) => f['friend_id'] == friend['friend_id']);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: friend['avatar'] != null && friend['avatar'].isNotEmpty
                                    ? NetworkImage(friend['avatar'])
                                    : null,
                                child: friend['avatar'] == null || friend['avatar'].isEmpty
                                    ? Text(
                                        (friend['nickname'] ?? '').isNotEmpty
                                            ? (friend['nickname'] ?? '')[0]
                                            : '?',
                                      )
                                    : null,
                              ),
                              title: Text(friend['remark'] ?? friend['nickname'] ?? ''),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleFriendSelection(friend),
                                activeColor: theme.primaryColor,
                              ),
                              onTap: () => _toggleFriendSelection(friend),
                            );
                          },
                        ),
                      ),
      ],
    );
  }
}
