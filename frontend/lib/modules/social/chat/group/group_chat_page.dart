import 'package:flutter/material.dart';
import 'group_chat_controller.dart';
import 'widgets/group_chat_message_list.dart';
import 'widgets/group_chat_input_box.dart';

class GroupChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: GroupChatMessageList()),
        GroupChatInputBox(),
      ],
    );
  }
}
