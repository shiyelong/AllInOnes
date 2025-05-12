import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../common/api.dart';
import '../../../common/persistence.dart';
import '../../../common/local_message_storage.dart';
import '../../../common/voice_recorder.dart';
import '../../../common/voice_player.dart';
import 'call/voice_call_page.dart';
import 'call/video_call_page.dart';
import 'call/simplified/simplified_call_manager.dart';

/// 语音通话处理器
/// 负责处理语音消息和语音/视频通话
class VoiceCallHandler {
  static final VoiceCallHandler _instance = VoiceCallHandler._internal();
  factory VoiceCallHandler() => _instance;

  VoiceCallHandler._internal();

  /// 发送语音消息
  Future<Map<String, dynamic>> sendVoiceMessage({
    required String userId,
    required String targetId,
    required String filePath,
    required int duration,
  }) async {
    try {
      // 生成唯一的消息ID
      final localMessageId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 创建本地消息对象
      final localMessage = {
        'id': localMessageId,
        'from_id': int.parse(userId),
        'to_id': int.parse(targetId),
        'content': filePath,
        'type': 'voice',
        'created_at': timestamp,
        'status': 0, // 发送中
        'duration': duration,
      };

      // 立即保存到本地存储，确保消息不会丢失
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      debugPrint('[VoiceCallHandler] 发送语音消息: $filePath, 时长: $duration 秒');
      final response = await Api.uploadVoiceMessage(
        filePath: filePath,
        duration: duration,
      );

      debugPrint('[VoiceCallHandler] 发送语音消息响应: $response');

      if (response['success'] == true) {
        // 获取服务器返回的消息ID和语音URL
        final serverId = response['data']?['id'];
        final serverUrl = response['data']?['url'];

        if (serverId != null) {
          // 更新本地消息对象
          localMessage['status'] = 1; // 已发送
          localMessage['id'] = serverId;
          if (serverUrl != null) {
            localMessage['server_url'] = serverUrl;
          }

          // 保存更新后的消息
          await _saveMessageToLocalStorage(userId, targetId, localMessage);

          return {
            'success': true,
            'message': localMessage,
            'error': '',
          };
        }
      }

      // 如果发送失败，更新消息状态为发送失败
      localMessage['status'] = 2; // 发送失败
      await _saveMessageToLocalStorage(userId, targetId, localMessage);

      return {
        'success': false,
        'message': localMessage,
        'error': response['msg'] ?? '发送语音消息失败',
      };
    } catch (e) {
      debugPrint('[VoiceCallHandler] 发送语音消息异常: $e');
      return {
        'success': false,
        'message': null,
        'error': '发送语音消息出错: $e',
      };
    }
  }

