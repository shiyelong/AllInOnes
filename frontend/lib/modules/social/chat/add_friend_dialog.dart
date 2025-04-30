import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddFriendDialog extends StatefulWidget {
  final void Function(String friendId)? onAdd;
  const AddFriendDialog({Key? key, this.onAdd}) : super(key: key);

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  void _submit() async {
    final friendId = _controller.text.trim();
    if (friendId.isEmpty) {
      setState(() => _error = '请输入好友账号/ID');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('account') ?? '';
      if (userId.isEmpty) {
        setState(() { _error = '未获取到当前账号，请重新登录'; _loading = false; });
        return;
      }
      final resp = await http.post(
        Uri.parse('http://localhost:3001/friend/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'friend_id': friendId}),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        if (mounted) Navigator.of(context).pop();
        widget.onAdd?.call(friendId);
        final msg = data['msg'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      } else {
        setState(() { _error = data['msg'] ?? '添加失败'; });
      }
    } catch (e) {
      setState(() { _error = '网络异常或服务器错误'; });
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('添加好友'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: '好友账号/ID',
              errorText: _error,
            ),
            enabled: !_loading,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('添加'),
        ),
      ],
    );
  }
}
