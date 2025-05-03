import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';

/// 文本清理工具类，用于确保文本是有效的 UTF-16 字符串
/// 特别处理表情符号和其他特殊字符
class TextSanitizer {
  /// 清理文本，确保它是有效的 UTF-16 字符串
  static String sanitize(String? text) {
    if (text == null || text.isEmpty) return '';

    try {
      // 使用 characters 包处理字符串，这样可以正确处理表情符号
      final characters = text.characters;
      if (characters.isEmpty) return '';

      // 如果字符串有效，直接返回
      if (_isValidString(text)) {
        return text;
      }

      // 如果字符串无效，尝试使用 UTF-8 编解码
      try {
        final encoded = utf8.encode(text);
        final decoded = utf8.decode(encoded, allowMalformed: true);

        if (_isValidString(decoded)) {
          return decoded;
        }
      } catch (e) {
        debugPrint('UTF-8 编解码失败: $e');
      }

      // 如果编解码失败，尝试逐字符过滤
      return _filterInvalidChars(text);
    } catch (e) {
      debugPrint('清理文本失败: $e');
      // 如果所有方法都失败，返回一个安全的字符串
      return '无法显示的内容';
    }
  }

  /// 检查字符串是否有效
  static bool _isValidString(String text) {
    try {
      // 使用 characters 包检查字符串
      final _ = text.characters.toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 过滤掉无效的字符
  static String _filterInvalidChars(String text) {
    final buffer = StringBuffer();

    try {
      // 使用 characters 包处理字符串
      final chars = text.characters;

      for (final char in chars) {
        try {
          // 检查字符是否有效
          if (_isValidChar(char)) {
            buffer.write(char);
          }
        } catch (e) {
          debugPrint('跳过无效字符: $char, 错误: $e');
          continue;
        }
      }

      final result = buffer.toString();
      if (result.isNotEmpty) {
        return result;
      }

      // 如果上面的方法没有产生有效结果，使用更保守的方法
      buffer.clear();

      // 逐个代码点处理
      for (final rune in text.runes) {
        try {
          // 检查代码点范围
          if (_isValidCodePoint(rune)) {
            buffer.write(String.fromCharCode(rune));
          }
        } catch (e) {
          debugPrint('处理代码点时出错: $rune, 错误: $e');
          continue;
        }
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('过滤字符时出错: $e');
      return '无法显示的内容';
    }
  }

  /// 检查字符是否有效
  static bool _isValidChar(String char) {
    try {
      // 尝试编码解码
      final encoded = utf8.encode(char);
      final decoded = utf8.decode(encoded);
      return decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 检查代码点是否在有效范围内
  static bool _isValidCodePoint(int codePoint) {
    // 基本 ASCII
    if (codePoint >= 32 && codePoint <= 126) {
      return true;
    }

    // 常见汉字 (CJK Unified Ideographs)
    if (codePoint >= 0x4E00 && codePoint <= 0x9FFF) {
      return true;
    }

    // 表情符号范围 (Emoji)
    if ((codePoint >= 0x1F300 && codePoint <= 0x1F6FF) || // Miscellaneous Symbols and Pictographs
        (codePoint >= 0x1F900 && codePoint <= 0x1F9FF) || // Supplemental Symbols and Pictographs
        (codePoint >= 0x1FA70 && codePoint <= 0x1FAFF) || // Symbols and Pictographs Extended-A
        (codePoint >= 0x2600 && codePoint <= 0x26FF) ||   // Miscellaneous Symbols
        (codePoint >= 0x2700 && codePoint <= 0x27BF) ||   // Dingbats
        (codePoint >= 0xFE00 && codePoint <= 0xFE0F) ||   // Variation Selectors
        (codePoint >= 0x1F1E6 && codePoint <= 0x1F1FF)) { // Regional Indicator Symbols
      return true;
    }

    // 其他常用 Unicode 范围
    if ((codePoint >= 0x0080 && codePoint <= 0x07FF) || // Latin-1 Supplement + Latin Extended
        (codePoint >= 0x0900 && codePoint <= 0x097F) || // Devanagari
        (codePoint >= 0x0400 && codePoint <= 0x04FF) || // Cyrillic
        (codePoint >= 0x0370 && codePoint <= 0x03FF) || // Greek and Coptic
        (codePoint >= 0x0600 && codePoint <= 0x06FF) || // Arabic
        (codePoint >= 0x3040 && codePoint <= 0x309F) || // Hiragana
        (codePoint >= 0x30A0 && codePoint <= 0x30FF) || // Katakana
        (codePoint >= 0xAC00 && codePoint <= 0xD7AF)) { // Hangul Syllables
      return true;
    }

    return false;
  }

  /// 清理消息对象中的文本字段
  static Map<String, dynamic> sanitizeMessage(Map<String, dynamic> message) {
    try {
      final sanitizedMessage = Map<String, dynamic>.from(message);
      final messageType = sanitizedMessage['type']?.toString() ?? 'text';

      // 根据消息类型处理内容
      switch (messageType) {
        case 'text':
        case 'emoji':
          // 文本和表情消息需要清理内容
          if (sanitizedMessage.containsKey('content')) {
            sanitizedMessage['content'] = sanitize(sanitizedMessage['content']?.toString());
          }
          break;

        case 'image':
        case 'video':
        case 'file':
        case 'voice':
          // 媒体消息不清理内容，因为内容是文件路径
          // 但需要确保文件名等字段被清理
          if (sanitizedMessage.containsKey('file_name')) {
            sanitizedMessage['file_name'] = sanitize(sanitizedMessage['file_name']?.toString());
          }
          if (sanitizedMessage.containsKey('filename')) {
            sanitizedMessage['filename'] = sanitize(sanitizedMessage['filename']?.toString());
          }
          break;

        case 'location':
          // 位置消息需要清理地址
          if (sanitizedMessage.containsKey('address')) {
            sanitizedMessage['address'] = sanitize(sanitizedMessage['address']?.toString());
          }
          break;

        case 'redpacket':
        case 'transfer':
          // 红包和转账消息需要特殊处理
          if (sanitizedMessage.containsKey('extra') && sanitizedMessage['extra'] is String) {
            try {
              // 尝试解析 extra 字段
              final extraJson = safeJsonDecode(sanitizedMessage['extra']);
              if (extraJson != null && extraJson is Map<String, dynamic>) {
                // 清理 extra 中的文本字段
                if (extraJson.containsKey('greeting')) {
                  extraJson['greeting'] = sanitize(extraJson['greeting']?.toString());
                }
                if (extraJson.containsKey('message')) {
                  extraJson['message'] = sanitize(extraJson['message']?.toString());
                }
                // 重新编码 extra 字段
                sanitizedMessage['extra'] = json.encode(extraJson);
              } else {
                // 如果无法解析，直接清理整个字符串
                sanitizedMessage['extra'] = sanitize(sanitizedMessage['extra']);
              }
            } catch (e) {
              debugPrint('清理 extra 字段失败: $e');
              sanitizedMessage['extra'] = sanitize(sanitizedMessage['extra']);
            }
          }

          // 清理红包/转账消息的内容
          if (sanitizedMessage.containsKey('content')) {
            sanitizedMessage['content'] = sanitize(sanitizedMessage['content']?.toString());
          }
          break;

        default:
          // 其他类型消息，清理内容
          if (sanitizedMessage.containsKey('content')) {
            sanitizedMessage['content'] = sanitize(sanitizedMessage['content']?.toString());
          }
      }

      // 清理通用字段

      // 清理昵称
      if (sanitizedMessage.containsKey('from_nickname')) {
        sanitizedMessage['from_nickname'] = sanitize(sanitizedMessage['from_nickname']?.toString());
      }

      // 清理发送者昵称
      if (sanitizedMessage.containsKey('sender_nickname')) {
        sanitizedMessage['sender_nickname'] = sanitize(sanitizedMessage['sender_nickname']?.toString());
      }

      // 清理标题
      if (sanitizedMessage.containsKey('title')) {
        sanitizedMessage['title'] = sanitize(sanitizedMessage['title']?.toString());
      }

      // 清理描述
      if (sanitizedMessage.containsKey('description')) {
        sanitizedMessage['description'] = sanitize(sanitizedMessage['description']?.toString());
      }

      // 清理翻译文本
      if (sanitizedMessage.containsKey('translated_text')) {
        sanitizedMessage['translated_text'] = sanitize(sanitizedMessage['translated_text']?.toString());
      }

      return sanitizedMessage;
    } catch (e) {
      debugPrint('清理消息对象失败: $e');
      // 如果清理失败，返回一个安全的消息对象
      return {
        'content': '无法显示的内容',
        'type': 'text',
        'created_at': message['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'from_id': message['from_id'] ?? 0,
        'to_id': message['to_id'] ?? 0,
      };
    }
  }

  /// 清理消息列表中的所有消息
  static List<Map<String, dynamic>> sanitizeMessages(List<Map<String, dynamic>> messages) {
    try {
      return messages.map((message) => sanitizeMessage(message)).toList();
    } catch (e) {
      debugPrint('清理消息列表失败: $e');
      // 如果清理失败，返回一个空列表
      return [];
    }
  }

  /// 安全地解析 JSON 字符串
  static dynamic safeJsonDecode(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }

    try {
      return json.decode(jsonString);
    } catch (e) {
      debugPrint('JSON 解析失败: $e');
      return null;
    }
  }
}
