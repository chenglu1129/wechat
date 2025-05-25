import '../models/user.dart';

enum FriendRequestStatus {
  pending,   // 等待验证
  accepted,  // 已接受
  rejected,  // 已拒绝
  expired    // 已过期
}

class FriendRequest {
  final int id;
  final User sender;      // 发送请求的用户
  final User receiver;    // 接收请求的用户
  final String message;   // 验证消息
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  FriendRequest({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });
  
  // 从JSON创建
  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      sender: User.fromJson(json['sender']),
      receiver: User.fromJson(json['receiver']),
      message: json['message'] ?? '',
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
  
  // 解析状态
  static FriendRequestStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return FriendRequestStatus.pending;
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      case 'expired':
        return FriendRequestStatus.expired;
      default:
        return FriendRequestStatus.pending;
    }
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.toJson(),
      'receiver': receiver.toJson(),
      'message': message,
      'status': _statusToString(status),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  // 状态转字符串
  static String _statusToString(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'pending';
      case FriendRequestStatus.accepted:
        return 'accepted';
      case FriendRequestStatus.rejected:
        return 'rejected';
      case FriendRequestStatus.expired:
        return 'expired';
    }
  }
  
  // 是否处于待处理状态
  bool get isPending => status == FriendRequestStatus.pending;
  
  // 是否已接受
  bool get isAccepted => status == FriendRequestStatus.accepted;
  
  // 是否已拒绝
  bool get isRejected => status == FriendRequestStatus.rejected;
  
  // 是否已过期
  bool get isExpired => status == FriendRequestStatus.expired;
  
  // 返回格式化的创建时间
  String get formattedCreatedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
} 