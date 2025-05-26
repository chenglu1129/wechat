import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../services/group_service.dart';

class GroupProvider with ChangeNotifier {
  final GroupService _groupService;
  
  // 群组列表
  List<Group> _groups = [];
  // 当前选中的群组
  Group? _currentGroup;
  // 当前群组的成员列表
  List<GroupMember> _currentGroupMembers = [];
  // 加载状态
  bool _isLoading = false;
  // 错误信息
  String? _error;
  
  GroupProvider({required GroupService groupService}) : _groupService = groupService;
  
  // 获取群组列表
  List<Group> get groups => _groups;
  // 获取当前群组
  Group? get currentGroup => _currentGroup;
  // 获取当前群组成员
  List<GroupMember> get currentGroupMembers => _currentGroupMembers;
  // 获取加载状态
  bool get isLoading => _isLoading;
  // 获取错误信息
  String? get error => _error;
  
  // 加载用户的群组列表
  Future<void> loadUserGroups() async {
    _setLoading(true);
    _clearError();
    
    try {
      _groups = await _groupService.getUserGroups();
      notifyListeners();
    } catch (e) {
      _setError('加载群组列表失败: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 创建群组
  Future<Group?> createGroup({
    required String name,
    required List<int> memberIds,
    File? avatarFile,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final group = await _groupService.createGroup(
        name: name,
        memberIds: memberIds,
        avatarFile: avatarFile,
      );
      
      // 将新创建的群组添加到列表中
      _groups.insert(0, group);
      notifyListeners();
      
      return group;
    } catch (e) {
      _setError('创建群组失败: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // 设置当前群组并加载成员
  Future<void> setCurrentGroup(Group group) async {
    _currentGroup = group;
    notifyListeners();
    
    // 加载群组成员
    await loadGroupMembers(group.id);
  }
  
  // 加载群组成员
  Future<void> loadGroupMembers(String groupId) async {
    _setLoading(true);
    _clearError();
    
    try {
      _currentGroupMembers = await _groupService.getGroupMembers(groupId);
      notifyListeners();
    } catch (e) {
      _setError('加载群组成员失败: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 更新群组信息
  Future<bool> updateGroupInfo({
    required String groupId,
    String? name,
    String? announcement,
    File? avatarFile,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final updatedGroup = await _groupService.updateGroup(
        groupId: groupId,
        name: name,
        announcement: announcement,
        avatarFile: avatarFile,
      );
      
      // 更新群组列表中的群组信息
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index >= 0) {
        _groups[index] = updatedGroup;
      }
      
      // 如果是当前群组，更新当前群组信息
      if (_currentGroup?.id == groupId) {
        _currentGroup = updatedGroup;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('更新群组信息失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 邀请成员
  Future<bool> inviteMembers(String groupId, List<int> userIds) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.inviteMembers(groupId, userIds);
      
      // 如果是当前群组，重新加载成员列表
      if (_currentGroup?.id == groupId) {
        await loadGroupMembers(groupId);
      }
      
      return true;
    } catch (e) {
      _setError('邀请成员失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 移除成员
  Future<bool> removeMember(String groupId, int userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.removeMember(groupId, userId);
      
      // 如果是当前群组，从成员列表中移除该成员
      if (_currentGroup?.id == groupId) {
        _currentGroupMembers.removeWhere((member) => member.user.id == userId.toString());
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('移除成员失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 退出群组
  Future<bool> leaveGroup(String groupId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.leaveGroup(groupId);
      
      // 从群组列表中移除该群组
      _groups.removeWhere((group) => group.id == groupId);
      
      // 如果是当前群组，清空当前群组和成员列表
      if (_currentGroup?.id == groupId) {
        _currentGroup = null;
        _currentGroupMembers.clear();
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('退出群组失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 解散群组
  Future<bool> disbandGroup(String groupId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.disbandGroup(groupId);
      
      // 从群组列表中移除该群组
      _groups.removeWhere((group) => group.id == groupId);
      
      // 如果是当前群组，清空当前群组和成员列表
      if (_currentGroup?.id == groupId) {
        _currentGroup = null;
        _currentGroupMembers.clear();
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('解散群组失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 设置/取消管理员
  Future<bool> setAdmin(String groupId, int userId, bool isAdmin) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.setAdmin(groupId, userId, isAdmin);
      
      // 如果是当前群组，更新成员角色
      if (_currentGroup?.id == groupId) {
        final index = _currentGroupMembers.indexWhere((member) => member.user.id == userId.toString());
        if (index >= 0) {
          final member = _currentGroupMembers[index];
          _currentGroupMembers[index] = GroupMember(
            groupId: member.groupId,
            user: member.user,
            role: isAdmin ? GroupMemberRole.admin : GroupMemberRole.member,
            nickname: member.nickname,
            joinedAt: member.joinedAt,
          );
          notifyListeners();
        }
      }
      
      return true;
    } catch (e) {
      _setError('设置管理员失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 清除错误
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  // 设置错误
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  // 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
} 