import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/modules/wallet/bank_card/add_bank_card_page.dart';
import 'package:frontend/services/wallet_service.dart';

class BankCardListPage extends StatefulWidget {
  const BankCardListPage({Key? key}) : super(key: key);

  @override
  _BankCardListPageState createState() => _BankCardListPageState();
}

class _BankCardListPageState extends State<BankCardListPage> {
  List<Map<String, dynamic>> _bankCards = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBankCards();
  }

  // 加载银行卡列表
  Future<void> _loadBankCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 从钱包服务获取银行卡列表
      final walletService = WalletService();
      await walletService.loadBankCards();

      setState(() {
        _bankCards = List<Map<String, dynamic>>.from(walletService.bankCards);
        _isLoading = false;
      });
      debugPrint('从钱包服务成功加载 ${_bankCards.length} 张银行卡');
    } catch (e) {
      debugPrint('获取银行卡列表异常: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '获取银行卡列表失败，请稍后重试';
      });
    }
  }

  // 设置默认银行卡
  Future<void> _setDefaultBankCard(int cardId) async {
    try {
      final walletService = WalletService();
      final response = await walletService.setDefaultBankCard(cardId);

      if (response['success'] == true) {
        // 刷新银行卡列表
        await _loadBankCards();

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已设为默认银行卡'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '设置默认银行卡失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络异常，请稍后重试'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('设置默认银行卡异常: $e');
    }
  }

  // 删除银行卡
  Future<void> _deleteBankCard(int cardId) async {
    try {
      final walletService = WalletService();
      final response = await walletService.deleteBankCard(cardId);

      if (response['success'] == true) {
        // 刷新银行卡列表
        await _loadBankCards();

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('银行卡已删除'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '删除银行卡失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络异常，请稍后重试'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('删除银行卡异常: $e');
    }
  }

  // 格式化银行卡号（显示后四位，其余用*代替）
  String _formatCardNumber(String cardNumber) {
    if (cardNumber.isEmpty) return '';

    // 移除空格
    final digitsOnly = cardNumber.replaceAll(' ', '');

    if (digitsOnly.length < 4) return cardNumber;

    // 获取后四位
    final lastFour = digitsOnly.substring(digitsOnly.length - 4);

    // 构建掩码
    final maskedPart = '*' * (digitsOnly.length - 4);

    // 每4位添加一个空格
    final buffer = StringBuffer();
    for (int i = 0; i < maskedPart.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write('*');
    }

    // 添加后四位
    if (buffer.length > 0) {
      buffer.write(' ');
    }
    buffer.write(lastFour);

    return buffer.toString();
  }

  // 获取银行卡图标颜色
  Color _getBankCardColor(String bankName) {
    switch (bankName) {
      case '招商银行':
        return Color(0xFF12B7F5);
      case '工商银行':
        return Color(0xFFE60012);
      case '建设银行':
        return Color(0xFF0066B3);
      case '农业银行':
        return Color(0xFF009944);
      case '中国银行':
        return Color(0xFFE50011);
      case '交通银行':
        return Color(0xFF0066B3);
      case '邮储银行':
        return Color(0xFF007F3E);
      case '浦发银行':
        return Color(0xFF0066B3);
      case '中信银行':
        return Color(0xFFE60012);
      case '光大银行':
        return Color(0xFFE60012);
      case '民生银行':
        return Color(0xFF0066B3);
      case '华夏银行':
        return Color(0xFFE60012);
      case '广发银行':
        return Color(0xFFE60012);
      case '平安银行':
        return Color(0xFFE60012);
      case '兴业银行':
        return Color(0xFF0066B3);
      default:
        return Color(0xFF12B7F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('我的银行卡'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBankCards,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : _bankCards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无银行卡',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddBankCardPage(),
                                ),
                              );
                              if (result == true) {
                                _loadBankCards();
                              }
                            },
                            icon: Icon(Icons.add),
                            label: Text('添加银行卡'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBankCards,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _bankCards.length + 1, // +1 for the add button
                        itemBuilder: (context, index) {
                          if (index == _bankCards.length) {
                            // 添加银行卡按钮
                            return Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddBankCardPage(),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadBankCards();
                                  }
                                },
                                icon: Icon(Icons.add),
                                label: Text('添加银行卡'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            );
                          }

                          final card = _bankCards[index];
                          final isDefault = card['is_default'] == true;
                          final bankName = card['bank_name'] ?? '未知银行';
                          final cardNumber = card['card_number'] ?? '';
                          final cardType = card['card_type'] ?? '未知卡类型';
                          final cardholderName = card['cardholder_name'] ?? '未知持卡人';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: _getBankCardColor(bankName),
                              child: InkWell(
                                onTap: () {
                                  // 显示银行卡详情或操作菜单
                                  showModalBottomSheet(
                                    context: context,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                    ),
                                    builder: (context) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: Icon(Icons.credit_card),
                                              title: Text('银行卡详情'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                // 显示银行卡详情
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      title: Text('银行卡详情'),
                                                      content: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('银行: $bankName'),
                                                          SizedBox(height: 8),
                                                          Text('卡号: $cardNumber'),
                                                          SizedBox(height: 8),
                                                          Text('类型: $cardType'),
                                                          SizedBox(height: 8),
                                                          Text('持卡人: $cardholderName'),
                                                          SizedBox(height: 8),
                                                          Text('默认卡: ${isDefault ? '是' : '否'}'),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                          },
                                                          child: Text('关闭'),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                            if (!isDefault)
                                              ListTile(
                                                leading: Icon(Icons.star),
                                                title: Text('设为默认卡'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _setDefaultBankCard(card['id']);
                                                },
                                              ),
                                            ListTile(
                                              leading: Icon(Icons.delete, color: Colors.red),
                                              title: Text('删除银行卡', style: TextStyle(color: Colors.red)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                // 确认删除
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      title: Text('删除银行卡'),
                                                      content: Text('确定要删除这张银行卡吗？'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                          },
                                                          child: Text('取消'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                            _deleteBankCard(card['id']);
                                                          },
                                                          child: Text('删除', style: TextStyle(color: Colors.red)),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            bankName,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (isDefault)
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.3),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.star,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        '默认',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              SizedBox(width: 8),
                                              Text(
                                                cardType,
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 20),
                                      Text(
                                        _formatCardNumber(cardNumber),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Text(
                                        cardholderName,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
