import 'package:flutter/material.dart';
import 'package:frontend/modules/social/call/simplified/simplified_call_manager.dart';

class CallTestPage extends StatefulWidget {
  const CallTestPage({Key? key}) : super(key: key);

  @override
  _CallTestPageState createState() => _CallTestPageState();
}

class _CallTestPageState extends State<CallTestPage> {
  final SimplifiedCallManager _callManager = SimplifiedCallManager();

  @override
  void initState() {
    super.initState();
    _callManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('通话测试'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _callManager.startVideoCall(
                  '123456',
                  '张三',
                  'https://randomuser.me/api/portraits/men/1.jpg',
                );
              },
              child: Text('发起视频通话'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _callManager.startVoiceCall(
                  '123456',
                  '张三',
                  'https://randomuser.me/api/portraits/men/1.jpg',
                );
              },
              child: Text('发起语音通话'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _callManager.simulateIncomingCall(
                  fromId: '123456',
                  fromName: '张三',
                  fromAvatar: 'https://randomuser.me/api/portraits/men/1.jpg',
                  callType: 'video',
                );
              },
              child: Text('模拟视频来电'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _callManager.simulateIncomingCall(
                  fromId: '123456',
                  fromName: '张三',
                  fromAvatar: 'https://randomuser.me/api/portraits/men/1.jpg',
                  callType: 'voice',
                );
              },
              child: Text('模拟语音来电'),
            ),
          ],
        ),
      ),
    );
  }
}
