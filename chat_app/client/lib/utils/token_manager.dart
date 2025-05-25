import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TokenManager {
  // SharedPreferences 键
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  
  // 存储令牌
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    // 确保令牌不包含多余的Bearer前缀
    final cleanToken = token.startsWith('Bearer ') ? token.substring(7) : token;
    
    print('保存令牌: $cleanToken');
    await prefs.setString(tokenKey, cleanToken);
  }
  
  // 获取令牌
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    
    if (token != null) {
      print('获取到令牌: $token');
    } else {
      print('未找到令牌');
    }
    
    return token;
  }
  
  // 获取带Bearer前缀的令牌，用于API请求
  Future<String?> getAuthToken() async {
    final token = await getToken();
    if (token == null) return null;
    
    return 'Bearer $token';
  }
  
  // 删除令牌（注销）
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    print('令牌已删除');
  }
  
  // 检查是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    final isLoggedIn = token != null && token.isNotEmpty;
    print('登录状态: $isLoggedIn');
    return isLoggedIn;
  }
  
  // 存储用户ID
  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    print('保存用户ID: $userId');
    await prefs.setInt(userIdKey, userId);
  }
  
  // 获取用户ID
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(userIdKey);
    
    if (userId != null) {
      print('获取到用户ID: $userId');
    } else {
      print('未找到用户ID');
    }
    
    return userId;
  }
  
  // 删除用户ID
  Future<void> removeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userIdKey);
    print('用户ID已删除');
  }
  
  // 完全注销
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userIdKey);
    print('用户已完全注销');
  }
} 