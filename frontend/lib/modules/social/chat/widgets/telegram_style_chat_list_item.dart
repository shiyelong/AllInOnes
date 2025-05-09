import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme_manager.dart';
import '../../../../common/text_sanitizer.dart';
import '../../../../common/message_formatter.dart';
import 'chat_list_item_menu.dart';

/// Telegram风格的聊天列表项
class TelegramStyleChatListItem extends StatefulWidget {
  final Map<String, dynamic> chat;
  final bool isSelected;
  final Function() onTap;
  final Function()? onLongPress;
  final Function()? onDelete;
  
  const TelegramStyleChatListItem({
    Key? key,
    required this.chat,
    required this.onTap,
    this.isSelected = false,
    this.onLongPress,
    this.onDelete,
  }) : super(key: key);
  
  @override
  State<TelegramStyleChatListItem> createState() => _TelegramStyleChatListItemState();
}

class _TelegramStyleChatListItemState extends State<TelegramStyleChatListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    final isDark = theme.isDark;
    
    // 获取聊天信息
    final targetName = TextSanitizer.sanitize(widget.chat['target_name'] ?? '未知');
    final targetAvatar = widget.chat['target_avatar'] ?? '';
    final lastMessage = widget.chat['formatted_preview'] ?? 
                        widget.chat['last_message'] ?? '';
    final lastMessageType = widget.chat['last_message_type'] ?? 'text';
    final unreadCount = widget.chat['unread'] ?? 0;
    final lastTime = widget.chat['updated_at'] ?? 0;
    final isPinned = widget.chat['is_pinned'] ?? false;
    final isMuted = widget.chat['is_muted'] ?? false;
    
    // 格式化最后消息时间
    final lastTimeStr = _formatTime(lastTime);
    
    // 格式化最后消息内容
    String lastMessageText = '';
    if (widget.chat['formatted_preview'] != null) {
      lastMessageText = widget.chat['formatted_preview'];
    } else if (lastMessageType == 'text' || lastMessageType.isEmpty) {
      lastMessageText = TextSanitizer.sanitize(lastMessage);
      
      // 检查是否是纯表情消息
      if (MessageFormatter.isEmojiOnly(lastMessageText)) {
        // 如果是纯表情，直接显示
      } else if (lastMessageText.length > 30) {
        // 如果消息太长，截断显示
        lastMessageText = lastMessageText.substring(0, 30) + '...';
      }
    } else {
      // 根据消息类型格式化
      switch (lastMessageType) {
        case 'image':
          lastMessageText = '[图片]';
          break;
        case 'video':
          lastMessageText = '[视频]';
          break;
        case 'file':
          lastMessageText = '[文件]';
          break;
        case 'voice':
          lastMessageText = '[语音]';
          break;
        case 'location':
          lastMessageText = '[位置]';
          break;
        case 'transfer':
          lastMessageText = '[转账]';
          break;
        case 'red_packet':
          lastMessageText = '[红包]';
          break;
        default:
          lastMessageText = TextSanitizer.sanitize(lastMessage);
          if (lastMessageText.length > 30) {
            lastMessageText = lastMessageText.substring(0, 30) + '...';
          }
      }
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: widget.isSelected 
                ? (isDark ? Colors.blueGrey[800] : theme.primaryColor.withOpacity(0.1))
                : (_isHovered 
                  ? (isDark ? Colors.grey[850] : Colors.grey[200]) 
                  : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  // 头像
                  _buildAvatar(targetName, targetAvatar),
                  SizedBox(width: 12),
                  
                  // 聊天信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 名称和时间
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                targetName,
                                style: TextStyle(
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              lastTimeStr,
                              style: TextStyle(
                                color: unreadCount > 0 
                                  ? theme.primaryColor 
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        
                        // 最后消息和未读数
                        Row(
                          children: [
                            if (isPinned)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.push_pin,
                                  size: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            if (isMuted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.volume_off,
                                  size: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            Expanded(
                              child: Text(
                                lastMessageText,
                                style: TextStyle(
                                  color: unreadCount > 0 
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4),
                            if (unreadCount > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 右键菜单
                  ChatListItemMenu(
                    chat: widget.chat,
                    isPinned: isPinned,
                    isMuted: isMuted,
                    onDelete: widget.onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建头像
  Widget _buildAvatar(String name, String avatarUrl) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: ThemeManager.currentTheme.primaryColor.withOpacity(0.2),
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: ThemeManager.currentTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
  
  /// 格式化时间
  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    
    final now = DateTime.now();
    final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final difference = now.difference(messageTime);
    
    // 今天的消息显示时间
    if (difference.inHours < 24 && now.day == messageTime.day) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    }
    
    // 昨天的消息显示"昨天"
    if (difference.inHours < 48 && now.day - messageTime.day == 1) {
      return '昨天';
    }
    
    // 一周内的消息显示星期几
    if (difference.inDays < 7) {
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      // 注意：DateTime中，周一是1，周日是7，而我们的数组索引从0开始
      final weekdayIndex = messageTime.weekday - 1;
      return weekdays[weekdayIndex];
    }
    
    // 其他情况显示日期
    return '${messageTime.month}/${messageTime.day}';
  }
}
