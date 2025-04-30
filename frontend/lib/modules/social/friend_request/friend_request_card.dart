import 'package:flutter/material.dart';

class FriendRequestCard extends StatelessWidget {
  final String fromUser;
  final String time;
  final bool agreed;
  final VoidCallback onAgree;

  const FriendRequestCard({
    required this.fromUser,
    required this.time,
    required this.agreed,
    required this.onAgree,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text(fromUser, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(time),
        trailing: agreed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: onAgree,
                child: const Text('同意'),
              ),
      ),
    );
  }
}
