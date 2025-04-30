import 'package:flutter/material.dart';

class EmojiPicker extends StatelessWidget {
  final void Function(String emoji) onSelected;
  const EmojiPicker({Key? key, required this.onSelected}) : super(key: key);

  static const emojis = [
    '😀','😁','😂','🤣','😍','😎','😭','😡','👍','🙏','🎉','❤️','🔥','🥳','🤔','😏','😅','😳','😱','🤗','😇','😘'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      color: Colors.grey[100],
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
