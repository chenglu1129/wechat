import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 有条件地导入dart:io
import 'dart:io' if (dart.library.html) '../utils/platform_web.dart' as platform;

import '../models/user.dart';
import '../utils/app_routes.dart';
import 'notification_api_service.dart';
import '../utils/token_manager.dart';

class NotificationService {
  // 单例模式
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 本地通知插件实例
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // 通知API服务
  late final NotificationApiService _apiService;
  
  // 通知设置
  bool _isNotificationsEnabled = true;
  bool _isSoundEnabled = true;
  bool _isVibrationEnabled = true;
  
  // 初始化完成标志
  bool _isInitialized = false;
  
  // 全局导航键，用于在通知被点击时进行路由导航
  GlobalKey<NavigatorState>? _navigatorKey;
  
  // Getters
  bool get isNotificationsEnabled => _isNotificationsEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isVibrationEnabled => _isVibrationEnabled;
  
  // 设置导航键
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }
  
  // 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 初始化通知API服务
    _apiService = NotificationApiService(tokenManager: TokenManager());
    
    // 加载通知设置
    await _loadSettings();
    
    // 初始化本地通知
    await _initializeLocalNotifications();
    
    _isInitialized = true;
  }
  
  // 加载通知设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _isNotificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _isSoundEnabled = prefs.getBool('notifications_sound') ?? true;
    _isVibrationEnabled = prefs.getBool('notifications_vibration') ?? true;
  }
  
  // 保存通知设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('notifications_enabled', _isNotificationsEnabled);
    await prefs.setBool('notifications_sound', _isSoundEnabled);
    await prefs.setBool('notifications_vibration', _isVibrationEnabled);
  }
  
  // 启用/禁用通知
  Future<void> setNotificationsEnabled(bool value) async {
    _isNotificationsEnabled = value;
    await _saveSettings();
  }
  
  // 启用/禁用通知声音
  Future<void> setSoundEnabled(bool value) async {
    _isSoundEnabled = value;
    await _saveSettings();
  }
  
  // 启用/禁用通知振动
  Future<void> setVibrationEnabled(bool value) async {
    _isVibrationEnabled = value;
    await _saveSettings();
  }
  
  // 初始化本地通知
  Future<void> _initializeLocalNotifications() async {
    // 在Web平台上，不初始化本地通知
    if (kIsWeb) {
      print('Web平台不支持本地通知');
      return;
    }
    
    // 安卓通知设置
    const androidSettings = AndroidInitializationSettings('app_icon');
    
    // iOS通知设置
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );
    
    // 初始化设置
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // 初始化本地通知插件
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
    
    // 请求通知权限
    if (!kIsWeb) {
      await _requestPermissions();
    }
  }
  
  // 请求通知权限
  Future<void> _requestPermissions() async {
    if (kIsWeb) return; // Web平台不支持
    
    if (platform.Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (platform.Platform.isAndroid) {
      // 在新版本中，Android权限请求已经改变
      if (platform.Platform.isAndroid) {
        try {
          // 尝试使用新API
          await _localNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
        } catch (e) {
          print('Android通知权限请求失败: $e');
          // 旧版本可能没有此方法，忽略错误
        }
      }
    }
  }
  
  // 处理本地通知点击
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    print('用户点击了本地通知: ${response.payload}');
    if (response.payload != null) {
      _navigateToPageBasedOnPayload(response.payload!);
    }
  }
  
  // 处理iOS本地通知（已弃用，但仍需要实现）
  void _onDidReceiveLocalNotification(
    int id, 
    String? title, 
    String? body, 
    String? payload,
  ) {
    print('iOS本地通知: $title');
    if (payload != null) {
      _navigateToPageBasedOnPayload(payload);
    }
  }
  
  // 根据负载导航到相应页面
  void _navigateToPageBasedOnPayload(String payload) {
    if (_navigatorKey?.currentState == null) return;
    
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      // 根据通知类型导航到不同页面
      final notificationType = data['type'] as String?;
      
      switch (notificationType) {
        case 'chat_message':
          final senderId = int.tryParse(data['sender_id'] ?? '');
          final senderName = data['sender_name'] as String?;
          
          if (senderId != null && senderName != null) {
            // 创建一个简单的User对象以便导航
            final user = User(
              id: senderId,
              username: senderName,
              email: '',
              avatarUrl: data['sender_avatar'],
              isOnline: true,
            );
            
            _navigatorKey!.currentState!.pushNamed(
              AppRoutes.chat,
              arguments: {'user': user},
            );
          }
          break;
          
        case 'friend_request':
          _navigatorKey!.currentState!.pushNamed(AppRoutes.friendRequests);
          break;
          
        case 'new_contact':
          _navigatorKey!.currentState!.pushNamed(AppRoutes.contacts);
          break;
          
        default:
          // 默认打开主页
          _navigatorKey!.currentState!.pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
      }
    } catch (e) {
      print('解析通知负载失败: $e');
    }
  }
  
  // 显示本地通知
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isNotificationsEnabled || kIsWeb) return;
    
    // 设置Android通知详情
    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      '聊天消息',
      channelDescription: '接收来自联系人的聊天消息',
      importance: Importance.high,
      priority: Priority.high,
      playSound: _isSoundEnabled,
      enableVibration: _isVibrationEnabled,
      icon: 'app_icon',
    );
    
    // 设置iOS通知详情
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _isSoundEnabled,
    );
    
    // 通知详情
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // 显示通知
    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }
  
  // 显示聊天消息通知
  Future<void> showChatMessageNotification({
    required int senderId,
    required String senderName,
    String? senderAvatar,
    required String message,
  }) async {
    await _showLocalNotification(
      id: senderId.hashCode,
      title: senderName,
      body: message,
      payload: jsonEncode({
        'type': 'chat_message',
        'sender_id': senderId.toString(),
        'sender_name': senderName,
        'sender_avatar': senderAvatar,
      }),
    );
  }
  
  // 获取FCM令牌 - 在Web平台返回null
  Future<String?> getFCMToken() async {
    if (kIsWeb) return null;
    
    // 这是一个简化的实现，假设在本地存储中获取
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }
  
  // 向服务器发送FCM令牌 - 简化实现
  Future<bool> sendFCMTokenToServer(String userId, String token) async {
    try {
      // 由于我们移除了Firebase，这里只是模拟成功
      return true;
    } catch (e) {
      print('发送FCM令牌到服务器失败: $e');
      return false;
    }
  }
  
  // 取消所有通知
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return; // Web平台上直接返回，不调用cancelAll
    await _localNotifications.cancelAll();
  }
  
  // 取消特定通知
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return; // Web平台上直接返回，不调用cancel
    await _localNotifications.cancel(id);
  }
} 