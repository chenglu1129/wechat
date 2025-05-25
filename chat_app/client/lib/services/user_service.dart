import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/user.dart';
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';

class UserService {
  final TokenManager tokenManager;
  
  UserService({required this.tokenManager});
  
  // 获取用户资料
  Future<User> getUserProfile(int userId) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('获取用户资料失败: ${response.body}');
    }
  }
  
  // 获取当前用户资料
  Future<User> getCurrentUserProfile() async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('获取当前用户资料失败: ${response.body}');
    }
  }
  
  // 更新用户资料
  Future<User> updateUserProfile({
    required String username, 
    required String email,
  }) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'email': email,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('更新用户资料失败: ${response.body}');
    }
  }
  
  // 上传头像
  Future<String> uploadAvatar(File imageFile) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    // 创建多部分请求
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConstants.baseUrl}/users/avatar'));
    
    // 添加授权头
    request.headers['Authorization'] = 'Bearer $token';
    
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
      throw Exception('上传头像失败: ${response.body}');
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
  
  // 修改密码
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/users/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    
    if (response.statusCode == 200) {
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? '修改密码失败');
    }
  }
} 