import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddFriendPage extends StatefulWidget {
  final int userId;
  const AddFriendPage({Key? key, required this.userId}) : super(key: key);
  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _formKey = GlobalKey<FormState>();
  String friendId = '';
  String result = '';

  Future<void> addFriend() async {
    final resp = await http.post(
      Uri.parse('http://localhost:3001/friend/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': widget.userId, 'friend_id': int.tryParse(friendId)}),
    );
    final data = jsonDecode(resp.body);
    setState(() {
      result = data['msg'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('添加好友')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: '好友ID'),
                onChanged: (v) => friendId = v,
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? '请输入好友ID' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) addFriend();
                },
                child: Text('添加'),
              ),
              if (result.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(result, style: TextStyle(color: Colors.green)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
