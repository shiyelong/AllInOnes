import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker_flutter;
import 'dart:io';
import '../../../common/theme_manager.dart';

class EmojiPicker extends StatelessWidget {
  final void Function(String emoji) onSelected;
  const EmojiPicker({Key? key, required this.onSelected}) : super(key: key);

  // 备用简单表情列表，当emoji_picker_flutter不可用时使用
  static const emojis = [
    '😀','😁','😂','🤣','😍','😎','😭','😡','👍','🙏','🎉','❤️','🔥','🥳','🤔','😏','😅','😳','😱','🤗','😇','😘',
    '👋','👌','✌️','🤞','🙌','👏','💪','🤝','🙄','😴','🤑','🤠','👻','👽','🤖','💩','🐶','🐱','🐭','🐹','🐰','🦊',
    '🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵','🙈','🙉','🙊','🐔','🐧','🐦','🐤','🦆','🦅','🦉','🦇','🐺','🐗',
    '🐴','🦄','🐝','🐛','🦋','🐌','🐞','🐜','🦟','🦗','🕷','🕸','🦂','🐢','🐍','🦎','🦖','🦕','🐙','🦑','🦐','🦞',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    // 尝试使用emoji_picker_flutter
    try {
      return emoji_picker_flutter.EmojiPicker(
        onEmojiSelected: (category, emoji) {
          onSelected(emoji.emoji);
        },
        config: emoji_picker_flutter.Config(
          columns: 7,
          emojiSizeMax: 32.0,
          verticalSpacing: 0,
          horizontalSpacing: 0,
          initCategory: emoji_picker_flutter.Category.RECENT,
          bgColor: theme.isDark ? Colors.grey[900]! : Colors.grey[100]!,
          indicatorColor: theme.primaryColor,
          iconColor: Colors.grey,
          iconColorSelected: theme.primaryColor,
          // progressIndicatorColor: theme.primaryColor, // 移除不支持的属性
          backspaceColor: theme.primaryColor,
          skinToneDialogBgColor: theme.isDark ? Colors.grey[800]! : Colors.white,
          skinToneIndicatorColor: Colors.grey,
          enableSkinTones: true,
          // showRecentsTab: true, // 移除不支持的属性
          // recentsLimit: 28, // 移除不支持的属性
          noRecents: Text(
            '最近没有使用表情',
            style: TextStyle(fontSize: 20, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          tabIndicatorAnimDuration: kTabScrollDuration,
          categoryIcons: emoji_picker_flutter.CategoryIcons(),
          buttonMode: emoji_picker_flutter.ButtonMode.MATERIAL,
        ),
      );
    } catch (e) {
      // 如果emoji_picker_flutter不可用，使用备用简单表情列表
      print('使用备用表情选择器: $e');
      return Container(
        height: 240,
        color: theme.isDark ? Colors.grey[900] : Colors.grey[100],
        child: GridView.count(
          crossAxisCount: 8,
          children: emojis.map((e) => InkWell(
            onTap: () => onSelected(e),
            child: Center(child: Text(e, style: TextStyle(fontSize: 28))),
          )).toList(),
        ),
      );
    }
  }
}
