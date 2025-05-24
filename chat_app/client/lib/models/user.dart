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
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
    );
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