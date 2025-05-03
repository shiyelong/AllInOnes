import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../widgets/app_avatar.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/empty_state.dart';
import 'voice_call_page.dart';
import 'video_call_page.dart';

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({Key? key}) : super(key: key);

  @override
  _CallHistoryPageState createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _voiceCallRecords = [];
  List<dynamic> _videoCallRecords = [];
  int _voiceCallPage = 1;
  int _videoCallPage = 1;
  bool _hasMoreVoiceCalls = true;
  bool _hasMoreVideoCalls = true;
  final int _pageSize = 20;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userId = Persistence.getUserId() ?? '';
    _loadCallHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 加载通话历史
  Future<void> _loadCallHistory() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 加载语音通话记录
      final voiceResp = await Api.getVoiceCallRecords(
        page: _voiceCallPage,
        pageSize: _pageSize,
      );

      // 加载视频通话记录
      final videoResp = await Api.getVideoCallRecords(
        page: _videoCallPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (voiceResp['success'] == true && voiceResp['data'] != null) {
            final records = voiceResp['data']['records'] as List;
            if (_voiceCallPage == 1) {
              _voiceCallRecords = records;
            } else {
              _voiceCallRecords.addAll(records);
            }
            _hasMoreVoiceCalls = records.length >= _pageSize;
          }

          if (videoResp['success'] == true && videoResp['data'] != null) {
            final records = videoResp['data']['records'] as List;
            if (_videoCallPage == 1) {
              _videoCallRecords = records;
            } else {
              _videoCallRecords.addAll(records);
            }
            _hasMoreVideoCalls = records.length >= _pageSize;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载通话历史失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 加载更多语音通话记录
  Future<void> _loadMoreVoiceCalls() async {
    if (!_hasMoreVoiceCalls || _isLoading) return;
    _voiceCallPage++;
    await _loadCallHistory();
  }

  // 加载更多视频通话记录
  Future<void> _loadMoreVideoCalls() async {
    if (!_hasMoreVideoCalls || _isLoading) return;
    _videoCallPage++;
    await _loadCallHistory();
  }

  // 刷新通话历史
  Future<void> _refreshCallHistory() async {
    _voiceCallPage = 1;
    _videoCallPage = 1;
    _hasMoreVoiceCalls = true;
    _hasMoreVideoCalls = true;
    await _loadCallHistory();
  }

  // 格式化通话时长
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds秒';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes分${remainingSeconds > 0 ? '$remainingSeconds秒' : ''}';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours小时${minutes > 0 ? '$minutes分' : ''}';
    }
  }

  // 格式化通话时间
  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(date.year, date.month, date.day);

    if (callDate == today) {
      return '今天 ${DateFormat('HH:mm').format(date)}';
    } else if (callDate == yesterday) {
      return '昨天 ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('MM-dd HH:mm').format(date);
    }
  }

  // 获取通话状态文本
  String _getCallStatusText(dynamic record) {
    final status = record['status'];
    final isOutgoing = record['is_outgoing'];
    final duration = record['duration'];

    if (status == 1) { // 已接通
      return '通话时长: ${_formatDuration(duration)}';
    } else if (status == 2) { // 已拒绝
      return isOutgoing ? '对方已拒绝' : '已拒绝';
    } else if (status == 0) { // 未接通
      return isOutgoing ? '未接通' : '未接听';
    } else {
      return '未知状态';
    }
  }

  // 获取通话状态图标
  IconData _getCallStatusIcon(dynamic record) {
    final status = record['status'];
    final isOutgoing = record['is_outgoing'];

    if (status == 1) { // 已接通
      return Icons.call;
    } else if (status == 2) { // 已拒绝
      return isOutgoing ? Icons.call_end : Icons.call_end;
    } else if (status == 0) { // 未接通
      return isOutgoing ? Icons.call_missed_outgoing : Icons.call_missed;
    } else {
      return Icons.error;
    }
  }

  // 获取通话状态颜色
  Color _getCallStatusColor(dynamic record) {
    final status = record['status'];
    final isOutgoing = record['is_outgoing'];

    if (status == 1) { // 已接通
      return Colors.green;
    } else if (status == 2) { // 已拒绝
      return Colors.red;
    } else if (status == 0) { // 未接通
      return isOutgoing ? Colors.orange : Colors.red;
    } else {
      return Colors.grey;
    }
  }

  // 回拨
  void _callBack(dynamic record, bool isVoiceCall) {
    final otherUser = record['other_user'];
    final otherUserId = otherUser['id'].toString();
    final otherUserName = otherUser['nickname'] ?? otherUser['account'];
    final otherUserAvatar = otherUser['avatar'] ?? '';

    if (isVoiceCall) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceCallPage(
            userId: _userId,
            targetId: otherUserId,
            targetName: otherUserName,
            targetAvatar: otherUserAvatar,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallPage(
            userId: _userId,
            targetId: otherUserId,
            targetName: otherUserName,
            targetAvatar: otherUserAvatar,
          ),
        ),
      );
    }
  }

  // 构建通话记录列表项
  Widget _buildCallRecordItem(dynamic record, bool isVoiceCall) {
    final otherUser = record['other_user'];
    final otherUserName = otherUser['nickname'] ?? otherUser['account'];
    final otherUserAvatar = otherUser['avatar'] ?? '';
    final isOutgoing = record['is_outgoing'];
    final startTime = record['start_time'];

    return ListTile(
      leading: AppAvatar(
        avatarUrl: otherUserAvatar,
        size: 50,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatTime(startTime),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(
            isOutgoing ? Icons.call_made : Icons.call_received,
            size: 16,
            color: isOutgoing ? Colors.blue : Colors.green,
          ),
          const SizedBox(width: 4),
          Icon(
            isVoiceCall ? Icons.call : Icons.videocam,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _getCallStatusText(record),
              style: TextStyle(
                color: _getCallStatusColor(record),
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isVoiceCall ? Icons.call : Icons.videocam,
          color: AppTheme.primaryColor,
        ),
        onPressed: () => _callBack(record, isVoiceCall),
      ),
      onTap: () {
        // 查看通话详情
        showModalBottomSheet(
          context: context,
          builder: (context) => _buildCallDetailSheet(record, isVoiceCall),
        );
      },
    );
  }

  // 构建通话详情底部弹窗
  Widget _buildCallDetailSheet(dynamic record, bool isVoiceCall) {
    final otherUser = record['other_user'];
    final otherUserName = otherUser['nickname'] ?? otherUser['account'];
    final otherUserAvatar = otherUser['avatar'] ?? '';
    final isOutgoing = record['is_outgoing'];
    final startTime = record['start_time'];
    final endTime = record['end_time'];
    final duration = record['duration'];
    final status = record['status'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppAvatar(
                avatarUrl: otherUserAvatar,
                size: 60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherUserName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      otherUser['account'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailItem(
            icon: isVoiceCall ? Icons.call : Icons.videocam,
            title: isVoiceCall ? '语音通话' : '视频通话',
            subtitle: isOutgoing ? '呼出' : '呼入',
          ),
          _buildDetailItem(
            icon: Icons.access_time,
            title: '通话时间',
            subtitle: _formatTime(startTime),
          ),
          if (status == 1) // 已接通
            _buildDetailItem(
              icon: Icons.timer,
              title: '通话时长',
              subtitle: _formatDuration(duration),
            ),
          _buildDetailItem(
            icon: _getCallStatusIcon(record),
            title: '通话状态',
            subtitle: _getCallStatusText(record),
            iconColor: _getCallStatusColor(record),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: isVoiceCall ? Icons.call : Icons.videocam,
                label: '回拨',
                onTap: () {
                  Navigator.pop(context);
                  _callBack(record, isVoiceCall);
                },
              ),
              _buildActionButton(
                icon: Icons.message,
                label: '发消息',
                onTap: () {
                  // 跳转到聊天页面
                  Navigator.pop(context);
                  // TODO: 实现跳转到聊天页面
                },
              ),
              _buildActionButton(
                icon: Icons.person_add,
                label: '查看资料',
                onTap: () {
                  // 跳转到用户资料页面
                  Navigator.pop(context);
                  // TODO: 实现跳转到用户资料页面
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建详情项
  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '通话记录',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(
                icon: Icon(Icons.call),
                text: '语音通话',
              ),
              Tab(
                icon: Icon(Icons.videocam),
                text: '视频通话',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 语音通话记录
                _buildCallList(_voiceCallRecords, true, _loadMoreVoiceCalls),
                // 视频通话记录
                _buildCallList(_videoCallRecords, false, _loadMoreVideoCalls),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建通话记录列表
  Widget _buildCallList(List<dynamic> records, bool isVoiceCall, Future<void> Function() loadMore) {
    if (_isLoading && records.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (records.isEmpty) {
      return EmptyState(
        icon: isVoiceCall ? Icons.call : Icons.videocam,
        title: '暂无${isVoiceCall ? '语音' : '视频'}通话记录',
        subtitle: '您的${isVoiceCall ? '语音' : '视频'}通话记录将显示在这里',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCallHistory,
      child: ListView.builder(
        itemCount: records.length + 1, // +1 for loading indicator
        itemBuilder: (context, index) {
          if (index == records.length) {
            // 加载更多指示器
            if (_isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (isVoiceCall ? _hasMoreVoiceCalls : _hasMoreVideoCalls) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: TextButton(
                    onPressed: loadMore,
                    child: const Text('加载更多'),
                  ),
                ),
              );
            } else {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('没有更多记录了'),
                ),
              );
            }
          } else {
            // 通话记录项
            return _buildCallRecordItem(records[index], isVoiceCall);
          }
        },
      ),
    );
  }
}
