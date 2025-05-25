class User {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final bool isOnline;
  
  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.isOnline = false,
  });
  
  // 从JSON创建用户
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        username: json['username'] ?? '未知用户',
        email: json['email'] ?? 'unknown@example.com',
        avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
        isOnline: json['is_online'] ?? json['isOnline'] ?? false,
      );
    } catch (e) {
      // 如果解析失败，抛出异常让调用者处理
      throw FormatException('无法解析用户数据: $e');
    }
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
    };
  }
  
  // 复制并修改用户
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? avatarUrl,
    bool? isOnline,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
    );
  }
} 