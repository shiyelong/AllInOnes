import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
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
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  String _callStatus = '准备就绪';
  Timer? _callTimer;
  int _callDuration = 0;
  String _callType = 'video'; // 'video' or 'audio'
  String _platform = '';

  final TextEditingController _serverController = TextEditingController(text: 'http://localhost:3001');
  final TextEditingController _userIdController = TextEditingController(text: '1');
  final TextEditingController _targetIdController = TextEditingController(text: '2');

  @override
  void initState() {
    super.initState();
    _detectPlatform();
    _initRenderers();
  }

  void _detectPlatform() {
    if (kIsWeb) {
      _platform = 'web';
    } else if (Platform.isAndroid) {
      _platform = 'android';
    } else if (Platform.isIOS) {
      _platform = 'ios';
    } else if (Platform.isMacOS) {
      _platform = 'macos';
    } else if (Platform.isWindows) {
      _platform = 'windows';
    } else if (Platform.isLinux) {
      _platform = 'linux';
    } else {
      _platform = 'unknown';
    }

    // 根据平台设置默认服务器地址
    if (_platform == 'ios') {
      // 在iOS上，localhost不起作用，需要使用计算机的IP地址
      // 这里我们使用一个通用的方法来尝试连接
      // 用户可以在UI中手动修改服务器地址
      _serverController.text = 'http://YOUR_COMPUTER_IP:3001'; // 用户需要手动替换为计算机的实际IP地址

      // 显示提示
      Future.delayed(Duration.zero, () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('在iOS设备上，请将服务器地址修改为您计算机的IP地址'),
              duration: Duration(seconds: 10),
              action: SnackBarAction(
                label: '知道了',
                onPressed: () {},
              ),
            ),
          );
        }
      });
    }

    print('当前平台: $_platform');
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.close();
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

      // 获取媒体流
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': _callType == 'video'
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }
            : false,
      };

      print('请求媒体设备权限...');
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;

      // 创建PeerConnection
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
          {'urls': 'stun:stun4.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 10,
      };

      _peerConnection = await createPeerConnection(configuration);

      // 添加本地媒体流
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 监听远程媒体流
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          setState(() {
            _isConnected = true;
            _callStatus = '通话中';
          });
          _startCallTimer();
        }
      };

      // 监听ICE候选者
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        // 在实际应用中，这里应该将候选者发送给对方
        print('ICE candidate: ${candidate.toMap()}');
      };

      // 监听连接状态
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setState(() {
            _isConnected = true;
            _callStatus = '通话中';
          });
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          setState(() {
            _isConnected = false;
            _callStatus = '通话结束';
          });
          _callTimer?.cancel();
        }
      };

      // 创建Offer
      final RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // 在实际应用中，这里应该将offer发送给对方
      print('Created offer: ${offer.toMap()}');

      setState(() {
        _callStatus = '正在呼叫...';
      });

      // 模拟接收Answer（在实际应用中，这部分应该由对方发送）
      // 这里仅用于测试，实际应用中不需要这部分代码
      _simulateReceiveAnswer();

    } catch (e) {
      print('Error starting call: $e');
      setState(() {
        _callStatus = '呼叫失败: $e';
      });
    }
  }

  // 模拟接收Answer（仅用于测试）
  Future<void> _simulateReceiveAnswer() async {
    try {
      // 创建一个新的RTCPeerConnection来模拟对方
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
          {'urls': 'stun:stun4.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 10,
      };

      final remotePeerConnection = await createPeerConnection(configuration);

      // 获取对方的媒体流
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': _callType == 'video'
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      final remoteStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      // 添加对方的媒体流
      remoteStream.getTracks().forEach((track) {
        remotePeerConnection.addTrack(track, remoteStream);
      });

      // 设置本地的Offer作为对方的RemoteDescription
      final offerMap = await _peerConnection!.getLocalDescription();
      await remotePeerConnection.setRemoteDescription(
        RTCSessionDescription(offerMap!.sdp, offerMap.type),
      );

      // 创建Answer
      final RTCSessionDescription answer = await remotePeerConnection.createAnswer();
      await remotePeerConnection.setLocalDescription(answer);

      // 将对方的Answer设置为本地的RemoteDescription
      await _peerConnection!.setRemoteDescription(answer);

      print('Set remote description (answer): ${answer.toMap()}');
    } catch (e) {
      print('Error simulating answer: $e');
    }
  }

  Future<void> _endCall() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _peerConnection?.close();
    _peerConnection = null;
    _callTimer?.cancel();
    setState(() {
      _isConnected = false;
      _callStatus = '通话结束';
      _callDuration = 0;
    });
  }

  void _toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  void _toggleCamera() {
    if (_localStream != null && _callType == 'video') {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }
      setState(() {
        _isCameraOff = !_isCameraOff;
      });
    }
  }

  void _toggleSpeaker() {
    // 在实际应用中，这里应该切换扬声器/听筒
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
            _callStatus = '通话请求已发送，等待对方接受...';
          });

          // 在实际应用中，这里应该等待WebSocket通知对方接受通话
          // 然后开始WebRTC连接

          // 为了测试，我们直接初始化WebRTC
          _initializeWebRTC();
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

  Future<void> _initializeWebRTC() async {
    try {
      // 获取媒体流
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': _callType == 'video'
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;

      // 创建PeerConnection
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
          {'urls': 'stun:stun4.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 10,
      };

      _peerConnection = await createPeerConnection(configuration);

      // 添加本地媒体流
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 监听远程媒体流
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          setState(() {
            _isConnected = true;
            _callStatus = '通话中';
          });
          _startCallTimer();
        }
      };

      setState(() {
        _callStatus = 'WebRTC初始化完成，等待信令...';
      });
    } catch (e) {
      setState(() {
        _callStatus = 'WebRTC初始化失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('语音/视频聊天测试 ($_platform) - $_callStatus'),
        actions: [
          IconButton(
            icon: Icon(_callType == 'video' ? Icons.videocam : Icons.phone),
            onPressed: _switchCallType,
            tooltip: '切换为${_callType == 'video' ? '语音' : '视频'}通话',
          ),
        ],
      ),
      body: _isInitialized
          ? Column(
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
                              child: RTCVideoView(
                                _remoteRenderer,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                                      : RTCVideoView(
                                          _localRenderer,
                                          mirror: true,
                                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
