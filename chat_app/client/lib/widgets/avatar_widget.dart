import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const AvatarWidget({
    Key? key,
    this.avatarUrl,
    required this.name,
    this.radius = 24.0,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultBackgroundColor = backgroundColor ?? Theme.of(context).primaryColor;
    final defaultTextColor = textColor ?? Colors.white;

    // 如果有头像URL，显示网络图片
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // 图片加载失败时显示首字母
          return;
        },
      );
    }

    // 否则显示名称首字母
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: defaultBackgroundColor,
      child: Text(
        initials,
        style: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
} 