import 'package:flutter/material.dart';
import '../../../../common/theme.dart';

/// 好友列表中的好友请求头部组件
class FriendRequestHeader extends StatelessWidget {
  final int requestCount;
  final VoidCallback onTap;

  const FriendRequestHeader({
    Key? key,
    required this.requestCount,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 如果有请求，使用更醒目的样式
    final hasRequests = requestCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasRequests
              ? Colors.blue.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(
              color: hasRequests
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  color: hasRequests ? Colors.blue : AppTheme.primaryColor,
                  size: 24,
                ),
                if (hasRequests)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          requestCount > 99 ? '99+' : requestCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '好友请求',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: hasRequests ? Colors.blue : null,
                    ),
                  ),
                  if (hasRequests)
                    Text(
                      '您有 $requestCount 个待处理的好友请求',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (hasRequests)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '点击处理',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: hasRequests ? Colors.blue : null,
            ),
          ],
        ),
      ),
    );
  }
}
