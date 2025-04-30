import 'package:http/http.dart' as http;
import 'dart:convert';

class FriendBlockService {
  static Future<bool> blockFriend({required String userId, required String friendId}) async {
    final resp = await http.post(
      Uri.parse('http://localhost:3001/friend/block'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'friend_id': friendId}),
    );
    final data = jsonDecode(resp.body);
    return data['success'] == true;
  }

  static Future<bool> unblockFriend({required String userId, required String friendId}) async {
    final resp = await http.post(
      Uri.parse('http://localhost:3001/friend/unblock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'friend_id': friendId}),
    );
    final data = jsonDecode(resp.body);
    return data['success'] == true;
  }
}
