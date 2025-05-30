import 'package:intl/intl.dart';

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  location,
  system,
}

class Message {
  final String id;
  final String senderId;
  final String? receiverId;
  final String? groupId;
  final MessageType type;
  final String content;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool read;
  final Map<String, dynamic>? metadata;
  final String? senderName;
  final String? senderAvatar;
  
  Message({
    required this.id,
    required this.senderId,
    this.receiverId,
    this.groupId,
    required this.type,
    required this.content,
    this.mediaUrl,
    required this.timestamp,
    this.read = false,
    this.metadata,
    this.senderName,
    this.senderAvatar,
  });
  
  // 从JSON创建消息
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      groupId: json['group_id'],
      type: _parseMessageType(json['type']),
      content: json['content'],
      mediaUrl: json['media_url'],
      timestamp: DateTime.parse(json['timestamp']),
      read: json['read'] ?? false,
      metadata: json['metadata'],
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'group_id': groupId,
      'type': type.toString().split('.').last,
      'content': content,
      'media_url': mediaUrl,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'metadata': metadata,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
    };
  }
  
  // 解析消息类型
  static MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      case 'location':
        return MessageType.location;
      case 'system':
        return MessageType.system;
      case 'text':
      default:
        return MessageType.text;
    }
  }
  
  // 格式化消息时间
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      // 今天
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == yesterday) {
      // 昨天
      return '昨天 ${DateFormat('HH:mm').format(timestamp)}';
    } else if (now.difference(timestamp).inDays < 7) {
      // 一周内
      return '${_getWeekday(timestamp.weekday)} ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      // 更早
      return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
    }
  }
  
  // 获取星期几
  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return '星期一';
      case 2:
        return '星期二';
      case 3:
        return '星期三';
      case 4:
        return '星期四';
      case 5:
        return '星期五';
      case 6:
        return '星期六';
      case 7:
        return '星期日';
      default:
        return '';
    }
  }
  
  // 判断是否为群组消息
  bool get isGroupMessage => groupId != null && groupId!.isNotEmpty;
  
  // 是否为自己发送的消息
  bool isSentByMe(String currentUserId) => senderId == currentUserId;
  
  // 创建消息的副本，可以修改部分属性
  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? groupId,
    MessageType? type,
    String? content,
    String? mediaUrl,
    DateTime? timestamp,
    bool? read,
    Map<String, dynamic>? metadata,
    String? senderName,
    String? senderAvatar,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      metadata: metadata ?? this.metadata,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
    );
  }
} 