import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group.dart';
import '../models/user.dart';

/// 模拟群组服务，用于在服务端API尚未实现时提供群组功能
class MockGroupService {
  static const String _groupsKey = 'mock_groups';
  static const String _groupMembersKey = 'mock_group_members';
  
  // 单例模式
  static final MockGroupService _instance = MockGroupService._internal();
  factory MockGroupService() => _instance;
  MockGroupService._internal();
  
  // 获取本地存储的群组列表
  Future<List<Group>> _getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = prefs.getStringList(_groupsKey) ?? [];
    print('从本地存储加载群组: ${groupsJson.length}个');
    if (groupsJson.isNotEmpty) {
      for (var json in groupsJson) {
        try {
          final group = Group.fromJson(jsonDecode(json));
          print('加载群组: ID=${group.id}, 名称=${group.name}');
        } catch (e) {
          print('解析群组JSON失败: $e');
          print('原始JSON: $json');
        }
      }
    }
    
    try {
      return groupsJson.map((json) => Group.fromJson(jsonDecode(json))).toList();
    } catch (e) {
      print('转换群组列表失败: $e');
      return [];
    }
  }
  
  // 保存群组列表到本地
  Future<void> _saveGroups(List<Group> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = groups.map((group) {
      final json = jsonEncode(group.toJson());
      print('序列化群组: ID=${group.id}, 名称=${group.name}, JSON长度=${json.length}');
      return json;
    }).toList();
    
    print('保存群组到本地存储: ${groups.length}个');
    for (var group in groups) {
      print('保存群组: ID=${group.id}, 名称=${group.name}, 成员数=${group.memberCount}');
    }
    
    try {
      await prefs.setStringList(_groupsKey, groupsJson);
      print('群组保存成功');
    } catch (e) {
      print('保存群组到本地存储失败: $e');
    }
  }
  
  // 获取本地存储的群组成员列表
  Future<List<GroupMember>> _getGroupMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final membersJson = prefs.getStringList(_groupMembersKey) ?? [];
    print('从本地存储加载群组成员: ${membersJson.length}个');
    
    try {
      return membersJson.map((json) => GroupMember.fromJson(jsonDecode(json))).toList();
    } catch (e) {
      print('转换群组成员列表失败: $e');
      return [];
    }
  }
  
  // 保存群组成员列表到本地
  Future<void> _saveGroupMembers(List<GroupMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    final membersJson = members.map((member) {
      final json = jsonEncode(member.toJson());
      print('序列化群组成员: 群组ID=${member.groupId}, 用户ID=${member.user.id}, JSON长度=${json.length}');
      return json;
    }).toList();
    
    print('保存群组成员到本地存储: ${members.length}个');
    
    try {
      await prefs.setStringList(_groupMembersKey, membersJson);
      print('群组成员保存成功');
    } catch (e) {
      print('保存群组成员到本地存储失败: $e');
    }
  }
  
  // 创建群组
  Future<Group> createGroup({
    required String name,
    required List<int> memberIds,
    File? avatarFile,
  }) async {
    print('开始创建群组: $name, 成员IDs: $memberIds');
    
    // 生成随机ID
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    // 获取当前用户ID（假设为1）
    final currentUserId = "1";
    
    // 处理头像
    String? avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await _saveAvatarLocally(avatarFile, id);
    }
    
    // 创建群组对象
    final group = Group(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      announcement: null,
      ownerId: currentUserId,
      adminIds: [currentUserId],
      memberCount: memberIds.length + 1, // 包括创建者自己
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // 获取现有群组列表
    final groups = await _getGroups();
    
    // 添加新群组
    groups.add(group);
    
    // 保存群组列表
    await _saveGroups(groups);
    
    // 创建群组成员
    final members = await _getGroupMembers();
    
    // 添加创建者为群主
    members.add(GroupMember(
      groupId: id,
      user: User(
        id: int.parse(currentUserId),
        username: "当前用户",
        email: "user@example.com",
        avatarUrl: null,
      ),
      role: GroupMemberRole.owner,
      joinedAt: DateTime.now(),
    ));
    
    // 添加其他成员
    for (final memberId in memberIds) {
      members.add(GroupMember(
        groupId: id,
        user: User(
          id: memberId,
          username: "用户$memberId",
          email: "user$memberId@example.com",
          avatarUrl: null,
        ),
        role: GroupMemberRole.member,
        joinedAt: DateTime.now(),
      ));
    }
    
    // 保存群组成员
    await _saveGroupMembers(members);
    
    // 打印调试信息
    print('创建群组成功: ID=${group.id}, 名称=${group.name}, 成员数=${group.memberCount}');
    print('当前存储的群组数量: ${groups.length}');
    
    // 验证保存是否成功
    _verifyGroupSaved(group.id);
    
    return group;
  }
  
  // 验证群组是否成功保存
  Future<void> _verifyGroupSaved(String groupId) async {
    // 延迟一秒，确保保存完成
    await Future.delayed(Duration(seconds: 1));
    
    final groups = await _getGroups();
    final foundGroup = groups.any((g) => g.id == groupId);
    
    if (foundGroup) {
      print('验证成功: 群组 $groupId 已正确保存到本地存储');
    } else {
      print('验证失败: 群组 $groupId 未能保存到本地存储');
    }
  }
  
  // 获取群组信息
  Future<Group> getGroupInfo(String groupId) async {
    print('获取群组信息: ID=$groupId');
    
    // 获取群组列表
    final groups = await _getGroups();
    
    // 查找指定群组
    final group = groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => throw Exception('群组不存在'),
    );
    
    print('获取到群组: ID=${group.id}, 名称=${group.name}, 成员数=${group.memberCount}');
    
    return group;
  }
  
  // 获取用户加入的群组列表
  Future<List<Group>> getUserGroups() async {
    print('获取用户群组列表');
    
    // 获取群组列表
    final groups = await _getGroups();
    
    print('获取到 ${groups.length} 个群组');
    for (var group in groups) {
      print('群组: ID=${group.id}, 名称=${group.name}, 成员数=${group.memberCount}');
    }
    
    // 模拟：返回所有群组（实际应该根据用户ID过滤）
    return groups;
  }
  
  // 更新群组信息
  Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? announcement,
    File? avatarFile,
  }) async {
    print('更新群组信息: ID=$groupId, 名称=$name, 公告=$announcement');
    
    // 获取群组列表
    final groups = await _getGroups();
    
    // 查找指定群组
    final index = groups.indexWhere((g) => g.id == groupId);
    if (index == -1) {
      throw Exception('群组不存在');
    }
    
    // 获取原群组
    final group = groups[index];
    
    // 处理头像
    String? avatarUrl = group.avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await _saveAvatarLocally(avatarFile, groupId);
    }
    
    // 更新群组信息
    final updatedGroup = Group(
      id: group.id,
      name: name ?? group.name,
      avatarUrl: avatarUrl,
      announcement: announcement ?? group.announcement,
      ownerId: group.ownerId,
      adminIds: group.adminIds,
      memberCount: group.memberCount,
      createdAt: group.createdAt,
      updatedAt: DateTime.now(),
    );
    
    // 更新群组列表
    groups[index] = updatedGroup;
    
    // 保存群组列表
    await _saveGroups(groups);
    
    print('群组更新成功: ID=${updatedGroup.id}, 名称=${updatedGroup.name}');
    
    return updatedGroup;
  }
  
  // 获取群组成员列表
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    print('获取群组成员列表: 群组ID=$groupId');
    
    // 获取群组成员列表
    final allMembers = await _getGroupMembers();
    
    // 过滤指定群组的成员
    final members = allMembers.where((m) => m.groupId == groupId).toList();
    
    print('获取到 ${members.length} 个群组成员');
    
    return members;
  }
  
  // 邀请用户加入群组
  Future<void> inviteMembers(String groupId, List<int> userIds) async {
    print('邀请用户加入群组: 群组ID=$groupId, 用户IDs=$userIds');
    
    // 获取群组
    final groups = await _getGroups();
    final groupIndex = groups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) {
      throw Exception('群组不存在');
    }
    
    // 更新成员数量
    final group = groups[groupIndex];
    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      avatarUrl: group.avatarUrl,
      announcement: group.announcement,
      ownerId: group.ownerId,
      adminIds: group.adminIds,
      memberCount: group.memberCount + userIds.length,
      createdAt: group.createdAt,
      updatedAt: DateTime.now(),
    );
    
    groups[groupIndex] = updatedGroup;
    await _saveGroups(groups);
    
    // 获取群组成员列表
    final members = await _getGroupMembers();
    
    // 添加新成员
    for (final userId in userIds) {
      members.add(GroupMember(
        groupId: groupId,
        user: User(
          id: userId,
          username: "用户$userId",
          email: "user$userId@example.com",
          avatarUrl: null,
        ),
        role: GroupMemberRole.member,
        joinedAt: DateTime.now(),
      ));
    }
    
    // 保存群组成员
    await _saveGroupMembers(members);
    
    print('邀请成员成功，当前群组成员数: ${updatedGroup.memberCount}');
  }
  
  // 移除群组成员
  Future<void> removeMember(String groupId, int userId) async {
    print('移除群组成员: 群组ID=$groupId, 用户ID=$userId');
    
    // 获取群组
    final groups = await _getGroups();
    final groupIndex = groups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) {
      throw Exception('群组不存在');
    }
    
    // 更新成员数量
    final group = groups[groupIndex];
    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      avatarUrl: group.avatarUrl,
      announcement: group.announcement,
      ownerId: group.ownerId,
      adminIds: group.adminIds.where((id) => id != userId.toString()).toList(),
      memberCount: group.memberCount - 1,
      createdAt: group.createdAt,
      updatedAt: DateTime.now(),
    );
    
    groups[groupIndex] = updatedGroup;
    await _saveGroups(groups);
    
    // 获取群组成员列表
    final members = await _getGroupMembers();
    
    // 移除成员
    members.removeWhere((m) => m.groupId == groupId && m.user.id == userId);
    
    // 保存群组成员
    await _saveGroupMembers(members);
    
    print('移除成员成功，当前群组成员数: ${updatedGroup.memberCount}');
  }
  
  // 退出群组
  Future<void> leaveGroup(String groupId) async {
    print('退出群组: ID=$groupId');
    
    // 获取当前用户ID（假设为1）
    final currentUserId = 1;
    
    // 调用移除成员方法
    await removeMember(groupId, currentUserId);
    
    print('退出群组成功');
  }
  
  // 解散群组
  Future<void> disbandGroup(String groupId) async {
    print('解散群组: ID=$groupId');
    
    // 获取群组列表
    final groups = await _getGroups();
    
    // 移除群组
    groups.removeWhere((g) => g.id == groupId);
    
    // 保存群组列表
    await _saveGroups(groups);
    
    // 获取群组成员列表
    final members = await _getGroupMembers();
    
    // 移除群组成员
    members.removeWhere((m) => m.groupId == groupId);
    
    // 保存群组成员
    await _saveGroupMembers(members);
    
    print('解散群组成功');
  }
  
  // 设置/取消管理员
  Future<void> setAdmin(String groupId, int userId, bool isAdmin) async {
    print('设置管理员: 群组ID=$groupId, 用户ID=$userId, 是否为管理员=$isAdmin');
    
    // 获取群组
    final groups = await _getGroups();
    final groupIndex = groups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) {
      throw Exception('群组不存在');
    }
    
    // 更新管理员列表
    final group = groups[groupIndex];
    List<String> adminIds = List.from(group.adminIds);
    
    if (isAdmin) {
      if (!adminIds.contains(userId.toString())) {
        adminIds.add(userId.toString());
      }
    } else {
      adminIds.removeWhere((id) => id == userId.toString());
    }
    
    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      avatarUrl: group.avatarUrl,
      announcement: group.announcement,
      ownerId: group.ownerId,
      adminIds: adminIds,
      memberCount: group.memberCount,
      createdAt: group.createdAt,
      updatedAt: DateTime.now(),
    );
    
    groups[groupIndex] = updatedGroup;
    await _saveGroups(groups);
    
    // 获取群组成员列表
    final members = await _getGroupMembers();
    
    // 更新成员角色
    final memberIndex = members.indexWhere((m) => m.groupId == groupId && m.user.id == userId);
    if (memberIndex != -1) {
      final member = members[memberIndex];
      members[memberIndex] = GroupMember(
        groupId: member.groupId,
        user: member.user,
        role: isAdmin ? GroupMemberRole.admin : GroupMemberRole.member,
        nickname: member.nickname,
        joinedAt: member.joinedAt,
      );
      
      // 保存群组成员
      await _saveGroupMembers(members);
    }
    
    print('设置管理员成功，当前管理员数量: ${adminIds.length}');
  }
  
  // 将头像保存到本地并返回路径
  Future<String> _saveAvatarLocally(File imageFile, String groupId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/group_avatars';
      
      // 创建目录
      await Directory(path).create(recursive: true);
      
      // 生成文件名
      final fileName = 'group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$path/$fileName';
      
      // 复制文件
      await imageFile.copy(filePath);
      
      print('头像保存成功: $filePath');
      
      // 返回本地路径
      return 'file://$filePath';
    } catch (e) {
      print('保存头像失败: $e');
      return '';
    }
  }
} 