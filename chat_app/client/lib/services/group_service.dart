import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';
import '../utils/mock_group_service.dart';

class GroupService {
  final TokenManager tokenManager;
  final bool useMock; // 是否使用模拟服务
  final MockGroupService _mockService = MockGroupService();
  
  GroupService({required this.tokenManager, this.useMock = true});
  
  // 创建群组
  Future<Group> createGroup({
    required String name,
    required List<int> memberIds,
    File? avatarFile,
  }) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.createGroup(
        name: name,
        memberIds: memberIds,
        avatarFile: avatarFile,
      );
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    // 如果有头像，先上传头像
    String? avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await _uploadGroupAvatar(token, avatarFile);
    }
    
    // 创建群组
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/groups'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
      body: jsonEncode({
        'name': name,
        'member_ids': memberIds,
        'avatar_url': avatarUrl,
      }),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Group.fromJson(data);
    } else {
      throw Exception('创建群组失败: ${response.body}');
    }
  }
  
  // 获取群组信息
  Future<Group> getGroupInfo(String groupId) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.getGroupInfo(groupId);
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Group.fromJson(data);
    } else {
      throw Exception('获取群组信息失败: ${response.body}');
    }
  }
  
  // 获取用户加入的群组列表
  Future<List<Group>> getUserGroups() async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.getUserGroups();
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/groups/user'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((item) => Group.fromJson(item)).toList();
    } else {
      throw Exception('获取群组列表失败: ${response.body}');
    }
  }
  
  // 更新群组信息
  Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? announcement,
    File? avatarFile,
  }) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.updateGroup(
        groupId: groupId,
        name: name,
        announcement: announcement,
        avatarFile: avatarFile,
      );
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    // 如果有头像，先上传头像
    String? avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await _uploadGroupAvatar(token, avatarFile);
    }
    
    // 准备请求体
    final Map<String, dynamic> requestBody = {};
    if (name != null) requestBody['name'] = name;
    if (announcement != null) requestBody['announcement'] = announcement;
    if (avatarUrl != null) requestBody['avatar_url'] = avatarUrl;
    
    // 更新群组信息
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Group.fromJson(data);
    } else {
      throw Exception('更新群组信息失败: ${response.body}');
    }
  }
  
  // 获取群组成员列表
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.getGroupMembers(groupId);
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/members'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((item) => GroupMember.fromJson(item)).toList();
    } else {
      throw Exception('获取群组成员列表失败: ${response.body}');
    }
  }
  
  // 邀请用户加入群组
  Future<void> inviteMembers(String groupId, List<int> userIds) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.inviteMembers(groupId, userIds);
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/members'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
      body: jsonEncode({
        'user_ids': userIds,
      }),
    );
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('邀请成员失败: ${response.body}');
    }
  }
  
  // 移除群组成员
  Future<void> removeMember(String groupId, int userId) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.removeMember(groupId, userId);
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/members/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
    );
    
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('移除成员失败: ${response.body}');
    }
  }
  
  // 退出群组
  Future<void> leaveGroup(String groupId) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.leaveGroup(groupId);
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/leave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
    );
    
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('退出群组失败: ${response.body}');
    }
  }
  
  // 解散群组
  Future<void> disbandGroup(String groupId) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.disbandGroup(groupId);
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
    );
    
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('解散群组失败: ${response.body}');
    }
  }
  
  // 设置/取消管理员
  Future<void> setAdmin(String groupId, int userId, bool isAdmin) async {
    // 如果使用模拟服务
    if (useMock) {
      return _mockService.setAdmin(groupId, userId, isAdmin);
    }
    
    // 使用真实API
    final token = await tokenManager.getAuthToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/members/$userId/admin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
      body: jsonEncode({
        'is_admin': isAdmin,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('设置管理员失败: ${response.body}');
    }
  }
  
  // 上传群组头像
  Future<String> _uploadGroupAvatar(String token, File imageFile) async {
    // 创建多部分请求
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}/groups/avatar'),
    );
    
    // 添加授权头
    request.headers['Authorization'] = token;
    
    // 添加文件
    final fileExtension = imageFile.path.split('.').last.toLowerCase();
    final mimeType = _getMimeType(fileExtension);
    
    request.files.add(
      await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
        contentType: MediaType('image', mimeType),
      ),
    );
    
    // 发送请求
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['avatar_url'];
    } else {
      throw Exception('上传群组头像失败: ${response.body}');
    }
  }
  
  // 获取MIME类型
  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }
} 