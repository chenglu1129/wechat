import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import '../models/chat.dart';
import '../utils/api_constants.dart';

class ChatProvider extends ChangeNotifier {
  final List<Chat> _chats = [];
  final Map<String, List<Message>> _messages = {};
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _currentChatId;
  bool _isLoading = false;
  String? _error;
  
  List<Chat> get chats => [..._chats];
  List<Message> get currentMessages => _currentChatId != null ? [...?_messages[_currentChatId]] : [];
  String? get currentChatId => _currentChatId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // 连接WebSocket
  void connectWebSocket(String token, String userId) {
    // 关闭现有连接
    disconnectWebSocket();
    
    // 创建新连接
    final wsUrl = '${ApiConstants.wsUrl}?token=$token&user_id=$userId';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    // 监听消息
    _subscription = _channel?.stream.listen(
      (data) {
        final message = Message.fromJson(json.decode(data));
        _handleIncomingMessage(message);
      },
      onError: (error) {
        _setError('WebSocket连接错误: $error');
      },
      onDone: () {
        // 连接关闭，可以尝试重新连接
      },
    );
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
    
    try {
      // 解析聊天ID
      final parts = chatId.split('_');
      final chatType = parts[0];
      final id = parts[1];
      
      String url;
      if (chatType == 'private') {
        url = '${ApiConstants.baseUrl}/messages?type=private&receiver_id=$id&limit=$limit&offset=$offset';
      } else {
        url = '${ApiConstants.baseUrl}/messages?type=group&group_id=$id&limit=$limit&offset=$offset';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
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
      } else {
        _setError('加载消息失败');
      }
    } catch (e) {
      _setError('网络错误，请稍后再试');
    } finally {
      _setLoading(false);
    }
  }
  
  // 发送消息
  Future<bool> sendMessage(String token, String content, {String? receiverId, String? groupId}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'receiver_id': receiverId,
          'group_id': groupId,
          'type': 'text',
          'content': content,
        }),
      );
      
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
        _setError('发送消息失败');
        return false;
      }
    } catch (e) {
      _setError('网络错误，请稍后再试');
      return false;
    }
  }
  
  // 设置当前聊天
  void setCurrentChat(String chatId) {
    _currentChatId = chatId;
    
    // 将未读消息数设为0
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex >= 0) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
    }
    
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
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 