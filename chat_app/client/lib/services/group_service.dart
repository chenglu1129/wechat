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
    print('GroupService.createGroup: 名称=$name, 成员数=${memberIds.length}, useMock=$useMock');
    
    // 如果明确指定使用模拟服务
    if (useMock) {
      print('使用模拟服务创建群组');
      return _mockService.createGroup(
        name: name,
        memberIds: memberIds,
        avatarFile: avatarFile,
      );
    }
    
    // 尝试使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API创建群组，令牌长度: ${token.length}');
      
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
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final group = Group.fromJson(data);
        print('API创建群组成功: ID=${group.id}, 名称=${group.name}');
        return group;
      } else {
        // API调用失败，回退到模拟服务
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.createGroup(
          name: name,
          memberIds: memberIds,
          avatarFile: avatarFile,
        );
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.createGroup(
        name: name,
        memberIds: memberIds,
        avatarFile: avatarFile,
      );
    }
  }
  
  // 获取群组信息
  Future<Group> getGroupInfo(String groupId) async {
    print('GroupService.getGroupInfo: ID=$groupId, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务获取群组信息');
      return _mockService.getGroupInfo(groupId);
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API获取群组信息，令牌长度: ${token.length}');
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/groups/$groupId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final group = Group.fromJson(data);
        print('API获取群组信息成功: ID=${group.id}, 名称=${group.name}');
        return group;
      } else {
        // API调用失败，回退到模拟服务
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.getGroupInfo(groupId);
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.getGroupInfo(groupId);
    }
  }
  
  // 获取用户加入的群组列表
  Future<List<Group>> getUserGroups() async {
    print('GroupService.getUserGroups: useMock=$useMock');
    
    // 如果明确指定使用模拟服务
    if (useMock) {
      print('使用模拟服务获取用户群组列表');
      return _mockService.getUserGroups();
    }
    
    // 尝试使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API获取用户群组列表，令牌长度: ${token.length}');
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/groups/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final groups = data.map((item) => Group.fromJson(item)).toList();
        print('API获取群组列表成功: ${groups.length}个群组');
        return groups;
      } else {
        // API调用失败，回退到模拟服务
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.getUserGroups();
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.getUserGroups();
    }
  }
  
  // 更新群组信息
  Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? announcement,
    File? avatarFile,
  }) async {
    print('GroupService.updateGroup: ID=$groupId, 名称=$name, 公告=$announcement, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务更新群组');
      return _mockService.updateGroup(
        groupId: groupId,
        name: name,
        announcement: announcement,
        avatarFile: avatarFile,
      );
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API更新群组，令牌长度: ${token.length}');
      
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
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final group = Group.fromJson(data);
        print('API更新群组成功: ID=${group.id}, 名称=${group.name}');
        return group;
      } else {
        // API调用失败，回退到模拟服务
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.updateGroup(
          groupId: groupId,
          name: name,
          announcement: announcement,
          avatarFile: avatarFile,
        );
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.updateGroup(
        groupId: groupId,
        name: name,
        announcement: announcement,
        avatarFile: avatarFile,
      );
    }
  }
  
  // 获取群组成员列表
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    print('GroupService.getGroupMembers: ID=$groupId, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务获取群组成员');
      return _mockService.getGroupMembers(groupId);
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API获取群组成员，令牌长度: ${token.length}');
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/members'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final members = data.map((item) => GroupMember.fromJson(item)).toList();
        print('API获取群组成员成功: ${members.length}个成员');
        return members;
      } else {
        // API调用失败，回退到模拟服务
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.getGroupMembers(groupId);
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.getGroupMembers(groupId);
    }
  }
  
  // 邀请用户加入群组
  Future<void> inviteMembers(String groupId, List<int> userIds) async {
    print('GroupService.inviteMembers: 群组ID=$groupId, 用户IDs=$userIds, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务邀请成员');
      return _mockService.inviteMembers(groupId, userIds);
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API邀请成员，令牌长度: ${token.length}');
      
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
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.inviteMembers(groupId, userIds);
      } else {
        print('API邀请成员成功');
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.inviteMembers(groupId, userIds);
    }
  }
  
  // 移除群组成员
  Future<void> removeMember(String groupId, int userId) async {
    print('GroupService.removeMember: 群组ID=$groupId, 用户ID=$userId, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务移除成员');
      return _mockService.removeMember(groupId, userId);
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API移除成员，令牌长度: ${token.length}');
      
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/members/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.removeMember(groupId, userId);
      } else {
        print('API移除成员成功');
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.removeMember(groupId, userId);
    }
  }
  
  // 退出群组
  Future<void> leaveGroup(String groupId) async {
    print('GroupService.leaveGroup: 群组ID=$groupId, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务退出群组');
      return _mockService.leaveGroup(groupId);
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API退出群组，令牌长度: ${token.length}');
      
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/groups/$groupId/leave'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.leaveGroup(groupId);
      } else {
        print('API退出群组成功');
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.leaveGroup(groupId);
    }
  }
  
  // 解散群组
  Future<void> disbandGroup(String groupId) async {
    print('GroupService.disbandGroup: 群组ID=$groupId, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务解散群组');
      return _mockService.disbandGroup(groupId);
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API解散群组，令牌长度: ${token.length}');
      
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/groups/$groupId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.disbandGroup(groupId);
      } else {
        print('API解散群组成功');
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.disbandGroup(groupId);
    }
  }
  
  // 设置/取消管理员
  Future<void> setAdmin(String groupId, int userId, bool isAdmin) async {
    print('GroupService.setAdmin: 群组ID=$groupId, 用户ID=$userId, 是否为管理员=$isAdmin, useMock=$useMock');
    
    // 如果使用模拟服务
    if (useMock) {
      print('使用模拟服务设置管理员');
      return _mockService.setAdmin(groupId, userId, isAdmin);
    }
    
    // 使用真实API
    try {
      final token = await tokenManager.getAuthToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      print('使用API设置管理员，令牌长度: ${token.length}');
      
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
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('API调用失败，状态码: ${response.statusCode}，回退到模拟服务');
        print('响应内容: ${response.body}');
        return _mockService.setAdmin(groupId, userId, isAdmin);
      } else {
        print('API设置管理员成功');
      }
    } catch (e) {
      // 发生异常，回退到模拟服务
      print('API调用异常: $e，回退到模拟服务');
      return _mockService.setAdmin(groupId, userId, isAdmin);
    }
  }
  
  // 上传群组头像
  Future<String> _uploadGroupAvatar(String token, File imageFile) async {
    print('GroupService._uploadGroupAvatar: 文件路径=${imageFile.path}');
    
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
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('API响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarUrl = data['avatar_url'];
        print('上传头像成功: $avatarUrl');
        return avatarUrl;
      } else {
        print('上传头像失败: ${response.body}');
        throw Exception('上传群组头像失败: ${response.body}');
      }
    } catch (e) {
      print('上传头像异常: $e');
      throw Exception('上传群组头像失败: $e');
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