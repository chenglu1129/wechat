import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/friend_request.dart';
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';

class FriendRequestService {
  final TokenManager tokenManager;
  
  FriendRequestService({required this.tokenManager});
  
  // 获取待处理的好友请求
  Future<List<FriendRequest>> getPendingRequests() async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/friend-requests/pending'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        try {
          // 尝试解析JSON响应
          final List<dynamic> decodedBody = jsonDecode(response.body);
          return decodedBody.map((json) => FriendRequest.fromJson(json)).toList();
        } catch (e) {
          // JSON解析错误，返回空列表
          print('解析好友请求失败: $e');
          return [];
        }
      } else if (response.statusCode == 404) {
        // 如果是404，可能表示用户还没有好友请求，返回空列表
        return [];
      } else {
        throw Exception('获取好友请求失败: ${response.body}');
      }
    } catch (e) {
      // 网络错误或其他异常
      throw Exception('获取好友请求失败: $e');
    }
  }
  
  // 获取所有好友请求历史
  Future<List<FriendRequest>> getAllRequests() async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/friend-requests/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        try {
          final List<dynamic> decodedBody = jsonDecode(response.body);
          return decodedBody.map((json) => FriendRequest.fromJson(json)).toList();
        } catch (e) {
          print('解析好友请求历史失败: $e');
          return [];
        }
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('获取好友请求历史失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('获取好友请求历史失败: $e');
    }
  }
  
  // 发送好友请求
  Future<FriendRequest> sendRequest(int receiverId, String message) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/friend-requests/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'receiver_id': receiverId,
          'message': message,
        }),
      );
      
      if (response.statusCode == 201) {
        return FriendRequest.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('发送好友请求失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('发送好友请求失败: $e');
    }
  }
  
  // 接受好友请求
  Future<void> acceptRequest(int requestId) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/friend-requests/$requestId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('接受好友请求失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('接受好友请求失败: $e');
    }
  }
  
  // 拒绝好友请求
  Future<void> rejectRequest(int requestId) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/friend-requests/$requestId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('拒绝好友请求失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('拒绝好友请求失败: $e');
    }
  }
  
  // 取消发送的好友请求
  Future<void> cancelRequest(int requestId) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/friend-requests/$requestId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('取消好友请求失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('取消好友请求失败: $e');
    }
  }
} 