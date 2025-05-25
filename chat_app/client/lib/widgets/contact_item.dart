import 'package:flutter/material.dart';
import '../models/user.dart';
import 'online_status_indicator.dart';

class ContactItem extends StatelessWidget {
  final User user;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? lastMessage;
  final DateTime? lastActive;
  
  const ContactItem({
    Key? key,
    required this.user,
    this.onTap,
    this.onLongPress,
    this.lastMessage,
    this.lastActive,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            Hero(
              tag: 'avatar-${user.id}',
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? null
                    : Text(
                        user.username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!)
                    : null,
              ),
            ),
            if (user.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: OnlineStatusIndicator(
                  isOnline: user.isOnline,
                  size: 12,
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastActive != null)
              Text(
                _formatLastActive(lastActive!),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        subtitle: Text(
          lastMessage ?? user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: lastMessage != null ? Colors.grey.shade800 : Colors.grey.shade600,
          ),
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
  
  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    final lastActiveDate = DateTime(
      lastActive.year,
      lastActive.month,
      lastActive.day,
    );
    
    if (lastActiveDate == today) {
      // 今天，显示时间
      return '${lastActive.hour.toString().padLeft(2, '0')}:${lastActive.minute.toString().padLeft(2, '0')}';
    } else if (lastActiveDate == yesterday) {
      // 昨天
      return '昨天';
    } else if (now.difference(lastActive).inDays < 7) {
      // 一周内，显示星期几
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[lastActive.weekday - 1];
    } else {
      // 更早，显示日期
      return '${lastActive.month}/${lastActive.day}';
    }
  }
} 