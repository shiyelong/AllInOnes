import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_auth/http_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/api.dart';
import '../common/config.dart';
import '../common/persistence.dart';

class WalletService extends ChangeNotifier {
  // 单例模式
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  // 钱包状态
  bool _isInitialized = false;
  String? _walletId;
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _bankCards = [];

  // Getters
  bool get isInitialized => _isInitialized;
  String? get walletId => _walletId;
  double get balance => _balance;
  List<Map<String, dynamic>> get transactions => _transactions;
  List<Map<String, dynamic>> get bankCards => _bankCards;

  // 初始化钱包
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        debugPrint('[WalletService] 用户未登录，无法初始化钱包');
        return false;
      }

      debugPrint('[WalletService] 开始初始化钱包，用户ID: ${userInfo.id}');

      // 获取钱包信息
      try {
        final response = await Api.getWalletInfo();
        debugPrint('[WalletService] 钱包信息响应: $response');

        if (response['success'] == true && response['data'] != null) {
          _walletId = response['data']['wallet_id']?.toString();
          _balance = double.tryParse(response['data']['balance']?.toString() ?? '0') ?? 0.0;
          _isInitialized = true;

          debugPrint('[WalletService] 钱包初始化成功: ID=$_walletId, 余额=$_balance');

          // 加载交易记录和银行卡
          try {
            await loadTransactions();
            await loadBankCards();
          } catch (e) {
            debugPrint('[WalletService] 加载交易记录或银行卡失败: $e');
            // 不影响钱包初始化结果
          }

          return true;
        } else {
          debugPrint('[WalletService] 钱包不存在或获取失败');
          return false;
        }
      } catch (e) {
        debugPrint('[WalletService] 获取钱包信息异常: $e');
        throw Exception('获取钱包信息失败: $e');
      }
    } catch (e) {
      debugPrint('[WalletService] 初始化钱包异常: $e');
      return false;
    }
  }

  // 加载交易记录
  Future<void> loadTransactions() async {
    try {
      final response = await Api.get('/wallet/transactions');
      if (response['success'] == true) {
        // 检查数据结构，适应不同的API响应格式
        if (response['data'] is List) {
          _transactions = List<Map<String, dynamic>>.from(response['data'] ?? []);
        } else if (response['data'] is Map && response['data']['transactions'] is List) {
          // 处理分页格式的响应
          _transactions = List<Map<String, dynamic>>.from(response['data']['transactions'] ?? []);
        } else {
          // 如果没有数据或格式不匹配，使用空列表
          _transactions = [];
        }
        debugPrint('[WalletService] 成功加载 ${_transactions.length} 条交易记录');
      } else {
        debugPrint('[WalletService] 获取交易记录失败: ${response['msg']}');
        _transactions = [];
      }
    } catch (e) {
      debugPrint('[WalletService] 加载交易记录异常: $e');
      _transactions = [];
      throw Exception('获取交易记录失败: $e');
    }
  }

  // 加载银行卡
  Future<void> loadBankCards() async {
    try {
      final response = await Api.get('/wallet/bank-card');
      debugPrint('[WalletService] 银行卡列表API响应: $response');

      if (response['success'] == true && response['data'] != null) {
        _bankCards = List<Map<String, dynamic>>.from(response['data'] ?? []);
        debugPrint('[WalletService] 成功加载 ${_bankCards.length} 张银行卡');
        notifyListeners();
      } else {
        debugPrint('[WalletService] 获取银行卡失败: ${response['msg']}');
        _bankCards = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[WalletService] 加载银行卡异常: $e');
      _bankCards = [];
      notifyListeners();
      throw Exception('获取银行卡失败: $e');
    }
  }

  // 添加银行卡
  Future<Map<String, dynamic>> addBankCard(Map<String, dynamic> cardData) async {
    try {
      final response = await Api.post('/wallet/bank-card', data: cardData);
      debugPrint('[WalletService] 添加银行卡API响应: $response');

      if (response['success'] == true) {
        await loadBankCards(); // 重新加载银行卡列表
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 添加银行卡异常: $e');
      throw Exception('添加银行卡失败: $e');
    }
  }

  // 删除银行卡
  Future<Map<String, dynamic>> deleteBankCard(int cardId) async {
    try {
      final response = await Api.delete('/wallet/bank-card/$cardId');
      debugPrint('[WalletService] 删除银行卡API响应: $response');

      if (response['success'] == true) {
        await loadBankCards(); // 重新加载银行卡列表
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 删除银行卡异常: $e');
      throw Exception('删除银行卡失败: $e');
    }
  }

  // 设置默认银行卡
  Future<Map<String, dynamic>> setDefaultBankCard(int cardId) async {
    try {
      final response = await Api.put('/wallet/bank-card/$cardId/default');
      debugPrint('[WalletService] 设置默认银行卡API响应: $response');

      if (response['success'] == true) {
        await loadBankCards(); // 重新加载银行卡列表
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 设置默认银行卡异常: $e');
      throw Exception('设置默认银行卡失败: $e');
    }
  }

  // 转账
  Future<Map<String, dynamic>> transfer({
    required int receiverId,
    required double amount,
    String? message,
  }) async {
    try {
      final response = await Api.post('/wallet/transfer', data: {
        'sender_id': int.parse(_walletId ?? '0'),
        'receiver_id': receiverId,
        'amount': amount,
        'message': message ?? '',
      });

      if (response['success'] == true) {
        // 更新余额和交易记录
        if (response['data'] != null && response['data']['new_balance'] != null) {
          _balance = double.tryParse(response['data']['new_balance'].toString()) ?? _balance;
        } else {
          // 如果API没有返回新余额，重新获取钱包信息
          await initialize();
        }
        await loadTransactions();
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 转账异常: $e');
      throw Exception('转账失败: $e');
    }
  }

  // 发红包
  Future<Map<String, dynamic>> sendRedPacket({
    required int receiverId,
    required double amount,
    String? greeting,
  }) async {
    try {
      final response = await Api.post('/wallet/red-packet', data: {
        'receiver_id': receiverId,
        'amount': amount,
        'greeting': greeting ?? '恭喜发财，大吉大利！',
      });

      if (response['success'] == true) {
        // 更新余额和交易记录
        if (response['data'] != null && response['data']['new_balance'] != null) {
          _balance = double.tryParse(response['data']['new_balance'].toString()) ?? _balance;
        } else {
          // 如果API没有返回新余额，重新获取钱包信息
          await initialize();
        }
        await loadTransactions();
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 发红包异常: $e');
      throw Exception('发红包失败: $e');
    }
  }

  // 领取红包
  Future<Map<String, dynamic>> receiveRedPacket(int packetId) async {
    try {
      final response = await Api.post('/wallet/red-packet/$packetId/receive');

      if (response['success'] == true) {
        // 更新余额和交易记录
        if (response['data'] != null && response['data']['new_balance'] != null) {
          _balance = double.tryParse(response['data']['new_balance'].toString()) ?? _balance;
        } else if (response['data'] != null && response['data']['amount'] != null) {
          // 如果API只返回了红包金额，重新获取钱包信息
          await initialize();
        }
        await loadTransactions();
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 领取红包异常: $e');
      throw Exception('领取红包失败: $e');
    }
  }

  // 充值
  Future<Map<String, dynamic>> recharge({
    required int bankCardId,
    required double amount,
  }) async {
    try {
      final response = await Api.post('/wallet/recharge', data: {
        'bank_card_id': bankCardId,
        'amount': amount,
      });

      if (response['success'] == true) {
        // 更新余额和交易记录
        if (response['data'] != null && response['data']['new_balance'] != null) {
          _balance = double.tryParse(response['data']['new_balance'].toString()) ?? _balance;
        } else {
          // 如果API没有返回新余额，重新获取钱包信息
          await initialize();
        }
        await loadTransactions();
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 充值异常: $e');
      throw Exception('充值失败: $e');
    }
  }

  // 提现
  Future<Map<String, dynamic>> withdraw({
    required int bankCardId,
    required double amount,
  }) async {
    try {
      final response = await Api.post('/wallet/withdraw', data: {
        'bank_card_id': bankCardId,
        'amount': amount,
      });

      if (response['success'] == true) {
        // 更新余额和交易记录
        if (response['data'] != null && response['data']['new_balance'] != null) {
          _balance = double.tryParse(response['data']['new_balance'].toString()) ?? _balance;
        } else {
          // 如果API没有返回新余额，重新获取钱包信息
          await initialize();
        }
        await loadTransactions();
      }
      return response;
    } catch (e) {
      debugPrint('[WalletService] 提现异常: $e');
      throw Exception('提现失败: $e');
    }
  }

  // 获取交易详情
  Future<Map<String, dynamic>> getTransactionDetail(int transactionId) async {
    try {
      final response = await Api.get('/wallet/transaction/$transactionId');
      return response;
    } catch (e) {
      debugPrint('[WalletService] 获取交易详情异常: $e');
      return {'success': false, 'msg': '获取交易详情失败: $e'};
    }
  }

  // 刷新钱包信息
  Future<bool> refreshWalletInfo() async {
    try {
      try {
        final response = await Api.get('/wallet/info');
        if (response['success'] == true && response['data'] != null) {
          if (response['data']['wallet_id'] != null) {
            _walletId = response['data']['wallet_id'].toString();
          }
          if (response['data']['balance'] != null) {
            _balance = double.tryParse(response['data']['balance'].toString()) ?? _balance;
          }

          // 刷新交易记录和银行卡
          await Future.wait([
            loadTransactions(),
            loadBankCards(),
          ]);

          return true;
        } else {
          debugPrint('[WalletService] 刷新钱包信息失败: ${response['msg']}');
          // 尝试使用备用API
          return await _refreshWalletInfoFallback();
        }
      } catch (apiError) {
        debugPrint('[WalletService] API刷新钱包信息失败: $apiError');
        // 尝试使用备用API
        return await _refreshWalletInfoFallback();
      }
    } catch (e) {
      debugPrint('[WalletService] 刷新钱包信息异常: $e');
      return false;
    }
  }

  // 备用刷新钱包信息方法
  Future<bool> _refreshWalletInfoFallback() async {
    try {
      // 尝试获取用户信息
      final userInfo = await Persistence.getUserInfoAsync();
      if (userInfo == null) {
        debugPrint('[WalletService] 用户未登录，无法刷新钱包');
        return false;
      }

      // 使用用户ID作为钱包ID
      _walletId = userInfo.id.toString();

      // 刷新交易记录和银行卡
      await Future.wait([
        loadTransactions(),
        loadBankCards(),
      ]);

      return true;
    } catch (e) {
      debugPrint('[WalletService] 备用刷新钱包信息异常: $e');
      return false;
    }
  }

  // 清除钱包数据（用于退出登录）
  void clear() {
    _isInitialized = false;
    _walletId = null;
    _balance = 0.0;
    _transactions = [];
    _bankCards = [];
  }
}
