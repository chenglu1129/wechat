import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  final TokenManager _tokenManager;
  late final UserService _userService;
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;
  
  AuthProvider({required TokenManager tokenManager}) : _tokenManager = tokenManager {
    _userService = UserService(tokenManager: tokenManager);
    _loadUserData();
  }
  
  // 从本地存储加载用户数据
  Future<void> _loadUserData() async {
    _setLoading(true);
    
    try {
      final token = await _tokenManager.getToken();
      final userId = await _tokenManager.getUserId();
      
      if (token != null && userId != null) {
        _token = token;
        // 尝试从API获取用户信息
        try {
          _user = await _userService.getCurrentUserProfile();
        } catch (e) {
          // 如果获取失败，暂时不处理，后续可以在需要时重新获取
          print('获取用户信息失败: $e');
        }
      }
    } catch (e) {
      _setError('加载用户数据失败');
    } finally {
      _setLoading(false);
    }
  }
  
  // 保存用户数据到本地存储
  Future<void> _saveUserData() async {
    if (_user == null || _token == null) return;
    
    try {
      await _tokenManager.saveToken(_token!);
      await _tokenManager.saveUserId(_user!.id);
    } catch (e) {
      _setError('保存用户数据失败');
    }
  }
  
  // 注册
  Future<bool> register(String username, String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _user = User.fromJson(data['user']);
        _token = data['token'];
        await _saveUserData();
        notifyListeners();
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? '注册失败');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 登录
  Future<bool> login(String usernameOrEmail, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      // 打印请求URL用于调试
      final url = '${ApiConstants.baseUrl}/auth/login';
      print('登录请求URL: $url');
      
      // 准备请求体
      final requestBody = {
        'username_or_email': usernameOrEmail,
        'password': password,
      };
      print('登录请求体: $requestBody');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );
      
      // 打印响应信息用于调试
      print('登录响应状态码: ${response.statusCode}');
      print('登录响应体: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          // 尝试解析响应为JSON
          final data = json.decode(response.body);
          
          // 检查响应格式
          if (data is Map<String, dynamic> && data.containsKey('token')) {
            // 保存令牌
            _token = data['token'];
            await _tokenManager.saveToken(_token!);
            
            // 如果响应包含用户信息，直接使用
            if (data.containsKey('user')) {
              _user = User.fromJson(data['user']);
              await _tokenManager.saveUserId(_user!.id);
              notifyListeners();
              return true;
            } else {
              // 否则尝试获取用户信息
              try {
                _user = await _userService.getCurrentUserProfile();
                if (_user != null) {
                  await _tokenManager.saveUserId(_user!.id);
                  notifyListeners();
                  return true;
                } else {
                  _setError('获取用户信息失败');
                  return false;
                }
              } catch (e) {
                _setError('获取用户信息失败: $e');
                print('获取用户信息失败: $e');
                return false;
              }
            }
          } else {
            // 不是预期的响应格式
            _setError('登录成功，但服务器返回的数据格式不正确');
            print('未知的响应格式: $data');
            return false;
          }
        } catch (e) {
          _setError('解析响应失败: $e');
          print('JSON解析失败: $e, 响应体: ${response.body}');
          return false;
        }
      } else {
        // 尝试解析错误消息
        try {
          final data = json.decode(response.body);
          _setError(data['message'] ?? '登录失败: ${response.statusCode}');
        } catch (e) {
          _setError('登录失败: ${response.statusCode}');
          print('解析错误响应失败: $e, 响应体: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      _setError('网络错误，请稍后再试: $e');
      print('登录错误详情: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 登出
  Future<void> logout() async {
    _user = null;
    _token = null;
    
    await _tokenManager.logout();
    
    notifyListeners();
  }
  
  // 更新用户资料
  Future<bool> updateProfile({
    required String username,
    required String email,
  }) async {
    if (!isAuthenticated) {
      _setError('未登录');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      final updatedUser = await _userService.updateUserProfile(
        username: username,
        email: email,
      );
      
      // 更新本地用户数据
      _user = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('更新用户资料失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 上传头像
  Future<bool> uploadAvatar(File imageFile) async {
    if (!isAuthenticated || _user == null) {
      _setError('未登录');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      final avatarUrl = await _userService.uploadAvatar(imageFile);
      
      // 更新本地用户数据
      _user = _user!.copyWith(avatarUrl: avatarUrl);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('上传头像失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 刷新用户资料
  Future<bool> refreshUserProfile() async {
    if (!isAuthenticated) {
      _setError('未登录');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      _user = await _userService.getCurrentUserProfile();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('刷新用户资料失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 修改密码
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!isAuthenticated) {
      _setError('未登录');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _userService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      
      return success;
    } catch (e) {
      _setError('修改密码失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 设置加载状态
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  // 设置错误信息
  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
  
  // 清除错误信息
  void _clearError() {
    _error = null;
    notifyListeners();
  }
} 