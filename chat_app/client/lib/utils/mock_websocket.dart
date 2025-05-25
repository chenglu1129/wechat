import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';

/// 模拟WebSocket服务，用于测试联系人在线状态更新
class MockWebSocketService {
  final BuildContext context;
  Timer? _statusUpdateTimer;
  final Random _random = Random();
  
  // 模拟的用户ID列表
  final List<int> _userIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  
  MockWebSocketService(this.context);
  
  /// 开始模拟WebSocket服务
  void startMockService() {
    // 取消现有定时器
    _statusUpdateTimer?.cancel();
    
    // 创建新的定时器，每15-30秒随机更新一个联系人的在线状态
    _statusUpdateTimer = Timer.periodic(
      Duration(seconds: _random.nextInt(15) + 15),
      (_) => _mockStatusUpdate(),
    );
  }
  
  /// 停止模拟服务
  void stopMockService() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
  }
  
  /// 模拟状态更新
  void _mockStatusUpdate() {
    // 随机选择一个用户
    final userId = _userIds[_random.nextInt(_userIds.length)];
    
    // 随机决定在线状态
    final isOnline = _random.nextBool();
    
    // 创建模拟消息
    final mockMessage = {
      'type': 'user_status',
      'user_id': userId,
      'is_online': isOnline,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // 获取ChatProvider
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 模拟接收WebSocket消息
    try {
      chatProvider.onUserStatusChanged?.call(userId, isOnline);
      
      // 打印模拟消息（仅用于调试）
      debugPrint('模拟WebSocket消息: ${json.encode(mockMessage)}');
    } catch (e) {
      debugPrint('处理模拟WebSocket消息时出错: $e');
    }
  }
  
  /// 模拟发送消息
  void mockSendMessage(String content, {required int senderId, required int receiverId}) {
    // 创建模拟消息
    final mockMessage = {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': senderId.toString(),
      'receiver_id': receiverId.toString(),
      'type': 'text',
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    };
    
    // 获取ChatProvider
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 延迟1-3秒后"接收"消息，模拟网络延迟
    Future.delayed(
      Duration(seconds: _random.nextInt(2) + 1),
      () {
        try {
          final message = mockMessage;
          // 处理模拟消息
          chatProvider.onUserStatusChanged?.call(senderId, true);
          
          // 打印模拟消息（仅用于调试）
          debugPrint('模拟消息: ${json.encode(message)}');
        } catch (e) {
          debugPrint('处理模拟消息时出错: $e');
        }
      },
    );
  }
} 