import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../../common/api.dart';
import '../../../../common/persistence.dart';
import '../../../../common/theme.dart';
import '../../../../common/theme_manager.dart';
import '../red_packet_detail_dialog.dart';

class RedPacketMessage extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isSelf;
  final Function(String) onSendText;

  const RedPacketMessage({
    Key? key,
    required this.message,
    required this.isSelf,
    required this.onSendText,
  }) : super(key: key);

  @override
  _RedPacketMessageState createState() => _RedPacketMessageState();
}

class _RedPacketMessageState extends State<RedPacketMessage> {
  bool _isGrabbing = false;
  bool _isGrabbed = false;
  double? _grabbedAmount;

  @override
  void initState() {
    super.initState();
    _checkIfGrabbed();
  }

  // 检查当前用户是否已经抢过这个红包
  Future<void> _checkIfGrabbed() async {
    try {
      // 解析红包信息
      final extra = widget.message['extra'];
      if (extra == null || extra.isEmpty) return;

      Map<String, dynamic> extraData;
      try {
        extraData = json.decode(extra);
      } catch (e) {
        print('解析红包信息失败: $e');
        return;
      }

      final redPacketId = extraData['red_packet_id'];
      if (redPacketId == null) return;

      // 获取红包详情
      final response = await Api.getRedPacketDetail(redPacketId: redPacketId.toString());
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final records = data['records'] ?? [];
        final userId = Persistence.getUserInfo()?.id;

        // 检查当前用户是否在抢红包记录中
        for (var record in records) {
          if (record['user_id'] == userId) {
            setState(() {
              _isGrabbed = true;
              _grabbedAmount = double.tryParse(record['amount'].toString()) ?? 0.0;
            });
            break;
          }
        }
      }
    } catch (e) {
      print('检查红包状态失败: $e');
    }
  }

  // 抢红包
  Future<void> _grabRedPacket() async {
    if (_isGrabbing || _isGrabbed) return;

    setState(() {
      _isGrabbing = true;
    });

    try {
      // 解析红包信息
      final extra = widget.message['extra'];
      if (extra == null || extra.isEmpty) {
        setState(() {
          _isGrabbing = false;
        });
        return;
      }

      Map<String, dynamic> extraData;
      try {
        extraData = json.decode(extra);
      } catch (e) {
        print('解析红包信息失败: $e');
        setState(() {
          _isGrabbing = false;
        });
        return;
      }

      final redPacketId = extraData['red_packet_id'];
      if (redPacketId == null) {
        setState(() {
          _isGrabbing = false;
        });
        return;
      }

      final userId = Persistence.getUserInfo()?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户信息不存在，请重新登录')),
        );
        setState(() {
          _isGrabbing = false;
        });
        return;
      }

      // 调用抢红包API
      final response = await Api.grabRedPacket(
        redPacketId: redPacketId.toString(),
        userId: userId.toString(),
      );

      if (response['success'] == true && response['data'] != null) {
        final amount = double.tryParse(response['data']['amount'].toString()) ?? 0.0;
        setState(() {
          _isGrabbed = true;
          _grabbedAmount = amount;
          _isGrabbing = false;
        });

        // 发送一条消息通知抢到了红包
        widget.onSendText('我抢到了${amount.toStringAsFixed(2)}元红包');

        // 显示抢到红包的详情
        _showRedPacketDetail(redPacketId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? '抢红包失败')),
        );
        setState(() {
          _isGrabbing = false;
        });
      }
    } catch (e) {
      print('抢红包失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('抢红包失败: $e')),
      );
      setState(() {
        _isGrabbing = false;
      });
    }
  }

  // 显示红包详情
  void _showRedPacketDetail(dynamic redPacketId) {
    showDialog(
      context: context,
      builder: (context) => RedPacketDetailDialog(
        redPacketId: redPacketId.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 解析红包信息
    final extra = widget.message['extra'];
    Map<String, dynamic> extraData = {};
    if (extra != null && extra.isNotEmpty) {
      try {
        extraData = json.decode(extra);
      } catch (e) {
        print('解析红包信息失败: $e');
      }
    }

    final greeting = extraData['greeting'] ?? '恭喜发财，大吉大利';
    final redPacketId = extraData['red_packet_id'];
    final amount = extraData['amount'];
    final count = extraData['count'];

    final theme = ThemeManager.currentTheme;
    final bgColor = widget.isSelf ? theme.selfMessageBubbleColor : theme.otherMessageBubbleColor;
    final textColor = widget.isSelf ? theme.selfMessageTextColor : theme.otherMessageTextColor;

    return GestureDetector(
      onTap: () {
        if (redPacketId != null) {
          if (_isGrabbed) {
            // 如果已经抢过，显示红包详情
            _showRedPacketDetail(redPacketId);
          } else if (!widget.isSelf) {
            // 如果是别人的红包且没抢过，抢红包
            _grabRedPacket();
          } else {
            // 如果是自己的红包，显示红包详情
            _showRedPacketDetail(redPacketId);
          }
        }
      },
      child: Container(
        width: 200,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isGrabbed ? Colors.grey[300] : Colors.red[700],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.redeem,
                  color: Colors.yellow,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    greeting,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_isGrabbed)
              Text(
                '已领取 ${_grabbedAmount?.toStringAsFixed(2)} 元',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              )
            else
              Text(
                widget.isSelf
                    ? '查看红包详情'
                    : _isGrabbing
                        ? '正在拆红包...'
                        : '点击拆红包',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            SizedBox(height: 8),
            Divider(
              color: Colors.white24,
              height: 1,
            ),
            SizedBox(height: 8),
            Text(
              '红包',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
