import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../common/theme_manager.dart';
import '../../../common/message_formatter.dart';
import '../../../common/persistence.dart';
import '../../../common/voice_player.dart';
import 'voice_message_widget.dart';

/// 聊天消息项
/// 用于显示聊天消息
class ChatMessageItem extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final Function(Map<String, dynamic>)? onLongPress;
  final Function(Map<String, dynamic>)? onTap;
  final bool showAvatar;
  final bool showName;
  final bool showTime;
  final bool isGroup;
  final bool isSelected;

  const ChatMessageItem({
    Key? key,
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.onTap,
    this.showAvatar = true,
    this.showName = false,
    this.showTime = true,
    this.isGroup = false,
    this.isSelected = false,
  }) : super(key: key);

  @override
  _ChatMessageItemState createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<ChatMessageItem> {
  bool _isHovering = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _voiceProgress = 0.0;

  @override
  void initState() {
    super.initState();
    
    // 如果是语音消息，监听播放状态
    if (_isVoiceMessage()) {
      VoicePlayer().addListener(_onVoicePlayStateChanged);
    }
  }

  @override
  void dispose() {
    // 如果是语音消息，移除监听
    if (_isVoiceMessage()) {
      VoicePlayer().removeListener(_onVoicePlayStateChanged);
    }
    super.dispose();
  }

  // 语音播放状态变化回调
  void _onVoicePlayStateChanged(String messageId, bool isPlaying, bool isPaused, double progress, int position) {
    if (messageId == widget.message['id']) {
      setState(() {
        _isPlaying = isPlaying;
        _isPaused = isPaused;
        _voiceProgress = progress;
      });
    }
  }

  // 是否是文本消息
  bool _isTextMessage() {
    return widget.message['type'] == 'text';
  }

  // 是否是图片消息
  bool _isImageMessage() {
    return widget.message['type'] == 'image';
  }

  // 是否是视频消息
  bool _isVideoMessage() {
    return widget.message['type'] == 'video';
  }

  // 是否是文件消息
  bool _isFileMessage() {
    return widget.message['type'] == 'file';
  }

  // 是否是语音消息
  bool _isVoiceMessage() {
    return widget.message['type'] == 'voice';
  }

  // 是否是位置消息
  bool _isLocationMessage() {
    return widget.message['type'] == 'location';
  }

  // 是否是红包消息
  bool _isRedPacketMessage() {
    return widget.message['type'] == 'red_packet';
  }

  // 是否是系统消息
  bool _isSystemMessage() {
    return widget.message['type'] == 'system';
  }

  // 是否是撤回消息
  bool _isRecalledMessage() {
    return widget.message['is_recalled'] == true;
  }

  // 获取消息时间
  String _getMessageTime() {
    final timestamp = widget.message['timestamp'] ?? 0;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    
    // 今天的消息只显示时间
    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      return DateFormat('HH:mm').format(dateTime);
    }
    
    // 昨天的消息显示"昨天 时间"
    final yesterday = now.subtract(Duration(days: 1));
    if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    }
    
    // 一周内的消息显示"星期几 时间"
    if (now.difference(dateTime).inDays < 7) {
      final weekday = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'][dateTime.weekday % 7];
      return '$weekday ${DateFormat('HH:mm').format(dateTime)}';
    }
    
    // 其他消息显示完整日期时间
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  // 获取发送者名称
  String _getSenderName() {
    if (widget.isMe) {
      final userInfo = Persistence.getUserInfo();
      return userInfo?['nickname'] ?? '我';
    }
    
    return widget.message['sender_name'] ?? '未知用户';
  }

  // 获取发送者头像
  String? _getSenderAvatar() {
    if (widget.isMe) {
      final userInfo = Persistence.getUserInfo();
      return userInfo?['avatar'];
    }
    
    return widget.message['sender_avatar'];
  }

  // 复制消息内容
  void _copyMessageContent() {
    if (_isTextMessage()) {
      final content = widget.message['content'];
      Clipboard.setData(ClipboardData(text: content));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制消息内容')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    
    // 系统消息居中显示
    if (_isSystemMessage()) {
      return _buildSystemMessage();
    }
    
    // 撤回消息特殊显示
    if (_isRecalledMessage()) {
      return _buildRecalledMessage();
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap != null ? () => widget.onTap!(widget.message) : null,
        onLongPress: widget.onLongPress != null ? () => widget.onLongPress!(widget.message) : null,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧头像（非自己的消息）
              if (!widget.isMe && widget.showAvatar) _buildAvatar(),
              
              // 消息内容
              Column(
                crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 发送者名称（群聊中显示）
                  if (widget.showName && !widget.isMe && widget.isGroup)
                    Padding(
                      padding: EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        _getSenderName(),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  
                  // 消息气泡
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 消息状态（自己的消息）
                      if (widget.isMe && _isHovering)
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: _buildMessageStatus(),
                        ),
                      
                      // 消息气泡
                      _buildMessageBubble(),
                      
                      // 消息状态（自己的消息）
                      if (widget.isMe && !_isHovering)
                        Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: _buildMessageStatus(),
                        ),
                    ],
                  ),
                  
                  // 消息时间
                  if (widget.showTime)
                    Padding(
                      padding: EdgeInsets.only(top: 4, left: widget.isMe ? 0 : 12, right: widget.isMe ? 12 : 0),
                      child: Text(
                        _getMessageTime(),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
              
              // 右侧头像（自己的消息）
              if (widget.isMe && widget.showAvatar) _buildAvatar(),
            ],
          ),
        ),
      ),
    );
  }

  // 构建头像
  Widget _buildAvatar() {
    final avatar = _getSenderAvatar();
    
    return Container(
      margin: EdgeInsets.only(
        left: widget.isMe ? 12 : 0,
        right: widget.isMe ? 0 : 12,
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[300],
        backgroundImage: avatar != null && avatar.isNotEmpty
            ? NetworkImage(avatar)
            : null,
        child: avatar == null || avatar.isEmpty
            ? Icon(Icons.person, color: Colors.white)
            : null,
      ),
    );
  }

  // 构建消息气泡
  Widget _buildMessageBubble() {
    final theme = ThemeManager.currentTheme;
    
    // 根据消息类型构建不同的气泡内容
    Widget content;
    if (_isTextMessage()) {
      content = _buildTextMessage();
    } else if (_isImageMessage()) {
      content = _buildImageMessage();
    } else if (_isVideoMessage()) {
      content = _buildVideoMessage();
    } else if (_isFileMessage()) {
      content = _buildFileMessage();
    } else if (_isVoiceMessage()) {
      content = _buildVoiceMessage();
    } else if (_isLocationMessage()) {
      content = _buildLocationMessage();
    } else if (_isRedPacketMessage()) {
      content = _buildRedPacketMessage();
    } else {
      content = Text('未知消息类型');
    }
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: widget.isMe
            ? theme.primaryColor
            : theme.isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: content,
    );
  }

  // 构建文本消息
  Widget _buildTextMessage() {
    final theme = ThemeManager.currentTheme;
    final content = widget.message['content'] ?? '';
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        content,
        style: TextStyle(
          color: widget.isMe ? Colors.white : (theme.isDark ? Colors.white : Colors.black87),
          fontSize: 16,
        ),
      ),
    );
  }

  // 构建图片消息
  Widget _buildImageMessage() {
    final imageUrl = widget.message['content'] ?? '';
    final thumbnailUrl = widget.message['thumbnail'] ?? imageUrl;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        thumbnailUrl,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: Center(
              child: Icon(Icons.broken_image, color: Colors.grey[600]),
            ),
          );
        },
      ),
    );
  }

  // 构建视频消息
  Widget _buildVideoMessage() {
    final thumbnailUrl = widget.message['thumbnail'] ?? '';
    
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            thumbnailUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(Icons.broken_image, color: Colors.grey[600]),
                ),
              );
            },
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
        ),
      ],
    );
  }

  // 构建文件消息
  Widget _buildFileMessage() {
    final theme = ThemeManager.currentTheme;
    final fileName = widget.message['file_name'] ?? '未知文件';
    final fileSize = widget.message['file_size'] ?? 0;
    
    // 格式化文件大小
    String formattedSize;
    if (fileSize < 1024) {
      formattedSize = '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      formattedSize = '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      formattedSize = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      formattedSize = '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    
    return Container(
      padding: EdgeInsets.all(12),
      width: 240,
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            color: widget.isMe ? Colors.white70 : theme.primaryColor,
            size: 40,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : (theme.isDark ? Colors.white : Colors.black87),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  formattedSize,
                  style: TextStyle(
                    color: widget.isMe ? Colors.white70 : (theme.isDark ? Colors.grey[400] : Colors.grey[600]),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建语音消息
  Widget _buildVoiceMessage() {
    final duration = widget.message['duration'] ?? 0;
    final filePath = widget.message['local_path'] ?? '';
    final messageId = widget.message['id'] ?? '';
    final serverUrl = widget.message['content']; // 服务器URL
    
    return VoiceMessageWidget(
      messageId: messageId,
      filePath: filePath,
      duration: duration,
      isMe: widget.isMe,
      serverUrl: serverUrl,
    );
  }

  // 构建位置消息
  Widget _buildLocationMessage() {
    final theme = ThemeManager.currentTheme;
    final address = widget.message['address'] ?? '未知位置';
    final thumbnailUrl = widget.message['thumbnail'] ?? '';
    
    return Container(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.network(
              thumbnailUrl,
              width: 240,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 240,
                  height: 120,
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(Icons.location_on, color: Colors.grey[600], size: 40),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? theme.primaryColor.withOpacity(0.8)
                  : (theme.isDark ? Colors.grey[700] : Colors.grey[100]),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: widget.isMe ? Colors.white70 : theme.primaryColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isMe ? Colors.white : (theme.isDark ? Colors.white : Colors.black87),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建红包消息
  Widget _buildRedPacketMessage() {
    final theme = ThemeManager.currentTheme;
    final message = widget.message['message'] ?? '恭喜发财，大吉大利';
    final isOpened = widget.message['is_opened'] == true;
    
    return Container(
      width: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.red[700]!,
            Colors.red[600]!,
          ],
        ),
      ),
      child: Column(
        children: [
          Icon(
            isOpened ? Icons.card_giftcard : Icons.redeem,
            color: Colors.yellow[100],
            size: 40,
          ),
          SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red[800],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isOpened ? '已领取' : '点击领取红包',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建系统消息
  Widget _buildSystemMessage() {
    final content = widget.message['content'] ?? '';
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        content,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }

  // 构建撤回消息
  Widget _buildRecalledMessage() {
    final isMe = widget.message['sender_id'] == Persistence.getUserId();
    final content = isMe ? '你撤回了一条消息' : '对方撤回了一条消息';
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        content,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // 构建消息状态
  Widget _buildMessageStatus() {
    final status = widget.message['status'] ?? 'sent';
    final isRead = widget.message['is_read'] == true;
    
    if (status == 'sending') {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      );
    } else if (status == 'failed') {
      return Icon(
        Icons.error_outline,
        color: Colors.red,
        size: 16,
      );
    } else {
      return Icon(
        isRead ? Icons.done_all : Icons.done,
        color: isRead ? Colors.blue : Colors.grey,
        size: 16,
      );
    }
  }
}
