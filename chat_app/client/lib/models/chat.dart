import 'package:intl/intl.dart';

enum ChatType {
  private,
  group,
}

class Chat {
  final String id;
  final String name;
  final String? avatarUrl;
  final ChatType type;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  
  Chat({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.type,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });
  
  // 从JSON创建聊天
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      type: json['type'] == 'group' ? ChatType.group : ChatType.private,
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      isOnline: json['is_online'] ?? false,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'type': type == ChatType.group ? 'group' : 'private',
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
      'is_online': isOnline,
    };
  }
  
  // 复制并修改聊天
  Chat copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    ChatType? type,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
    );
  }
  
  // 格式化最后消息时间
  String get formattedLastMessageTime {
    if (lastMessageTime == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(lastMessageTime!.year, lastMessageTime!.month, lastMessageTime!.day);
    
    if (messageDate == today) {
      // 今天
      return DateFormat('HH:mm').format(lastMessageTime!);
    } else if (messageDate == yesterday) {
      // 昨天
      return '昨天';
    } else if (now.difference(lastMessageTime!).inDays < 7) {
      // 一周内
      return _getWeekday(lastMessageTime!.weekday);
    } else {
      // 更早
      return DateFormat('MM-dd').format(lastMessageTime!);
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
} 