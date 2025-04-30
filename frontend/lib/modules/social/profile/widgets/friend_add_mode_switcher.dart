import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 加好友方式切换组件，极致细分
class FriendAddModeSwitcher extends StatefulWidget {
  const FriendAddModeSwitcher({super.key});
  @override
  State<FriendAddModeSwitcher> createState() => _FriendAddModeSwitcherState();
}

class _FriendAddModeSwitcherState extends State<FriendAddModeSwitcher> {
  int? _mode; // 0=自动同意, 1=需验证
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchMode();
  }

  Future<void> _fetchMode() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:3001/user/friend_add_mode?user_id=$userId'));
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        setState(() => _mode = data['mode']);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _setMode(int value) async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await http.post(
        Uri.parse('http://localhost:3001/user/friend_add_mode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'mode': value}),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        setState(() => _mode = value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加好友方式已更新'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _mode == null) {
      return SizedBox(height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Row(
      children: [
        Expanded(
          child: RadioListTile<int>(
            value: 0,
            groupValue: _mode,
            onChanged: (v) => _setMode(v!),
            title: Text('自动同意'),
          ),
        ),
        Expanded(
          child: RadioListTile<int>(
            value: 1,
            groupValue: _mode,
            onChanged: (v) => _setMode(v!),
            title: Text('需验证'),
          ),
        ),
      ],
    );
  }
}