  /// 开始语音通话
  Future<Map<String, dynamic>> startVoiceCall({
    required BuildContext context,
    required String userId,
    required String targetId,
    required String targetName,
    String? targetAvatar,
  }) async {
    try {
      debugPrint('[VoiceCallHandler] 开始语音通话: targetId=$targetId, targetName=$targetName');

      // 调用API发起语音通话
      final response = await Api.initiateVoiceCall(
        targetId: targetId,
      );

      debugPrint('[VoiceCallHandler] 发起语音通话响应: $response');

      if (response['success'] == true) {
        final callId = response['data']?['call_id'];
        final signalingServer = response['data']?['signaling_server'];
        final turnServers = response['data']?['turn_servers'];

        if (callId != null) {
          // 打开语音通话页面
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VoiceCallPage(
                  callId: callId,
                  targetId: targetId,
                  targetName: targetName,
                  targetAvatar: targetAvatar,
                  isIncoming: false,
                  onCallEnded: () {},
                ),
              ),
            );
          }

          return {
            'success': true,
            'callId': callId,
            'error': '',
          };
        }
      }

      return {
        'success': false,
        'callId': null,
        'error': response['msg'] ?? '发起语音通话失败',
      };
    } catch (e) {
      debugPrint('[VoiceCallHandler] 发起语音通话异常: $e');
      return {
        'success': false,
        'callId': null,
        'error': '发起语音通话出错: $e',
      };
    }
  }

  /// 开始视频通话
  Future<Map<String, dynamic>> startVideoCall({
    required BuildContext context,
    required String userId,
    required String targetId,
    required String targetName,
    String? targetAvatar,
  }) async {
    try {
      debugPrint('[VoiceCallHandler] 开始视频通话: targetId=$targetId, targetName=$targetName');

      // 调用API发起视频通话
      final response = await Api.initiateVideoCall(
        targetId: targetId,
      );

      debugPrint('[VoiceCallHandler] 发起视频通话响应: $response');

      if (response['success'] == true) {
        final callId = response['data']?['call_id'];
        final signalingServer = response['data']?['signaling_server'];
        final turnServers = response['data']?['turn_servers'];

        if (callId != null) {
          // 打开视频通话页面
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoCallPage(
                  callId: callId,
                  targetId: targetId,
                  targetName: targetName,
                  targetAvatar: targetAvatar,
                  isIncoming: false,
                  onCallEnded: () {},
                ),
              ),
            );
          }

          return {
            'success': true,
            'callId': callId,
            'error': '',
          };
        }
      }

      return {
        'success': false,
        'callId': null,
        'error': response['msg'] ?? '发起视频通话失败',
      };
    } catch (e) {
      debugPrint('[VoiceCallHandler] 发起视频通话异常: $e');
      return {
        'success': false,
        'callId': null,
        'error': '发起视频通话出错: $e',
      };
    }
  }

  /// 接受通话
  Future<Map<String, dynamic>> acceptCall({
    required String callId,
    required String callType,
  }) async {
    try {
      debugPrint('[VoiceCallHandler] 接受通话: callId=$callId, callType=$callType');

      // 调用API接受通话
      final response = callType == 'voice'
          ? await Api.acceptVoiceCall(callId: callId)
          : await Api.acceptVideoCall(callId: callId);

      debugPrint('[VoiceCallHandler] 接受通话响应: $response');

      if (response['success'] == true) {
        return {
          'success': true,
          'error': '',
        };
      }

      return {
        'success': false,
        'error': response['msg'] ?? '接受通话失败',
      };
    } catch (e) {
      debugPrint('[VoiceCallHandler] 接受通话异常: $e');
      return {
        'success': false,
        'error': '接受通话出错: $e',
      };
    }
  }

  /// 拒绝通话
  Future<Map<String, dynamic>> rejectCall({
    required String callId,
    required String callType,
  }) async {
    try {
      debugPrint('[VoiceCallHandler] 拒绝通话: callId=$callId, callType=$callType');

      // 调用API拒绝通话
      final response = callType == 'voice'
          ? await Api.rejectVoiceCall(callId: callId)
          : await Api.rejectVideoCall(callId: callId);

      debugPrint('[VoiceCallHandler] 拒绝通话响应: $response');

      if (response['success'] == true) {
        return {
          'success': true,
          'error': '',
        };
      }

      return {
        'success': false,
        'error': response['msg'] ?? '拒绝通话失败',
      };
    } catch (e) {
      debugPrint('[VoiceCallHandler] 拒绝通话异常: $e');
      return {
        'success': false,
        'error': '拒绝通话出错: $e',
      };
    }
  }

  /// 结束通话
  Future<Map<String, dynamic>> endCall({
    required String callId,
    required String callType,
  }) async {
    try {
      debugPrint('[VoiceCallHandler] 结束通话: callId=$callId, callType=$callType');

      // 调用API结束通话
      final response = callType == 'voice'
          ? await Api.endVoiceCall(callId: callId)
          : await Api.endVideoCall(callId: callId);

      debugPrint('[VoiceCallHandler] 结束通话响应: $response');

      if (response['success'] == true) {
        return {
          'success': true,
          'error': '',
        };
      }

      return {
        'success': false,
        'error': response['msg'] ?? '结束通话失败',
      };
    } catch (e) {
      debugPrint('[VoiceCallHandler] 结束通话异常: $e');
      return {
        'success': false,
        'error': '结束通话出错: $e',
      };
    }
  }

  /// 保存消息到本地存储
  Future<void> _saveMessageToLocalStorage(
    String userId,
    String targetId,
    Map<String, dynamic> message,
  ) async {
    try {
      // 获取当前消息列表
      final messages = await Persistence.getChatMessages(userId, targetId);

      // 查找是否已存在相同ID的消息
      final index = messages.indexWhere((msg) => msg['id'] == message['id']);
      if (index != -1) {
        // 更新现有消息
        messages[index] = message;
      } else {
        // 添加新消息
        messages.add(message);
      }

      // 保存到Persistence
      await Persistence.saveChatMessages(userId, targetId, messages);

      // 同时保存到LocalMessageStorage
      try {
        await LocalMessageStorage.saveMessage(
          userId,
          targetId,
          message
        );
      } catch (e) {
        debugPrint('[VoiceCallHandler] 保存到LocalMessageStorage失败: $e');
      }
    } catch (e) {
      debugPrint('[VoiceCallHandler] 保存消息到本地存储失败: $e');
    }
  }
}
