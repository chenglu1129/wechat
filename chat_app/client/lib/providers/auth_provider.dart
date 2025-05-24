import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../utils/api_constants.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;
  
  AuthProvider() {
    _loadUserData();
  }
  
  // 从本地存储加载用户数据
  Future<void> _loadUserData() async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userData');
      final token = prefs.getString('token');
      
      if (userData != null && token != null) {
        _user = User.fromJson(json.decode(userData));
        _token = token;
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', json.encode(_user!.toJson()));
      await prefs.setString('token', _token!);
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
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username_or_email': usernameOrEmail,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _user = User.fromJson(data['user']);
        _token = data['token'];
        await _saveUserData();
        notifyListeners();
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? '登录失败');
        return false;
      }
    } catch (e) {
      _setError('网络错误，请稍后再试');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 登出
  Future<void> logout() async {
    _user = null;
    _token = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('token');
    
    notifyListeners();
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