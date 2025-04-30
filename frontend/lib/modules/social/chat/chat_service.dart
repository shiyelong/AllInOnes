import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  static Future<List> fetchRecentChats(int userId) async {
    final resp = await http.get(Uri.parse('http://localhost:3001/chat/recent?user_id=$userId'));
    final data = jsonDecode(resp.body);
    if (data['success'] == true) {
      return data['data'];
    }
    return [];
  }
}
