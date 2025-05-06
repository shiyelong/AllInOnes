import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '语音/视频聊天测试',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CallTestPage(),
    );
  }
}

class CallTestPage extends StatefulWidget {
  const CallTestPage({Key? key}) : super(key: key);

  @override
  _CallTestPageState createState() => _CallTestPageState();
}

class _CallTestPageState extends State<CallTestPage> {
  String _callStatus = '准备就绪';
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  Timer? _callTimer;
  int _callDuration = 0;
  String _callType = 'video'; // 'video' or 'audio'
  
  final TextEditingController _serverController = TextEditingController(text: 'http://localhost:3001');
  final TextEditingController _userIdController = TextEditingController(text: '1');
  final TextEditingController _targetIdController = TextEditingController(text: '2');

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startCall() async {
    try {
      setState(() {
        _callStatus = '初始化中...';
      });

      // 模拟通话建立
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isConnected = true;
        _callStatus = '通话中';
      });
      
      _startCallTimer();
    } catch (e) {
      print('Error starting call: $e');
      setState(() {
        _callStatus = '呼叫失败: $e';
      });
    }
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    setState(() {
      _isConnected = false;
      _callStatus = '通话结束';
      _callDuration = 0;
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _switchCallType() {
    setState(() {
      _callType = _callType == 'video' ? 'audio' : 'video';
    });
  }

  // 实际调用后端API发起通话
  Future<void> _startRealCall() async {
    try {
      final serverUrl = _serverController.text;
      final userId = int.parse(_userIdController.text);
      final targetId = int.parse(_targetIdController.text);
      
      setState(() {
        _callStatus = '正在发起通话请求...';
      });
      
      // 发起通话请求
      final url = Uri.parse('$serverUrl/api/call/${_callType}/initiate');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'caller_id': userId,
          'receiver_id': targetId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _isConnected = true;
            _callStatus = '通话请求已发送，通话已建立';
          });
          _startCallTimer();
        } else {
          setState(() {
            _callStatus = '通话请求失败: ${data['msg']}';
          });
        }
      } else {
        setState(() {
          _callStatus = '通话请求失败: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _callStatus = '通话请求错误: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('语音/视频聊天测试 - $_callStatus'),
        actions: [
          IconButton(
            icon: Icon(_callType == 'video' ? Icons.videocam : Icons.phone),
            onPressed: _switchCallType,
            tooltip: '切换为${_callType == 'video' ? '语音' : '视频'}通话',
          ),
        ],
      ),
      body: Column(
        children: [
          // 服务器和用户ID设置
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: '用户ID',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _targetIdController,
                    decoration: const InputDecoration(
                      labelText: '目标ID',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          
          // 视频显示区域
          Expanded(
            child: _callType == 'video'
                ? Stack(
                    children: [
                      // 远程视频（全屏）
                      Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: Center(
                            child: _isConnected
                                ? const Text(
                                    '远程视频',
                                    style: TextStyle(color: Colors.white, fontSize: 24),
                                  )
                                : const Text(
                                    '未连接',
                                    style: TextStyle(color: Colors.white, fontSize: 24),
                                  ),
                          ),
                        ),
                      ),
                      // 本地视频（小窗口）
                      Positioned(
                        right: 16,
                        top: 16,
                        width: 120,
                        height: 160,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[800],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _isCameraOff
                                ? Container(
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Icon(
                                        Icons.videocam_off,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      '本地视频',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.phone,
                          size: 100,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isConnected ? '语音通话中' : _callStatus,
                          style: const TextStyle(fontSize: 24),
                        ),
                        if (_isConnected)
                          Text(
                            _formatDuration(_callDuration),
                            style: const TextStyle(fontSize: 18),
                          ),
                      ],
                    ),
                  ),
          ),
          
          // 通话状态和时间
          if (_isConnected)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '通话时长: ${_formatDuration(_callDuration)}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          
          // 控制按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 麦克风按钮
                ElevatedButton.icon(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  label: Text(_isMuted ? '取消静音' : '静音'),
                  onPressed: _isConnected ? _toggleMute : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMuted ? Colors.red : null,
                  ),
                ),
                
                // 摄像头按钮（仅视频通话）
                if (_callType == 'video')
                  ElevatedButton.icon(
                    icon: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam),
                    label: Text(_isCameraOff ? '开启摄像头' : '关闭摄像头'),
                    onPressed: _isConnected ? _toggleCamera : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCameraOff ? Colors.red : null,
                    ),
                  ),
                
                // 扬声器按钮
                ElevatedButton.icon(
                  icon: Icon(_isSpeakerOn ? Icons.volume_up : Icons.volume_down),
                  label: Text(_isSpeakerOn ? '关闭扬声器' : '扬声器'),
                  onPressed: _isConnected ? _toggleSpeaker : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSpeakerOn ? Colors.green : null,
                  ),
                ),
              ],
            ),
          ),
          
          // 开始/结束通话按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('测试本地通话'),
                  onPressed: !_isConnected ? _startCall : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('发起真实通话'),
                  onPressed: !_isConnected ? _startRealCall : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.call_end),
                  label: const Text('结束通话'),
                  onPressed: _isConnected ? _endCall : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
