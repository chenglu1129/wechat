import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/api_constants.dart';
import '../utils/token_manager.dart';

/// 通知API服务
/// 用于与服务器通知API通信，发送FCM令牌
class NotificationApiService {
  final TokenManager _tokenManager;
  
  NotificationApiService({required TokenManager tokenManager}) 
      : _tokenManager = tokenManager;
  
  /// 保存FCM令牌到服务器
  Future<bool> saveFCMToken(String userId, String token) async {
    final authToken = await _tokenManager.getToken();
    if (authToken == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notifications/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': token,
        }),
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? '保存FCM令牌失败');
      }
    } catch (e) {
      throw Exception('网络错误，请稍后再试: $e');
    }
  }
  
  /// 删除FCM令牌
  Future<bool> deleteFCMToken() async {
    final authToken = await _tokenManager.getToken();
    if (authToken == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/notifications/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? '删除FCM令牌失败');
      }
    } catch (e) {
      throw Exception('网络错误，请稍后再试: $e');
    }
  }
  
  /// 发送测试通知
  Future<bool> sendTestNotification(int userId) async {
    final authToken = await _tokenManager.getToken();
    if (authToken == null) {
      throw Exception('未登录');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notifications/test/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? '发送测试通知失败');
      }
    } catch (e) {
      throw Exception('网络错误，请稍后再试: $e');
    }
  }
} 