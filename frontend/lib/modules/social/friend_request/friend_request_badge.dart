import 'package:flutter/material.dart';

/// 红点组件，用于显示未读好友申请数
class FriendRequestBadge extends StatelessWidget {
  final int unreadCount;
  final Widget child;
  const FriendRequestBadge({required this.unreadCount, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (unreadCount > 0)
          Positioned(
            right: -2, top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
      ],
    );
  }
}
