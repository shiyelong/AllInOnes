import 'package:flutter/material.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/theme.dart';
import '../../../widgets/app_avatar.dart';

class RedPacketDetailDialog extends StatefulWidget {
  final String redPacketId;

  const RedPacketDetailDialog({
    Key? key,
    required this.redPacketId,
  }) : super(key: key);

  @override
  _RedPacketDetailDialogState createState() => _RedPacketDetailDialogState();
}

class _RedPacketDetailDialogState extends State<RedPacketDetailDialog> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _redPacketData = {};
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRedPacketDetail();
  }

  // 加载红包详情
  Future<void> _loadRedPacketDetail() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final response = await Api.getRedPacketDetail(redPacketId: widget.redPacketId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _redPacketData = response['data'];
          _records = List<Map<String, dynamic>>.from(_redPacketData['records'] ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _error = response['msg'] ?? '获取红包详情失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '获取红包详情出错: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 320,
        constraints: BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 红包头部
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.redeem,
                    color: Colors.yellow,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _redPacketData['greeting'] ?? '恭喜发财，大吉大利',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '红包金额：${_redPacketData['amount'] ?? 0.0} 元',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '已领取 ${_records.length}/${_redPacketData['count'] ?? 0} 个',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // 红包记录
            Flexible(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error, style: TextStyle(color: Colors.red)),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadRedPacketDetail,
                                child: Text('重试'),
                              ),
                            ],
                          ),
                        )
                      : _records.isEmpty
                          ? Center(
                              child: Text('暂无人领取红包'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _records.length,
                              itemBuilder: (context, index) {
                                final record = _records[index];
                                final userId = record['user_id'];
                                final amount = record['amount'];
                                final createdAt = record['created_at'];
                                final nickname = record['nickname'] ?? '用户$userId';
                                final avatar = record['avatar'];
                                final isCurrentUser = userId == Persistence.getUserInfo()?.id;
                                final isBest = index == 0; // 第一个是手气最佳

                                return ListTile(
                                  leading: AppAvatar(
                                    name: nickname,
                                    size: 40,
                                    imageUrl: avatar,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        nickname + (isCurrentUser ? ' (我)' : ''),
                                        style: TextStyle(
                                          fontWeight: isCurrentUser ? FontWeight.bold : null,
                                        ),
                                      ),
                                      if (isBest)
                                        Container(
                                          margin: EdgeInsets.only(left: 8),
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '手气最佳',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '领取时间：${DateTime.fromMillisecondsSinceEpoch((createdAt ?? 0) * 1000).toString().substring(0, 19)}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(
                                    '${amount ?? 0.0} 元',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            // 底部按钮
            Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('关闭'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
