import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/contact.dart';
import '../models/user.dart';
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';

class ContactService {
  final TokenManager tokenManager;
  
  ContactService({required this.tokenManager});
  
  // 获取所有联系人
  Future<ContactList> getContacts() async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/contacts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        try {
          // 尝试解析JSON响应
          final dynamic decodedBody = jsonDecode(response.body);
          
          // 检查解析的响应是否是列表
          if (decodedBody is List) {
            return ContactList.fromJson(decodedBody);
          } else if (decodedBody is Map && decodedBody.containsKey('contacts')) {
            // 如果响应是一个包含contacts键的对象
            if (decodedBody['contacts'] is List) {
              return ContactList.fromJson(decodedBody['contacts']);
            }
          }
          
          // 如果响应格式不符合预期，返回空列表
          return ContactList(contacts: []);
        } catch (e) {
          // JSON解析错误，返回空列表
          return ContactList(contacts: []);
        }
      } else if (response.statusCode == 404) {
        // 如果是404，可能表示用户还没有联系人，返回空列表
        return ContactList(contacts: []);
      } else {
        throw Exception('获取联系人失败: ${response.body}');
      }
    } catch (e) {
      // 网络错误或其他异常
      throw Exception('获取联系人失败: $e');
    }
  }
  
  // 添加联系人
  Future<void> addContact(int contactId) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/contacts/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'contact_id': contactId,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('添加联系人失败: ${response.body}');
    }
  }
  
  // 删除联系人
  Future<void> removeContact(int contactId) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/contacts/remove?contact_id=$contactId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('删除联系人失败: ${response.body}');
    }
  }
  
  // 搜索用户
  Future<SearchResult> searchUsers(String query, {int offset = 0, int limit = 20}) async {
    final token = await tokenManager.getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/users/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
          'offset': offset,
          'limit': limit,
        }),
      );
      
      if (response.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(response.body);
        
        // 检查响应格式
        if (decodedBody is Map<String, dynamic>) {
          return SearchResult.fromJson(decodedBody);
        } else if (decodedBody is List) {
          // 如果服务器直接返回用户列表
          return SearchResult(
            users: decodedBody.map((json) => User.fromJson(json)).toList(),
            total: decodedBody.length,
            hasMore: false,
          );
        } else {
          // 未知格式
          return SearchResult(users: [], total: 0, hasMore: false);
        }
      } else {
        throw Exception('搜索用户失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('搜索用户失败: $e');
    }
  }
} 