import 'package:flutter/material.dart';

class SocialLoginBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const SocialLoginBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
