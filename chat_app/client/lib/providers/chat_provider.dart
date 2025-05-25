import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import '../models/chat.dart';
import '../utils/api_constants.dart';

// 定义WebSocket消息类型
enum WebSocketMessageType {
  message,
  userStatus,
  typing,
  readReceipt,
  system,
}

class ChatProvider extends ChangeNotifier {
  final List<Chat> _chats = [];
  final Map<String, List<Message>> _messages = {};
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _currentChatId;
  int? _currentChatUserId; // 当前正在聊天的用户ID
  bool _isLoading = false;
  String? _error;
  
  // 联系人在线状态变化回调
  Function(int userId, bool isOnline)? onUserStatusChanged;
  
  // 消息接收回调，用于通知服务
  Function(Message message)? onMessageReceived;
  
  List<Chat> get chats => [..._chats];
  List<Message> get currentMessages => _currentChatId != null ? [...?_messages[_currentChatId]] : [];
  String? get currentChatId => _currentChatId;
  int? get currentChatUserId => _currentChatUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // 连接WebSocket
  void connectWebSocket(String token, String userId) {
    // 关闭现有连接
    disconnectWebSocket();
    
    // 确保token不包含Bearer前缀，因为WebSocket连接不需要
    final cleanToken = token.startsWith('Bearer ') ? token.substring(7) : token;
    
    // 创建新连接
    final wsUrl = '${ApiConstants.wsUrl}?token=$cleanToken&user_id=$userId';
    print('连接WebSocket: $wsUrl');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // 监听消息
      _subscription = _channel?.stream.listen(
        (data) {
          try {
            print('收到WebSocket消息: $data');
            final jsonData = json.decode(data);
            final messageType = _parseWebSocketMessageType(jsonData['type'] ?? 'message');
            
            switch (messageType) {
              case WebSocketMessageType.message:
                final message = Message.fromJson(jsonData);
                _handleIncomingMessage(message);
                // 触发消息接收回调，用于通知
                onMessageReceived?.call(message);
                break;
              case WebSocketMessageType.userStatus:
                _handleUserStatusChange(jsonData);
                break;
              case WebSocketMessageType.typing:
                _handleTypingStatus(jsonData);
                break;
              case WebSocketMessageType.readReceipt:
                _handleReadReceipt(jsonData);
                break;
              case WebSocketMessageType.system:
                _handleSystemMessage(jsonData);
                break;
            }
          } catch (e) {
            print('处理WebSocket消息错误: $e');
          }
        },
        onError: (error) {
          _setError('WebSocket连接错误: $error');
          print('WebSocket错误: $error');
        },
        onDone: () {
          print('WebSocket连接关闭');
          // 连接关闭，可以尝试重新连接
        },
      );
      
      print('WebSocket连接成功');
    } catch (e) {
      print('WebSocket连接失败: $e');
      _setError('WebSocket连接失败: $e');
    }
  }
  
  // 解析WebSocket消息类型
  WebSocketMessageType _parseWebSocketMessageType(String type) {
    switch (type) {
      case 'user_status':
        return WebSocketMessageType.userStatus;
      case 'typing':
        return WebSocketMessageType.typing;
      case 'read_receipt':
        return WebSocketMessageType.readReceipt;
      case 'system':
        return WebSocketMessageType.system;
      case 'message':
      default:
        return WebSocketMessageType.message;
    }
  }
  
  // 断开WebSocket连接
  void disconnectWebSocket() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
  }
  
  // 处理接收到的消息
  void _handleIncomingMessage(Message message) {
    // 确定聊天ID
    final chatId = message.isGroupMessage
        ? 'group_${message.groupId}'
        : 'private_${message.senderId}';
    
    // 添加消息到对应的聊天
    if (_messages.containsKey(chatId)) {
      _messages[chatId]!.add(message);
    } else {
      _messages[chatId] = [message];
    }
    
    // 更新聊天列表
    _updateChatList(chatId, message);
    
    notifyListeners();
  }
  
  // 处理用户状态变化
  void _handleUserStatusChange(Map<String, dynamic> data) {
    final userId = data['user_id'];
    final isOnline = data['is_online'] ?? false;
    
    if (userId != null) {
      // 通知联系人状态变化
      onUserStatusChanged?.call(int.parse(userId.toString()), isOnline);
      
      // 更新聊天列表中的用户状态
      for (int i = 0; i < _chats.length; i++) {
        final chat = _chats[i];
        if (chat.type == ChatType.private && chat.id == 'private_$userId') {
          _chats[i] = chat.copyWith(isOnline: isOnline);
          notifyListeners();
          break;
        }
      }
    }
  }
  
  // 处理正在输入状态
  void _handleTypingStatus(Map<String, dynamic> data) {
    // 实现正在输入状态的处理
  }
  
  // 处理已读回执
  void _handleReadReceipt(Map<String, dynamic> data) {
    // 实现已读回执的处理
  }
  
  // 处理系统消息
  void _handleSystemMessage(Map<String, dynamic> data) {
    // 实现系统消息的处理
  }
  
  // 更新聊天列表
  void _updateChatList(String chatId, Message message) {
    // 查找现有聊天
    final existingChatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    
    if (existingChatIndex >= 0) {
      // 更新现有聊天
      final chat = _chats[existingChatIndex];
      final updatedChat = chat.copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        unreadCount: _currentChatId == chatId ? 0 : chat.unreadCount + 1,
      );
      
      _chats[existingChatIndex] = updatedChat;
      
      // 将聊天移到列表顶部
      if (existingChatIndex > 0) {
        _chats.removeAt(existingChatIndex);
        _chats.insert(0, updatedChat);
      }
    } else {
      // 创建新聊天
      // 这里需要获取用户/群组信息
      // 实际应用中，应该通过API获取这些信息
    }
  }
  
  // 加载聊天列表
  Future<void> loadChats(String token) async {
    _setLoading(true);
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        _chats.clear();
        _chats.addAll(data.map((item) => Chat.fromJson(item)).toList());
      } else {
        _setError('加载聊天列表失败');
      }
    } catch (e) {
      _setError('网络错误，请稍后再试');
    } finally {
      _setLoading(false);
    }
  }
  
  // 加载消息历史
  Future<void> loadMessages(String token, String chatId, {int limit = 20, int offset = 0}) async {
    _setLoading(true);
    _currentChatId = chatId;
    
    // 解析聊天ID，设置当前聊天用户ID
    final parts = chatId.split('_');
    if (parts.length == 2 && parts[0] == 'private') {
      _currentChatUserId = int.tryParse(parts[1]);
    }
    
    try {
      // 确保token包含Bearer前缀
      final authToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
      print('加载消息使用的令牌: $authToken');
      
      // 验证聊天ID格式
      if (parts.length != 2) {
        _setError('无效的聊天ID');
        return;
      }
      
      final chatType = parts[0];
      final chatTargetId = parts[1];
      
      // 构建查询参数
      final queryParams = {
        'type': chatType == 'private' ? 'private' : 'group',
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      // 根据聊天类型添加相应的ID参数
      if (chatType == 'private') {
        queryParams['receiver_id'] = chatTargetId;
      } else {
        queryParams['group_id'] = chatTargetId;
      }
      
      // 打印请求信息
      final requestUrl = Uri.parse('${ApiConstants.baseUrl}/messages').replace(queryParameters: queryParams);
      print('加载消息请求URL: $requestUrl');
      print('加载消息请求头: Authorization: $authToken');
      
      // 发送请求
      final response = await http.get(
        requestUrl,
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
      );
      
      // 打印响应信息用于调试
      print('加载消息响应状态码: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('加载消息响应体: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final messages = data.map((item) => Message.fromJson(item)).toList();
        
        if (offset == 0 || !_messages.containsKey(chatId)) {
          _messages[chatId] = messages;
        } else {
          _messages[chatId]!.addAll(messages);
        }
        
        // 更新未读消息数
        final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
        if (chatIndex >= 0) {
          _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
        }
        
        // 清除可能存在的错误状态
        _clearError();
      } else if (response.statusCode == 404 && offset == 0) {
        // 如果是首次加载且没有找到消息，这是正常情况（新对话）
        if (!_messages.containsKey(chatId)) {
          _messages[chatId] = []; // 初始化为空列表
        }
        _clearError(); // 确保清除错误状态
      } else {
        _setError('加载消息失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _setError('网络错误，请稍后再试: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 发送消息
  Future<bool> sendMessage(String token, String content, {String? receiverId, String? groupId}) async {
    try {
      // 确保token包含Bearer前缀
      final authToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
      print('发送消息使用的令牌: $authToken');
      
      // 准备请求体
      final requestBody = {
        'receiver_id': receiverId,
        'group_id': groupId,
        'type': 'text',
        'content': content,
      };
      print('发送消息请求体: ${json.encode(requestBody)}');
      
      // 发送请求
      final requestUrl = Uri.parse('${ApiConstants.baseUrl}/messages');
      print('发送消息请求URL: $requestUrl');
      print('发送消息请求头: Authorization: $authToken');
      
      final response = await http.post(
        requestUrl,
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      // 打印响应信息用于调试
      print('发送消息响应状态码: ${response.statusCode}');
      print('发送消息响应体: ${response.body}');
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final message = Message.fromJson(data);
        
        // 确定聊天ID
        final chatId = message.isGroupMessage
            ? 'group_${message.groupId}'
            : 'private_${message.receiverId}';
        
        // 添加消息到列表
        if (_messages.containsKey(chatId)) {
          _messages[chatId]!.add(message);
        } else {
          _messages[chatId] = [message];
        }
        
        // 更新聊天列表
        _updateChatList(chatId, message);
        
        notifyListeners();
        return true;
      } else {
        _setError('发送消息失败: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _setError('网络错误，请稍后再试: $e');
      return false;
    }
  }
  
  // 发送媒体消息
  Future<bool> sendMediaMessage(
    String token,
    MessageType type,
    String mediaUrl,
    String content,
    {String? receiverId, String? groupId, Map<String, dynamic>? metadata}
  ) async {
    try {
      // 确保token包含Bearer前缀
      final authToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
      
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/messages'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'receiver_id': receiverId,
          'group_id': groupId,
          'type': type.toString().split('.').last,
          'content': content,
          'media_url': mediaUrl,
          'metadata': metadata,
        }),
      );
      
      // 打印响应信息用于调试
      print('发送媒体消息响应状态码: ${response.statusCode}');
      print('发送媒体消息响应体: ${response.body}');
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final message = Message.fromJson(data);
        
        // 确定聊天ID
        final chatId = message.isGroupMessage
            ? 'group_${message.groupId}'
            : 'private_${message.receiverId}';
        
        // 添加消息到列表
        if (_messages.containsKey(chatId)) {
          _messages[chatId]!.add(message);
        } else {
          _messages[chatId] = [message];
        }
        
        // 更新聊天列表
        _updateChatList(chatId, message);
        
        notifyListeners();
        return true;
      } else {
        _setError('发送媒体消息失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _setError('网络错误，请稍后再试: $e');
      return false;
    }
  }
  
  // 设置当前聊天
  void setCurrentChat(String chatId) {
    _currentChatId = chatId;
    
    // 更新当前聊天用户ID
    final parts = chatId.split('_');
    if (parts.length == 2 && parts[0] == 'private') {
      _currentChatUserId = int.tryParse(parts[1]);
    } else {
      _currentChatUserId = null;
    }
    
    // 将未读消息数设为0
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex >= 0) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
    }
    
    notifyListeners();
  }
  
  // 清除当前聊天
  void clearCurrentChat() {
    _currentChatId = null;
    _currentChatUserId = null;
    notifyListeners();
  }
  
  // 发送"正在输入"状态
  void sendTypingStatus(String token, String receiverId) {
    if (_channel != null) {
      _channel!.sink.add(json.encode({
        'type': 'typing',
        'receiver_id': receiverId,
      }));
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