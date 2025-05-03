import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/text_sanitizer.dart';
import 'package:frontend/widgets/app_button.dart';
import 'package:timeago/timeago.dart' as timeago;

class FriendRequestsPage extends StatefulWidget {
  final Function()? onRequestProcessed;

  const FriendRequestsPage({Key? key, this.onRequestProcessed}) : super(key: key);

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  // 标签控制器
  late TabController _tabController;

  // 当前选中的标签索引
  int _currentTabIndex = 0;

  // 标签列表
  final List<String> _tabs = ['收到的请求', '发出的请求'];

  // 请求类型
  final List<String> _requestTypes = ['received', 'sent'];

  // 状态过滤
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);

    // 加载好友请求
    _loadFriendRequests();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // 处理标签变化
  void _handleTabChange() {
    if (_tabController.indexIsChanging || _tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
      _loadFriendRequests();
    }
  }

  // 加载好友请求
  Future<void> _loadFriendRequests() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      setState(() {
        _error = '未获取到用户信息，请重新登录';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Api.getFriendRequests(
        userId: userId.toString(),
        type: _requestTypes[_currentTabIndex],
        status: _statusFilter,
      );

      if (response['success'] == true) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response['data'] ?? []);
          _isLoading = false;
        });

        if (_requests.isEmpty) {
          setState(() {
            _error = '暂无${_tabs[_currentTabIndex]}';
          });
        }
      } else {
        setState(() {
          _error = response['msg'] ?? '获取好友请求失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络异常或服务器错误: $e';
        _isLoading = false;
      });
    }
  }

  // 同意好友请求
  Future<void> _agreeRequest(Map<String, dynamic> request) async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未获取到用户信息，请重新登录'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Api.agreeFriendRequest(
        requestId: request['id'].toString(),
        userId: userId.toString(),
      );

      if (response['success'] == true) {
        // 刷新列表
        await _loadFriendRequests();

        // 获取好友信息
        final friendName = TextSanitizer.sanitize(
          request['from_user']['nickname'] ??
          request['from_user']['account'] ??
          '好友'
        );

        // 显示成功消息，包含更多信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已同意 $friendName 的好友请求，现在可以开始聊天了'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: '查看好友',
              textColor: Colors.white,
              onPressed: () {
                // 返回到好友列表页面
                Navigator.pop(context);
              },
            ),
          ),
        );

        // 回调
        widget.onRequestProcessed?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '操作失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络异常或服务器错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 拒绝好友请求
  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未获取到用户信息，请重新登录'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Api.rejectFriendRequest(
        requestId: request['id'].toString(),
        userId: userId.toString(),
      );

      if (response['success'] == true) {
        // 刷新列表
        await _loadFriendRequests();

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已拒绝好友请求'),
            backgroundColor: Colors.orange,
          ),
        );

        // 回调
        widget.onRequestProcessed?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '操作失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络异常或服务器错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 批量同意好友请求
  Future<void> _batchAgreeRequests() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未获取到用户信息，请重新登录'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没有待处理的好友请求'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取所有待处理请求的ID
      final List<String> requestIds = _requests
          .where((req) => req['status'] == 0)
          .map((req) => req['id'].toString())
          .toList();

      if (requestIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('没有待处理的好友请求'), backgroundColor: Colors.orange),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await Api.batchAgreeFriendRequests(
        userId: userId.toString(),
        requestIds: requestIds,
      );

      if (response['success'] == true) {
        // 刷新列表
        await _loadFriendRequests();

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已同意所有好友请求'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 回调
        widget.onRequestProcessed?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '批量操作失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络异常或服务器错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 批量拒绝好友请求
  Future<void> _batchRejectRequests() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未获取到用户信息，请重新登录'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没有待处理的好友请求'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取所有待处理请求的ID
      final List<String> requestIds = _requests
          .where((req) => req['status'] == 0)
          .map((req) => req['id'].toString())
          .toList();

      if (requestIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('没有待处理的好友请求'), backgroundColor: Colors.orange),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await Api.batchRejectFriendRequests(
        userId: userId.toString(),
        requestIds: requestIds,
      );

      if (response['success'] == true) {
        // 刷新列表
        await _loadFriendRequests();

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已拒绝所有好友请求'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        // 回调
        widget.onRequestProcessed?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '批量操作失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络异常或服务器错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('好友请求'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          indicatorColor: AppTheme.primaryColor,
        ),
        actions: [
          // 状态过滤菜单
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: '状态过滤',
            onSelected: (value) {
              setState(() {
                _statusFilter = value;
              });
              _loadFriendRequests();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      color: _statusFilter == 'pending' ? AppTheme.primaryColor : null,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '待处理',
                      style: TextStyle(
                        fontWeight: _statusFilter == 'pending' ? FontWeight.bold : FontWeight.normal,
                        color: _statusFilter == 'pending' ? AppTheme.primaryColor : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'accepted',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: _statusFilter == 'accepted' ? Colors.green : null,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '已同意',
                      style: TextStyle(
                        fontWeight: _statusFilter == 'accepted' ? FontWeight.bold : FontWeight.normal,
                        color: _statusFilter == 'accepted' ? Colors.green : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rejected',
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      color: _statusFilter == 'rejected' ? Colors.red : null,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '已拒绝',
                      style: TextStyle(
                        fontWeight: _statusFilter == 'rejected' ? FontWeight.bold : FontWeight.normal,
                        color: _statusFilter == 'rejected' ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive,
                      color: _statusFilter == 'all' ? Colors.blue : null,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '全部',
                      style: TextStyle(
                        fontWeight: _statusFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                        color: _statusFilter == 'all' ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 刷新按钮
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _isLoading ? null : _loadFriendRequests,
          ),
        ],
      ),
      // 添加底部操作栏，方便用户快速处理请求
      bottomNavigationBar: _currentTabIndex == 0 && _requests.isNotEmpty && _statusFilter == 'pending'
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '您有 ${_requests.length} 个待处理的好友请求',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // 显示批量处理对话框
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('批量处理好友请求'),
                            content: Text('您确定要批量处理所有好友请求吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  // 批量拒绝
                                  _batchRejectRequests();
                                },
                                child: Text('全部拒绝'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  // 批量同意
                                  _batchAgreeRequests();
                                },
                                child: Text('全部同意'),
                                style: TextButton.styleFrom(foregroundColor: Colors.green),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('批量处理'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null && _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 24),
                      AppButton(
                        onPressed: _loadFriendRequests,
                        text: '刷新',
                        icon: Icons.refresh,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFriendRequests,
                  child: ListView.builder(
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      return _buildRequestItem(request);
                    },
                  ),
                ),
    );
  }

  // 构建请求项
  Widget _buildRequestItem(Map<String, dynamic> request) {
    // 获取用户信息（根据当前标签选择发送者或接收者）
    final user = _currentTabIndex == 0
        ? request['from_user'] as Map<String, dynamic>
        : request['to_user'] as Map<String, dynamic>;

    // 获取请求状态
    final status = request['status'] as int;
    final isPending = status == 0;

    // 获取请求时间
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (request['created_at'] as int) * 1000,
    );

    // 获取验证消息
    final message = request['message'] as String? ?? '';

    // 卡片颜色根据状态变化
    Color cardColor = Colors.white;
    if (_currentTabIndex == 0 && isPending) {
      cardColor = Colors.blue.withOpacity(0.05);
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cardColor,
      elevation: isPending ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPending ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
          width: isPending ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 用户信息
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: user['avatar'] != null && user['avatar'].isNotEmpty
                      ? NetworkImage(user['avatar'])
                      : null,
                  child: user['avatar'] == null || user['avatar'].isEmpty
                      ? Text(
                          user['nickname']?.substring(0, 1) ??
                              user['account']?.substring(0, 1) ?? '?',
                          style: TextStyle(fontSize: 18),
                        )
                      : null,
                ),
                if (isPending && _currentTabIndex == 0)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(Icons.notifications_active, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            title: Text(
              user['nickname'] ?? user['account'] ?? '未知用户',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isPending ? Colors.blue[800] : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('账号: ${user['account']}'),
                if (message.isNotEmpty && message.length < 30)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '消息: $message',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            trailing: _buildStatusChip(status),
          ),

          // 验证消息（仅当消息较长时显示完整内容）
          if (message.isNotEmpty && message.length >= 30)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '验证消息:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(message),
                  ),
                ],
              ),
            ),

          // 时间和来源
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  timeago.format(createdAt, locale: 'zh_CN'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(width: 16),
                if (request['source_type'] != null) ...[
                  Icon(
                    _getSourceTypeIcon(request['source_type']),
                    size: 14,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _getSourceTypeName(request['source_type']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 操作按钮（仅对待处理的收到的请求显示）
          if (_currentTabIndex == 0 && isPending)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _rejectRequest(request),
                      icon: Icon(Icons.close),
                      label: Text('拒绝'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _agreeRequest(request),
                      icon: Icon(Icons.check),
                      label: Text('同意'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 构建状态标签
  Widget _buildStatusChip(int status) {
    switch (status) {
      case 0:
        return Chip(
          label: Text('待处理'),
          backgroundColor: Colors.blue.withOpacity(0.2),
          labelStyle: TextStyle(color: Colors.blue, fontSize: 12),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case 1:
        return Chip(
          label: Text('已同意'),
          backgroundColor: Colors.green.withOpacity(0.2),
          labelStyle: TextStyle(color: Colors.green, fontSize: 12),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case 2:
        return Chip(
          label: Text('已拒绝'),
          backgroundColor: Colors.red.withOpacity(0.2),
          labelStyle: TextStyle(color: Colors.red, fontSize: 12),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      default:
        return Chip(
          label: Text('未知'),
          backgroundColor: Colors.grey.withOpacity(0.2),
          labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    }
  }

  // 获取来源类型图标
  IconData _getSourceTypeIcon(String sourceType) {
    switch (sourceType) {
      case 'search':
        return Icons.search;
      case 'scan':
        return Icons.qr_code_scanner;
      case 'recommend':
        return Icons.recommend;
      default:
        return Icons.link;
    }
  }

  // 获取来源类型名称
  String _getSourceTypeName(String sourceType) {
    switch (sourceType) {
      case 'search':
        return '搜索';
      case 'scan':
        return '扫码';
      case 'recommend':
        return '推荐';
      default:
        return '其他';
    }
  }
}
