import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/widgets/app_button.dart';

class RedPacketDialog extends StatefulWidget {
  final int receiverId;
  final Function(double amount, String greeting) onSend;

  const RedPacketDialog({
    Key? key,
    required this.receiverId,
    required this.onSend,
  }) : super(key: key);

  @override
  _RedPacketDialogState createState() => _RedPacketDialogState();
}

class _RedPacketDialogState extends State<RedPacketDialog> {
  final amountController = TextEditingController();
  final greetingController = TextEditingController(text: '恭喜发财，大吉大利！');
  final countController = TextEditingController(text: '1');
  bool _isLoading = false;
  bool _useWallet = true;
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  @override
  void dispose() {
    amountController.dispose();
    greetingController.dispose();
    countController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletInfo() async {
    setState(() {
      _isLoadingWallet = true;
    });

    try {
      final resp = await Api.getWalletInfo();
      if (resp['success'] == true) {
        setState(() {
          _walletBalance = (resp['data']['balance'] as num).toDouble();
        });
      }
    } catch (e) {
      // 加载钱包信息失败，默认余额为0
    } finally {
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }

  Future<void> _sendRedPacket() async {
    final amount = double.tryParse(amountController.text);
    final greeting = greetingController.text;
    final count = int.tryParse(countController.text) ?? 1;

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    if (greeting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入祝福语')),
      );
      return;
    }

    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('红包数量必须大于0')),
      );
      return;
    }

    if (_useWallet && amount > _walletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('余额不足'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户信息不存在，请重新登录')),
        );
        return;
      }

      if (_useWallet) {
        // 使用钱包发红包
        debugPrint('[RedPacket] 发送红包: 发送者=${userInfo.id}, 接收者=${widget.receiverId}, 金额=$amount, 数量=$count');
      final resp = await Api.sendRedPacketWithWallet(
          targetId: widget.receiverId.toString(),
          amount: amount,
          greeting: greeting,
        );
      debugPrint('[RedPacket] 发送红包响应: $resp');

        if (resp['success'] == true) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('红包发送成功'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp['msg'] ?? '发送失败'), backgroundColor: Colors.red),
          );
        }
      } else {
        // 使用传统方式发红包
        widget.onSend(amount, greeting);
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络异常: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade500],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '发红包',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '给好友发个红包吧',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (_isLoadingWallet)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              )
            else
              SwitchListTile(
                title: Text('使用钱包余额'),
                subtitle: Text('当前余额: ¥${_walletBalance.toStringAsFixed(2)}'),
                value: _useWallet,
                onChanged: (value) {
                  setState(() {
                    _useWallet = value;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: '金额',
                hintText: '请输入红包金额',
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            TextField(
              controller: countController,
              decoration: InputDecoration(
                labelText: '红包数量',
                hintText: '请输入红包数量',
                prefixIcon: Icon(Icons.people, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: greetingController,
              decoration: InputDecoration(
                labelText: '祝福语',
                hintText: '请输入祝福语',
                prefixIcon: Icon(Icons.message, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text('取消'),
                ),
                AppButton(
                  onPressed: _isLoading ? null : _sendRedPacket,
                  text: '发送',
                  isLoading: _isLoading,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
