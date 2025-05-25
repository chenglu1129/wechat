import 'package:flutter/material.dart';

import '../models/friend_request.dart';

class FriendRequestItem extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  
  const FriendRequestItem({
    Key? key,
    required this.request,
    this.onAccept,
    this.onReject,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: request.sender.avatarUrl != null
                      ? NetworkImage(request.sender.avatarUrl!)
                      : null,
                  child: request.sender.avatarUrl == null
                      ? Text(request.sender.username[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.sender.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        request.sender.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  request.formattedCreatedTime,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            // 验证消息
            if (request.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.message,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
            
            // 状态标签
            if (!request.isPending) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusText(request.status),
                  style: TextStyle(
                    color: _getStatusColor(request.status),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            
            // 按钮行
            if (onAccept != null || onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onReject != null) ...[
                    OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('拒绝'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (onAccept != null)
                    ElevatedButton(
                      onPressed: onAccept,
                      child: const Text('接受'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // 获取状态颜色
  Color _getStatusColor(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return Colors.blue;
      case FriendRequestStatus.accepted:
        return Colors.green;
      case FriendRequestStatus.rejected:
        return Colors.red;
      case FriendRequestStatus.expired:
        return Colors.grey;
    }
  }
  
  // 获取状态文本
  String _getStatusText(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return '待处理';
      case FriendRequestStatus.accepted:
        return '已接受';
      case FriendRequestStatus.rejected:
        return '已拒绝';
      case FriendRequestStatus.expired:
        return '已过期';
    }
  }
} 