import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 消息格式化工具类
/// 用于格式化消息内容、时间等
class MessageFormatter {
  /// 格式化消息时间
  /// 根据消息时间与当前时间的差距，返回不同格式的时间字符串
  static String formatMessageTime(int timestamp) {
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
    
    // 今年的消息显示"月-日 时间"
    if (dateTime.year == now.year) {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
    
    // 其他消息显示完整日期时间
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
  
  /// 格式化会话时间
  /// 用于在会话列表中显示最后一条消息的时间
  static String formatConversationTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    
    // 今天的消息只显示时间
    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      return DateFormat('HH:mm').format(dateTime);
    }
    
    // 昨天的消息显示"昨天"
    final yesterday = now.subtract(Duration(days: 1));
    if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
      return '昨天';
    }
    
    // 一周内的消息显示"星期几"
    if (now.difference(dateTime).inDays < 7) {
      final weekday = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'][dateTime.weekday % 7];
      return weekday;
    }
    
    // 今年的消息显示"月-日"
    if (dateTime.year == now.year) {
      return DateFormat('MM-dd').format(dateTime);
    }
    
    // 其他消息显示"年-月-日"
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }
  
  /// 格式化消息内容
  /// 用于在会话列表中显示最后一条消息的内容预览
  static String formatMessageContent(String type, String content, {int maxLength = 20}) {
    String result;
    
    switch (type) {
      case 'text':
        result = content;
        break;
      case 'image':
        result = '[图片]';
        break;
      case 'video':
        result = '[视频]';
        break;
      case 'file':
        result = '[文件]';
        break;
      case 'voice':
        result = '[语音]';
        break;
      case 'location':
        result = '[位置]';
        break;
      case 'red_packet':
        result = '[红包]';
        break;
      case 'system':
        result = '[系统消息]';
        break;
      default:
        result = '[未知消息类型]';
        break;
    }
    
    // 截断过长的消息内容
    if (result.length > maxLength) {
      result = '${result.substring(0, maxLength)}...';
    }
    
    return result;
  }
  
  /// 格式化未读消息数量
  /// 当未读消息数量超过99时，显示为"99+"
  static String formatUnreadCount(int count) {
    if (count <= 0) {
      return '';
    } else if (count > 99) {
      return '99+';
    } else {
      return count.toString();
    }
  }
  
  /// 格式化文件大小
  /// 将字节数转换为易读的文件大小字符串
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  /// 格式化语音时长
  /// 将秒数转换为"分:秒"格式
  static String formatVoiceDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  /// 格式化通话时长
  /// 将秒数转换为"时:分:秒"格式
  static String formatCallDuration(int seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
  
  /// 格式化金额
  /// 将金额转换为带两位小数的字符串
  static String formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }
  
  /// 格式化距离
  /// 将米数转换为易读的距离字符串
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}米';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}千米';
    }
  }
  
  /// 格式化在线状态
  /// 根据最后在线时间，返回在线状态字符串
  static String formatOnlineStatus(int lastOnlineTimestamp) {
    final lastOnlineTime = DateTime.fromMillisecondsSinceEpoch(lastOnlineTimestamp);
    final now = DateTime.now();
    final difference = now.difference(lastOnlineTime);
    
    if (difference.inMinutes < 5) {
      return '在线';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前在线';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前在线';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前在线';
    } else {
      return '长期未在线';
    }
  }
  
  /// 格式化消息状态
  /// 根据消息状态，返回状态图标
  static Icon formatMessageStatus(String status, bool isRead) {
    if (status == 'sending') {
      return Icon(
        Icons.access_time,
        size: 16,
        color: Colors.grey,
      );
    } else if (status == 'failed') {
      return Icon(
        Icons.error_outline,
        size: 16,
        color: Colors.red,
      );
    } else {
      return Icon(
        isRead ? Icons.done_all : Icons.done,
        size: 16,
        color: isRead ? Colors.blue : Colors.grey,
      );
    }
  }
  
  /// 格式化搜索结果
  /// 将搜索关键词在文本中高亮显示
  static List<TextSpan> formatSearchResult(String text, String keyword) {
    if (keyword.isEmpty) {
      return [TextSpan(text: text)];
    }
    
    final List<TextSpan> spans = [];
    final lowercaseText = text.toLowerCase();
    final lowercaseKeyword = keyword.toLowerCase();
    
    int start = 0;
    int indexOfKeyword;
    while ((indexOfKeyword = lowercaseText.indexOf(lowercaseKeyword, start)) != -1) {
      // 添加关键词前的文本
      if (indexOfKeyword > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfKeyword)));
      }
      
      // 添加高亮的关键词
      spans.add(TextSpan(
        text: text.substring(indexOfKeyword, indexOfKeyword + keyword.length),
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = indexOfKeyword + keyword.length;
    }
    
    // 添加剩余的文本
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    
    return spans;
  }
}
