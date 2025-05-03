import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RecentAccount {
  final String account;
  final String generatedEmail;
  final DateTime registeredAt;

  RecentAccount({
    required this.account,
    required this.generatedEmail,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'account': account,
      'generatedEmail': generatedEmail,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }

  factory RecentAccount.fromJson(Map<String, dynamic> json) {
    return RecentAccount(
      account: json['account'],
      generatedEmail: json['generatedEmail'],
      registeredAt: DateTime.parse(json['registeredAt']),
    );
  }
}

class RecentAccountsManager {
  static const String _key = 'recent_accounts';
  static const int _maxAccounts = 5; // 最多保存5个最近账号

  // 保存新注册的账号
  static Future<void> saveAccount(String account, String generatedEmail) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    
    // 检查是否已存在相同账号
    final existingIndex = accounts.indexWhere((a) => a.account == account);
    if (existingIndex != -1) {
      accounts.removeAt(existingIndex);
    }
    
    // 添加新账号到列表开头
    accounts.insert(0, RecentAccount(
      account: account,
      generatedEmail: generatedEmail,
      registeredAt: DateTime.now(),
    ));
    
    // 如果超过最大数量，删除最旧的
    if (accounts.length > _maxAccounts) {
      accounts.removeLast();
    }
    
    // 保存到SharedPreferences
    final jsonList = accounts.map((account) => jsonEncode(account.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  // 获取所有保存的账号
  static Future<List<RecentAccount>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    
    return jsonList.map((jsonStr) {
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      return RecentAccount.fromJson(json);
    }).toList();
  }

  // 清除所有保存的账号
  static Future<void> clearAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
