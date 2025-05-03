import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/common/platform_utils.dart';
import 'package:frontend/common/widgets/app_button.dart';
import 'package:frontend/common/widgets/app_card.dart';
import 'package:frontend/modules/wallet/bank_card/bank_card_list_page.dart';
import 'package:frontend/services/wallet_service.dart';
import 'package:intl/intl.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({Key? key}) : super(key: key);

  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  int _currentPage = 1;
  bool _hasMoreTransactions = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWalletInfo();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore && _hasMoreTransactions) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _loadWalletInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 初始化钱包服务
      final success = await _walletService.initialize();
      if (!success) {
        setState(() {
          _error = '初始化钱包失败';
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

  Future<void> _loadTransactions() async {
    try {
      // 使用钱包服务加载交易记录
      await _walletService.loadTransactions();

      setState(() {
        _transactions = List<Map<String, dynamic>>.from(_walletService.transactions);
        _currentPage = 1;
        _hasMoreTransactions = _transactions.length >= 20;
      });

      debugPrint('成功加载 ${_transactions.length} 条交易记录');
    } catch (e) {
      debugPrint('加载交易记录异常: $e');
      setState(() {
        _error = '网络异常: $e';
      });
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // 目前钱包服务不支持分页加载，所以我们只显示已加载的交易记录
      // 在实际应用中，这里应该调用支持分页的API
      setState(() {
        _hasMoreTransactions = false;
      });
    } catch (e) {
      // 加载更多失败，不显示错误
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _showRechargeDialog() {
    final amountController = TextEditingController();
    int selectedCardId = -1;

    // 检查是否有银行卡
    if (_walletService.bankCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先添加银行卡'), action: SnackBarAction(
          label: '添加',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BankCardListPage(),
              ),
            );
          },
        )),
      );
      return;
    }

    // 默认选择第一张卡
    selectedCardId = _walletService.bankCards.first['id'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('充值'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: selectedCardId,
              decoration: InputDecoration(
                labelText: '选择银行卡',
                border: OutlineInputBorder(),
              ),
              items: _walletService.bankCards.map((card) {
                return DropdownMenuItem<int>(
                  value: card['id'],
                  child: Text('${card['bank_name']} (${card['card_number'].toString().substring(card['card_number'].toString().length - 4)})'),
                );
              }).toList(),
              onChanged: (value) {
                selectedCardId = value!;
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: '金额',
                hintText: '请输入充值金额',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            Text('注意：这是模拟充值，不会产生实际费用', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0 && selectedCardId > 0) {
                Navigator.pop(context);
                await _recharge(amount, selectedCardId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入有效金额并选择银行卡')),
                );
              }
            },
            child: Text('充值'),
          ),
        ],
      ),
    );
  }

  Future<void> _recharge(double amount, int bankCardId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _walletService.recharge(
        bankCardId: bankCardId,
        amount: amount,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('充值成功'), backgroundColor: Colors.green),
        );

        // 刷新交易记录
        await _loadTransactions();

        // 刷新UI显示新余额
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? '充值失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('充值异常: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络异常: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showTransferDialog() {
    final receiverIdController = TextEditingController();
    final amountController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('转账'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: receiverIdController,
              decoration: InputDecoration(
                labelText: '接收者ID',
                hintText: '请输入接收者ID',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: '金额',
                hintText: '请输入转账金额',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: '留言',
                hintText: '请输入转账留言（可选）',
                prefixIcon: Icon(Icons.message),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final receiverId = int.tryParse(receiverIdController.text);
              final amount = double.tryParse(amountController.text);
              if (receiverId != null && amount != null && amount > 0) {
                Navigator.pop(context);
                await _transfer(receiverId, amount, messageController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入有效的接收者ID和金额')),
                );
              }
            },
            child: Text('转账'),
          ),
        ],
      ),
    );
  }

  Future<void> _transfer(int receiverId, double amount, String message) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取用户信息
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户信息不存在，请重新登录')),
        );
        return;
      }

      if (userInfo.id == receiverId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('不能给自己转账'), backgroundColor: Colors.red),
        );
        return;
      }

      // 检查余额是否足够
      if (_walletService.balance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('余额不足'), backgroundColor: Colors.red),
        );
        return;
      }

      final response = await _walletService.transfer(
        receiverId: receiverId,
        amount: amount,
        message: message,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转账成功'), backgroundColor: Colors.green),
        );

        // 刷新交易记录
        await _loadTransactions();

        // 刷新UI显示新余额
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? '转账失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('转账异常: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络异常: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(locale: 'zh_CN', symbol: '¥', decimalDigits: 2).format(amount);
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  String _getTransactionTypeText(String type) {
    switch (type) {
      case 'recharge':
        return '充值';
      case 'withdraw':
        return '提现';
      case 'transfer_in':
        return '转入';
      case 'transfer_out':
        return '转出';
      case 'redpacket_in':
        return '收红包';
      case 'redpacket_out':
        return '发红包';
      default:
        return type;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'recharge':
      case 'transfer_in':
      case 'redpacket_in':
        return Colors.green;
      case 'withdraw':
      case 'transfer_out':
      case 'redpacket_out':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = (transaction['amount'] as num).toDouble();
    final balance = (transaction['balance'] as num).toDouble();
    final description = transaction['description'] as String;
    final createdAt = transaction['created_at'] as int;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(
          amount > 0 ? Icons.arrow_downward : Icons.arrow_upward,
          color: _getTransactionColor(type),
        ),
        title: Text(
          _getTransactionTypeText(type),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text(_formatDate(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              (amount > 0 ? '+' : '') + _formatAmount(amount),
              style: TextStyle(
                color: _getTransactionColor(type),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '余额: ${_formatAmount(balance)}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _walletService.refreshWalletInfo();

      if (success) {
        // 刷新交易记录
        await _loadTransactions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('钱包信息已更新'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新钱包信息失败'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint('刷新钱包信息异常: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新钱包信息失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('我的钱包'),
        backgroundColor: theme.primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshWallet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '钱包概览'),
            Tab(text: '交易记录'),
          ],
        ),
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
                        onPressed: _loadWalletInfo,
                        text: '重试',
                        icon: Icons.refresh,
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // 钱包概览
                    RefreshIndicator(
                      onRefresh: _refreshWallet,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '账户余额',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _formatAmount(_walletService.balance),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '钱包ID: ${_walletService.walletId ?? '未知'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: AppButton(
                                          onPressed: _showRechargeDialog,
                                          text: '充值',
                                          icon: Icons.add,
                                          color: Colors.green,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: AppButton(
                                          onPressed: _showTransferDialog,
                                          text: '转账',
                                          icon: Icons.send,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: AppButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => BankCardListPage(),
                                              ),
                                            );
                                          },
                                          text: '银行卡',
                                          icon: Icons.credit_card,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: AppButton(
                                          onPressed: () {
                                            // 暂未实现
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('虚拟货币功能即将上线')),
                                            );
                                          },
                                          text: '虚拟货币',
                                          icon: Icons.currency_bitcoin,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              '最近交易',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            _transactions.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Text(
                                        '暂无交易记录',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: _transactions
                                        .take(5)
                                        .map((transaction) => _buildTransactionItem(transaction))
                                        .toList(),
                                  ),
                            if (_transactions.length > 5)
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    _tabController.animateTo(1);
                                  },
                                  child: Text('查看更多'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // 交易记录
                    RefreshIndicator(
                      onRefresh: _loadTransactions,
                      child: _transactions.isEmpty
                          ? Center(
                              child: Text(
                                '暂无交易记录',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: AlwaysScrollableScrollPhysics(),
                              itemCount: _transactions.length + (_hasMoreTransactions ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < _transactions.length) {
                                  return _buildTransactionItem(_transactions[index]);
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? CircularProgressIndicator()
                                          : Text('加载更多...'),
                                    ),
                                  );
                                }
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
