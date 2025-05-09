import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme_manager.dart';
import '../../../../common/local_message_storage.dart';
import '../../../../common/persistence.dart';

/// 聊天列表项右键菜单
class ChatListItemMenu extends StatelessWidget {
  final Map<String, dynamic> chat;
  final Function? onDelete;
  final Function? onPin;
  final Function? onUnpin;
  final Function? onMute;
  final Function? onUnmute;
  final Function? onMarkAsRead;
  final Function? onViewProfile;
  final bool isPinned;
  final bool isMuted;
  
  const ChatListItemMenu({
    Key? key,
    required this.chat,
    this.onDelete,
    this.onPin,
    this.onUnpin,
    this.onMute,
    this.onUnmute,
    this.onMarkAsRead,
    this.onViewProfile,
    this.isPinned = false,
    this.isMuted = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    
    return PopupMenuButton<String>(
      tooltip: '更多选项',
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            if (onDelete != null) {
              onDelete!();
            } else {
              await _deleteChat(context);
            }
            break;
          case 'pin':
            if (onPin != null) onPin!();
            break;
          case 'unpin':
            if (onUnpin != null) onUnpin!();
            break;
          case 'mute':
            if (onMute != null) onMute!();
            break;
          case 'unmute':
            if (onUnmute != null) onUnmute!();
            break;
          case 'mark_as_read':
            if (onMarkAsRead != null) onMarkAsRead!();
            break;
          case 'view_profile':
            if (onViewProfile != null) onViewProfile!();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onViewProfile != null || chat['type'] != 'self')
          PopupMenuItem(
            value: 'view_profile',
            child: Row(
              children: [
                Icon(Icons.person, color: theme.primaryColor),
                SizedBox(width: 8),
                Text('查看资料'),
              ],
            ),
          ),
        if (isPinned)
          PopupMenuItem(
            value: 'unpin',
            child: Row(
              children: [
                Icon(Icons.push_pin_outlined, color: theme.primaryColor),
                SizedBox(width: 8),
                Text('取消置顶'),
              ],
            ),
          )
        else
          PopupMenuItem(
            value: 'pin',
            child: Row(
              children: [
                Icon(Icons.push_pin, color: theme.primaryColor),
                SizedBox(width: 8),
                Text('置顶聊天'),
              ],
            ),
          ),
        if (isMuted)
          PopupMenuItem(
            value: 'unmute',
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: theme.primaryColor),
                SizedBox(width: 8),
                Text('取消静音'),
              ],
            ),
          )
        else
          PopupMenuItem(
            value: 'mute',
            child: Row(
              children: [
                Icon(Icons.notifications_off, color: theme.primaryColor),
                SizedBox(width: 8),
                Text('静音通知'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'mark_as_read',
          child: Row(
            children: [
              Icon(Icons.mark_chat_read, color: theme.primaryColor),
              SizedBox(width: 8),
              Text('标记为已读'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('删除聊天记录', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      icon: Icon(Icons.more_vert, color: theme.iconColor),
    );
  }
  
  /// 删除聊天记录
  Future<void> _deleteChat(BuildContext context) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除聊天记录'),
        content: Text('确定要删除与"${chat['target_name']}"的聊天记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户信息不存在，请重新登录')),
        );
        return;
      }
      
      final userId = userInfo.id;
      final targetId = chat['target_id'];
      
      // 清除本地消息
      final success = await LocalMessageStorage.clearMessages(userId, targetId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('聊天记录已删除'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除聊天记录失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
