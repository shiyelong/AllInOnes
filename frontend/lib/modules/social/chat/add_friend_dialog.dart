import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/widgets/app_button.dart';
import 'package:frontend/widgets/app_text_field.dart';
import 'package:frontend/common/theme.dart';

class AddFriendDialog extends StatefulWidget {
  final void Function(Map<String, dynamic> friendData)? onAdd;
  final void Function(List<Map<String, dynamic>> searchResults)? onSearch;

  const AddFriendDialog({Key? key, this.onAdd, this.onSearch}) : super(key: key);

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _loading = false;
  String? _error;

  // 搜索结果
  List<Map<String, dynamic>> _searchResults = [];

  // 推荐好友列表
  List<Map<String, dynamic>> _recommendedFriends = [];

  // 选中的用户
  Map<String, dynamic>? _selectedUser;

  // 添加好友的来源
  String _sourceType = 'search'; // search, scan, recommend

  // 性别筛选
  String? _selectedGender;

  // 标签控制器
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 默认验证消息
    _messageController.text = '我是${Persistence.getUserInfo()?.nickname ?? Persistence.getUserInfo()?.account ?? ''}，请求添加您为好友';

    // 加载推荐好友
    _loadRecommendedFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // 加载推荐好友
  Future<void> _loadRecommendedFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        setState(() {
          _error = '未获取到当前用户信息，请重新登录';
          _loading = false;
        });
        return;
      }

      // 调用API获取推荐好友
      final response = await Api.getRecommendedFriends(
        currentUserId: userId.toString(),
        limit: 20,
        gender: _selectedGender,
      );

      debugPrint('推荐好友响应: $response');

      if (response['success'] == true) {
        final results = List<Map<String, dynamic>>.from(response['data'] ?? []);

        setState(() {
          _recommendedFriends = results;
          _loading = false;
        });

        if (results.isEmpty) {
          setState(() => _error = '暂无推荐好友');
        }
      } else {
        setState(() {
          _error = response['msg'] ?? '获取推荐好友失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络异常或服务器错误: $e';
        _loading = false;
      });
    }
  }

  // 搜索用户
  Future<void> _searchUsers() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() => _error = '请输入搜索关键词');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _searchResults = [];
      _selectedUser = null;
    });

    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        setState(() {
          _error = '未获取到当前用户信息，请重新登录';
          _loading = false;
        });
        return;
      }

      // 调用API搜索用户
      final response = await Api.searchUsers(
        keyword: keyword,
        currentUserId: userId.toString(),
        gender: _selectedGender,
      );

      if (response['success'] == true) {
        final results = List<Map<String, dynamic>>.from(response['data'] ?? []);

        setState(() {
          _searchResults = results;
          _loading = false;
        });

        // 回调搜索结果
        widget.onSearch?.call(results);

        if (results.isEmpty) {
          setState(() => _error = '未找到匹配的用户');
        }
      } else {
        setState(() {
          _error = response['msg'] ?? '搜索失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络异常或服务器错误: $e';
        _loading = false;
      });
    }
  }

  // 添加好友
  Future<void> _addFriend() async {
    if (_selectedUser == null) {
      setState(() => _error = '请先选择要添加的好友');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        setState(() {
          _error = '未获取到当前用户信息，请重新登录';
          _loading = false;
        });
        return;
      }

      // 如果已经是好友，直接返回
      if (_selectedUser!['is_friend'] == true) {
        setState(() {
          _error = '该用户已经是您的好友';
          _loading = false;
        });
        return;
      }

      // 如果有待处理的请求，提示用户
      if (_selectedUser!['has_pending_request'] == true) {
        setState(() {
          _error = '已有待处理的好友请求，请等待处理或查看好友请求列表';
          _loading = false;
        });
        return;
      }

      // 打印调试信息
      print('添加好友参数: userId=${userId}, friendId=${_selectedUser!['id']}, message=${_messageController.text}, sourceType=${_sourceType}');

      // 调用API添加好友
      final response = await Api.addFriend(
        userId: userId.toString(),
        friendId: _selectedUser!['id'].toString(),
        message: _messageController.text,
        sourceType: _sourceType,
      );

      if (response['success'] == true) {
        if (mounted) Navigator.of(context).pop();

        // 回调添加结果
        widget.onAdd?.call({
          ..._selectedUser!,
          'auto_accepted': response['auto_accepted'] == true,
        });

        final msg = response['msg'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _error = response['msg'] ?? '添加失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络异常或服务器错误: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width < 600
            ? double.infinity
            : 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '添加好友',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 标签栏
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              indicatorColor: AppTheme.primaryColor,
              tabs: [
                Tab(text: '搜索好友'),
                Tab(text: '推荐好友'),
                Tab(text: '扫码添加'),
              ],
            ),

            // 标签内容
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 搜索好友标签
                  _buildSearchTab(),

                  // 推荐好友标签
                  _buildRecommendedTab(),

                  // 扫码添加标签
                  _buildScanTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 搜索标签
  Widget _buildSearchTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 搜索框
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _searchController,
                  labelText: '账号/昵称',
                  hintText: '输入账号或昵称搜索',
                  errorText: _error,
                  enabled: !_loading,
                  onSubmitted: (_) => _searchUsers(),
                  prefixIcon: Icons.search,
                ),
              ),
              SizedBox(width: 8),
              AppButton(
                onPressed: _loading ? null : _searchUsers,
                text: '搜索',
                isLoading: _loading,
                minWidth: 80,
              ),
            ],
          ),

          // 性别筛选
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text('性别筛选:', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              _buildGenderFilterChip('全部', null),
              SizedBox(width: 4),
              _buildGenderFilterChip('男', '男'),
              SizedBox(width: 4),
              _buildGenderFilterChip('女', '女'),
              SizedBox(width: 4),
              _buildGenderFilterChip('未知', '未知'),
            ],
          ),

          SizedBox(height: 16),

          // 搜索结果
          if (_searchResults.isNotEmpty) ...[
            Text(
              '搜索结果 (${_searchResults.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final isSelected = _selectedUser != null &&
                      _selectedUser!['id'] == user['id'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatar'] != null && user['avatar'].isNotEmpty
                          ? NetworkImage(user['avatar'])
                          : null,
                      child: user['avatar'] == null || user['avatar'].isEmpty
                          ? Text(user['nickname']?.substring(0, 1) ??
                                user['account']?.substring(0, 1) ?? '?')
                          : null,
                    ),
                    title: Row(
                      children: [
                        Text(
                          user['nickname'] ?? user['account'] ?? '未知用户',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        SizedBox(width: 4),
                        _buildGenderIcon(user['gender']),
                      ],
                    ),
                    subtitle: Text('账号: ${user['account']}'),
                    trailing: _buildUserStatusChip(user),
                    selected: isSelected,
                    selectedTileColor: Colors.blue.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedUser = isSelected ? null : user;
                      });
                    },
                  );
                },
              ),
            ),
          ],

          if (_selectedUser != null) ...[
            SizedBox(height: 16),

            // 验证消息
            AppTextField(
              controller: _messageController,
              labelText: '验证消息',
              hintText: '请输入验证消息',
              maxLines: 2,
              enabled: !_loading,
            ),

            SizedBox(height: 16),

            // 添加按钮
            AppButton(
              onPressed: _loading || _selectedUser == null ||
                        _selectedUser!['is_friend'] == true ||
                        _selectedUser!['has_pending_request'] == true
                  ? null
                  : _addFriend,
              text: '添加好友',
              isLoading: _loading,
              color: AppTheme.primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  // 扫码标签
  Widget _buildScanTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '扫描二维码添加好友',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '请点击下方按钮打开相机扫描好友二维码',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 24),
          AppButton(
            onPressed: () {
              // 设置来源类型为扫码
              setState(() {
                _sourceType = 'scan';
              });

              // TODO: 实现扫码功能
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('扫码功能即将上线，敬请期待！'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            text: '打开相机扫码',
            icon: Icons.camera_alt,
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  // 推荐好友标签
  Widget _buildRecommendedTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 性别筛选
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text('性别筛选:', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              _buildGenderFilterChip('全部', null),
              SizedBox(width: 4),
              _buildGenderFilterChip('男', '男'),
              SizedBox(width: 4),
              _buildGenderFilterChip('女', '女'),
              SizedBox(width: 4),
              _buildGenderFilterChip('未知', '未知'),
            ],
          ),

          SizedBox(height: 8),

          // 刷新按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _loading ? null : _loadRecommendedFriends,
                icon: Icon(Icons.refresh, size: 16),
                label: Text('刷新推荐'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(0, 0),
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          // 推荐好友列表
          if (_recommendedFriends.isNotEmpty) ...[
            Text(
              '推荐好友 (${_recommendedFriends.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _recommendedFriends.length,
                itemBuilder: (context, index) {
                  final user = _recommendedFriends[index];
                  final isSelected = _selectedUser != null &&
                      _selectedUser!['id'] == user['id'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatar'] != null && user['avatar'].isNotEmpty
                          ? NetworkImage(user['avatar'])
                          : null,
                      child: user['avatar'] == null || user['avatar'].isEmpty
                          ? Text(user['nickname']?.substring(0, 1) ??
                                user['account']?.substring(0, 1) ?? '?')
                          : null,
                    ),
                    title: Row(
                      children: [
                        Text(
                          user['nickname'] ?? user['account'] ?? '未知用户',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        SizedBox(width: 4),
                        _buildGenderIcon(user['gender']),
                      ],
                    ),
                    subtitle: Text('账号: ${user['account']}'),
                    trailing: _buildUserStatusChip(user),
                    selected: isSelected,
                    selectedTileColor: Colors.blue.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedUser = isSelected ? null : user;
                        _sourceType = 'recommend';
                      });
                    },
                  );
                },
              ),
            ),
          ] else if (_loading) ...[
            Center(
              child: CircularProgressIndicator(),
            ),
          ] else ...[
            Center(
              child: Text(_error ?? '暂无推荐好友'),
            ),
          ],

          if (_selectedUser != null) ...[
            SizedBox(height: 16),

            // 验证消息
            AppTextField(
              controller: _messageController,
              labelText: '验证消息',
              hintText: '请输入验证消息',
              maxLines: 2,
              enabled: !_loading,
            ),

            SizedBox(height: 16),

            // 添加按钮
            AppButton(
              onPressed: _loading || _selectedUser == null ||
                        _selectedUser!['is_friend'] == true ||
                        _selectedUser!['has_pending_request'] == true
                  ? null
                  : _addFriend,
              text: '添加好友',
              isLoading: _loading,
              color: AppTheme.primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  // 性别筛选芯片
  Widget _buildGenderFilterChip(String label, String? gender) {
    final isSelected = _selectedGender == gender;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedGender = selected ? gender : null;
        });

        // 重新加载数据
        if (_tabController.index == 0) {
          if (_searchController.text.isNotEmpty) {
            _searchUsers();
          }
        } else if (_tabController.index == 1) {
          _loadRecommendedFriends();
        }
      },
      backgroundColor: Colors.grey.withOpacity(0.1),
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : null,
        fontSize: 12,
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  // 性别图标
  Widget _buildGenderIcon(String? gender) {
    IconData icon;
    Color color;

    switch (gender) {
      case '男':
        icon = Icons.male;
        color = Colors.blue;
        break;
      case '女':
        icon = Icons.female;
        color = Colors.pink;
        break;
      case '未知':
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  // 用户状态标签
  Widget _buildUserStatusChip(Map<String, dynamic> user) {
    if (user['is_friend'] == true) {
      return Chip(
        label: Text('已是好友'),
        backgroundColor: Colors.green.withOpacity(0.2),
        labelStyle: TextStyle(color: Colors.green, fontSize: 12),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    } else if (user['has_pending_request'] == true) {
      return Chip(
        label: Text('请求处理中'),
        backgroundColor: Colors.orange.withOpacity(0.2),
        labelStyle: TextStyle(color: Colors.orange, fontSize: 12),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    } else {
      switch (user['friend_add_mode']) {
        case 0:
          return Chip(
            label: Text('自动通过'),
            backgroundColor: Colors.blue.withOpacity(0.2),
            labelStyle: TextStyle(color: Colors.blue, fontSize: 12),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        case 1:
          return Chip(
            label: Text('需要验证'),
            backgroundColor: Colors.purple.withOpacity(0.2),
            labelStyle: TextStyle(color: Colors.purple, fontSize: 12),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        case 2:
          return Chip(
            label: Text('拒绝所有'),
            backgroundColor: Colors.red.withOpacity(0.2),
            labelStyle: TextStyle(color: Colors.red, fontSize: 12),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        default:
          return SizedBox.shrink();
      }
    }
  }
}
