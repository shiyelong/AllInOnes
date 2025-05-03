import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatApi {
  static const String baseUrl = 'http://localhost:3001'; // 已更新为正确的后端地址

  // 上传文件（图片/视频/语音）
  static Future<String?> uploadFile(dynamic file, {String fileType = 'image'}) async {
    // file: File 或 XFile
    var uri = Uri.parse('$baseUrl/chat/upload');
    var request = http.MultipartRequest('POST', uri);

    // 添加文件类型
    request.fields['type'] = fileType;

    if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else {
      return null;
    }

    print('[ChatApi] 上传文件: ${file.path}, 类型: $fileType');
    var resp = await request.send();
    if (resp.statusCode == 200) {
      final body = await resp.stream.bytesToString();
      print('[ChatApi] 上传文件响应: $body');
      final data = jsonDecode(body);
      if (data['success'] == true && data['data'] != null) {
        return data['data']['url'] as String?;
      }
    } else {
      print('[ChatApi] 上传文件失败: ${resp.statusCode}');
    }
    return null;
  }

  // 发送聊天消息（文本/图片/表情/视频/语音/红包）
  static Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String content,
    required String type,
    String extra = '',
  }) async {
    var url = Uri.parse('$baseUrl/chat/single');
    var resp = await http.post(url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'type': type,
        'extra': extra,
      }),
    );
    return resp.statusCode == 200;
  }

  // 发红包
  static Future<bool> sendHongbao({
    required int senderId,
    required int receiverId,
    required double amount,
    String remark = '',
  }) async {
    var url = Uri.parse('$baseUrl/hongbao/send');
    var resp = await http.post(url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'amount': amount,
        'remark': remark,
      }),
    );
    return resp.statusCode == 200;
  }

  // WebRTC 信令
  static Future<bool> sendWebRTCSignal({
    required int from,
    required int to,
    required String type,
    required String signal,
  }) async {
    var url = Uri.parse('$baseUrl/webrtc/signal');
    var resp = await http.post(url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': from,
        'to': to,
        'type': type,
        'signal': signal,
      }),
    );
    return resp.statusCode == 200;
  }
}
