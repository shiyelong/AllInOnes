import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/widgets/app_avatar.dart';
import 'package:frontend/common/widgets/app_button.dart';
import 'package:intl/intl.dart';

class RedPacketDetailPage extends StatefulWidget {
  final int redPacketId;

  const RedPacketDetailPage({
    Key? key,
    required this.redPacketId,
  }) : super(key: key);

  @override
  _RedPacketDetailPageState createState() => _RedPacketDetailPageState();
}

class _RedPacketDetailPageState extends State<RedPacketDetailPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _redPacket;
  List<Map<String, dynamic>> _records = [];
  bool _isGrabbing = false;
  bool _hasGrabbed = false;
  double _grabbedAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadRedPacketDetail();
  }

  Future<void> _loadRedPacketDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await Api.getRedPacketDetail(redPacketId: widget.redPacketId.toString());
      if (resp['success'] == true) {
        setState(() {
          _redPacket = Map<String, dynamic>.from(resp['data']['red_packet']);
          _records = List<Map<String, dynamic>>.from(resp['data']['records']);

          // 检查当前用户是否已经抢过红包
          final userInfo = Persistence.getUserInfo();
          if (userInfo != null) {
            for (var record in _records) {
              if (record['user_id'] == userInfo.id) {
                _hasGrabbed = true;
                _grabbedAmount = (record['amount'] as num).toDouble();
                break;
              }
            }
          }
        });
      } else {
        setState(() {
          _error = resp['msg'] ?? '获取红包详情失败';
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络异常: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _grabRedPacket() async {
    final userInfo = Persistence.getUserInfo();
    if (userInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('用户信息不存在，请重新登录')),
      );
      return;
    }

    setState(() {
      _isGrabbing = true;
    });

    try {
      final resp = await Api.grabRedPacketWithWallet(
        redPacketId: widget.redPacketId.toString(),
      );

      if (resp['success'] == true) {
        setState(() {
          _hasGrabbed = true;
          _grabbedAmount = (resp['data']['amount'] as num).toDouble();
        });

        // 重新加载红包详情
        await _loadRedPacketDetail();

        // 显示抢到的金额
        _showGrabbedAmountDialog(_grabbedAmount);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp['msg'] ?? '抢红包失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络异常: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isGrabbing = false;
      });
    }
  }

  void _showGrabbedAmountDialog(double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade500],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.celebration, color: Colors.yellow, size: 48),
                    SizedBox(height: 16),
                    Text(
                      '恭喜您抢到',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '¥${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '已存入您的钱包',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('确定', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 2).format(amount);
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('红包详情'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 24),
                      AppButton(
                        onPressed: _loadRedPacketDetail,
                        text: '重试',
                        icon: Icons.refresh,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // 红包信息
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade700, Colors.red.shade500],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                            // 发送者信息
                            Row(
                              children: [
                                AppAvatar(
                                  url: _redPacket?['sender_avatar'],
                                  size: 48,
                                ),
                                SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _redPacket?['sender_nickname'] ?? '未知用户',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '的红包',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            // 红包祝福语
                            Text(
                              _redPacket?['greeting'] ?? '',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            // 红包状态
                            if (_redPacket?['is_expired'] == true || _redPacket?['is_finished'] == true)
                              Text(
                                _redPacket?['is_expired'] == true ? '红包已过期' : '红包已抢完',
                                style: TextStyle(color: Colors.white70),
                              )
                            else if (_hasGrabbed)
                              Column(
                                children: [
                                  Text(
                                    '您已抢到',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _formatAmount(_grabbedAmount),
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            else
                              AppButton(
                                onPressed: _isGrabbing ? null : _grabRedPacket,
                                text: '抢红包',
                                isLoading: _isGrabbing,
                                color: Colors.red,
                              ),
                          ],
                        ),
                      ),
                      // 红包统计信息
                      Container(
                        padding: EdgeInsets.all(16),
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '总金额',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatAmount(_redPacket?['amount'] ?? 0.0),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  '红包个数',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_redPacket?['count'] ?? 0}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  '已抢个数',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${(_redPacket?['count'] ?? 0) - (_redPacket?['remaining_count'] ?? 0)}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1),
                      // 抢红包记录
                      Container(
                        padding: EdgeInsets.all(16),
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                        width: double.infinity,
                        child: Text(
                          '抢红包记录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Divider(height: 1),
                      // 记录列表
                      _records.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(32),
                              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                              child: Center(
                                child: Text(
                                  '暂无抢红包记录',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _records.length,
                              separatorBuilder: (context, index) => Divider(height: 1),
                              itemBuilder: (context, index) {
                                final record = _records[index];
                                final userId = record['user_id'];
                                final nickname = record['nickname'] ?? '未知用户';
                                final avatar = record['avatar'];
                                final amount = (record['amount'] as num).toDouble();
                                final createdAt = record['created_at'] as int;
                                final isBest = record['is_best'] == true;

                                // 检查是否是当前用户
                                final userInfo = Persistence.getUserInfo();
                                final isCurrentUser = userInfo != null && userInfo.id == userId;

                                return Container(
                                  color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      AppAvatar(url: avatar, size: 40),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  nickname,
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                if (isCurrentUser)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 8.0),
                                                    child: Text(
                                                      '(我)',
                                                      style: TextStyle(color: Colors.grey),
                                                    ),
                                                  ),
                                                if (isBest)
                                                  Container(
                                                    margin: EdgeInsets.only(left: 8),
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      '手气最佳',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              _formatDate(createdAt),
                                              style: TextStyle(color: Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _formatAmount(amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isBest ? Colors.red : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }
}
