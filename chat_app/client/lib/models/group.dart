import 'package:intl/intl.dart';
import 'user.dart';

enum GroupMemberRole {
  owner,
  admin,
  member,
}

class Group {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? announcement;
  final String ownerId;
  final List<String> adminIds;
  final int memberCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Group({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.announcement,
    required this.ownerId,
    required this.adminIds,
    this.memberCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  // 从JSON创建群组
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'].toString(),
      name: json['name'],
      avatarUrl: json['avatar_url'],
      announcement: json['announcement'],
      ownerId: json['owner_id'].toString(),
      adminIds: (json['admin_ids'] as List<dynamic>?)?.map((id) => id.toString()).toList() ?? [],
      memberCount: json['member_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'announcement': announcement,
      'owner_id': ownerId,
      'admin_ids': adminIds,
      'member_count': memberCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // 复制并修改群组
  Group copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? announcement,
    String? ownerId,
    List<String>? adminIds,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      announcement: announcement ?? this.announcement,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 判断用户是否为群主
  bool isOwner(String userId) => ownerId == userId;

  // 判断用户是否为管理员
  bool isAdmin(String userId) => adminIds.contains(userId) || isOwner(userId);

  // 格式化创建时间
  String get formattedCreatedAt {
    return DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
  }
}

class GroupMember {
  final String groupId;
  final User user;
  final GroupMemberRole role;
  final String? nickname;
  final DateTime joinedAt;

  GroupMember({
    required this.groupId,
    required this.user,
    required this.role,
    this.nickname,
    required this.joinedAt,
  });

  // 从JSON创建群组成员
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      groupId: json['group_id'].toString(),
      user: User.fromJson(json['user']),
      role: _parseRole(json['role']),
      nickname: json['nickname'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'user': user.toJson(),
      'role': role.toString().split('.').last,
      'nickname': nickname,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  // 解析成员角色
  static GroupMemberRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return GroupMemberRole.owner;
      case 'admin':
        return GroupMemberRole.admin;
      case 'member':
      default:
        return GroupMemberRole.member;
    }
  }

  // 格式化加入时间
  String get formattedJoinedAt {
    return DateFormat('yyyy-MM-dd HH:mm').format(joinedAt);
  }
} 