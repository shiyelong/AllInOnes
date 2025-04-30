import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'friend_request_card.dart';

/// 好友申请页面，极致细分
class FriendRequestPage extends StatefulWidget {
  const FriendRequestPage({super.key});
  @override
  State<FriendRequestPage> createState() => _FriendRequestPageState();
}

class _FriendRequestPageState extends State<FriendRequestPage> {
  List _requests = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('account') ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:3001/friend/requests?user_id=$userId'));
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        setState(() => _requests = data['data']);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _agree(int requestId) async {
    setState(() => _loading = true);
    try {
      final resp = await http.post(
        Uri.parse('http://localhost:3001/friend/agree'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'request_id': requestId}),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已同意好友请求'), backgroundColor: Colors.green),
        );
        _fetchRequests();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友申请'),
        centerTitle: true,
        actions: [
          if (_requests.isNotEmpty)
            TextButton(
              onPressed: _loading ? null : _agreeAll,
              child: const Text('全部同意', style: TextStyle(color: Colors.white)),
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRequests,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('暂无好友申请', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _requests.length,
                    itemBuilder: (context, i) {
                      final req = _requests[i];
                      final ts = req['created_at'] ?? 0;
                      return FriendRequestCard(
                        fromUser: '用户ID: ${req['from_id']}',
                        time: '申请时间: ${DateTime.fromMillisecondsSinceEpoch(ts * 1000)}',
                        agreed: false,
                        onAgree: () => _agree(req['id']),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _agreeAll() async {
    for (final req in _requests) {
      await _agree(req['id']);
    }
  }
}
