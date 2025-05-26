import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';

class GroupService {
  final TokenManager tokenManager;
  
  GroupService({required this.tokenManager});
  
  // 创建群组
  Future<Group> createGroup({
    required String name,
    required List<int> memberIds,
    File? avatarFile,
  }) async {
    print('GroupService.createGroup: 名称=$name, 成员数=${memberIds.length}');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('创建群组失败: ${response.statusCode}');
    }
  }
  
  // 获取群组信息
  Future<Group> getGroupInfo(String groupId) async {
    print('GroupService.getGroupInfo: ID=$groupId');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('获取群组信息失败: ${response.statusCode}');
    }
  }
  
  // 获取用户加入的群组列表
  Future<List<Group>> getUserGroups() async {
    print('GroupService.getUserGroups');
    
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
      print('API返回原始群组数据: $data');
      
      final groups = data.map((item) {
        print('解析群组项: $item');
        final group = Group.fromJson(item);
        print('解析后的群组: ID=${group.id}, 名称=${group.name}, 成员数=${group.memberCount}');
        return group;
      }).toList();
      
      print('API获取群组列表成功: ${groups.length}个群组');
      return groups;
    } else {
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('获取群组列表失败: ${response.statusCode}');
    }
  }
  
  // 更新群组信息
  Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? announcement,
    File? avatarFile,
  }) async {
    print('GroupService.updateGroup: ID=$groupId, 名称=$name, 公告=$announcement');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('更新群组失败: ${response.statusCode}');
    }
  }
  
  // 获取群组成员列表
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    print('GroupService.getGroupMembers: ID=$groupId');
    
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
      print('API返回原始群组成员数据: $data');
      
      final members = data.map((item) {
        print('解析群组成员项: $item');
        final member = GroupMember.fromJson(item);
        print('解析后的群组成员: 用户ID=${member.user.id}, 用户名=${member.user.username}, 角色=${member.role}');
        return member;
      }).toList();
      
      print('API获取群组成员成功: ${members.length}个成员');
      return members;
    } else {
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('获取群组成员失败: ${response.statusCode}');
    }
  }
  
  // 邀请用户加入群组
  Future<void> inviteMembers(String groupId, List<int> userIds) async {
    print('GroupService.inviteMembers: 群组ID=$groupId, 用户IDs=$userIds');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('邀请成员失败: ${response.statusCode}');
    }
    
    print('API邀请成员成功');
  }
  
  // 移除群组成员
  Future<void> removeMember(String groupId, int userId) async {
    print('GroupService.removeMember: 群组ID=$groupId, 用户ID=$userId');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('移除成员失败: ${response.statusCode}');
    }
    
    print('API移除成员成功');
  }
  
  // 退出群组
  Future<void> leaveGroup(String groupId) async {
    print('GroupService.leaveGroup: 群组ID=$groupId');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('退出群组失败: ${response.statusCode}');
    }
    
    print('API退出群组成功');
  }
  
  // 解散群组
  Future<void> disbandGroup(String groupId) async {
    print('GroupService.disbandGroup: 群组ID=$groupId');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('解散群组失败: ${response.statusCode}');
    }
    
    print('API解散群组成功');
  }
  
  // 设置/取消管理员
  Future<void> setAdmin(String groupId, int userId, bool isAdmin) async {
    print('GroupService.setAdmin: 群组ID=$groupId, 用户ID=$userId, 是否为管理员=$isAdmin');
    
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
      print('API调用失败，状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');
      throw Exception('设置管理员失败: ${response.statusCode}');
    }
    
    print('API设置管理员成功');
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