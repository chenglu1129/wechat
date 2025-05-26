import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // 确定聊天类型和ID
      final isGroup = message.isGroupMessage;
      final targetId = isGroup ? message.groupId : (message.senderId == message.receiverId ? message.receiverId : message.senderId);
      final name = message.senderName ?? (isGroup ? "群聊" : "联系人");
      
      // 创建新的聊天对象
      final newChat = Chat(
        id: chatId,
        name: name,
        avatarUrl: message.senderAvatar,
        type: isGroup ? ChatType.group : ChatType.private,
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        unreadCount: _currentChatId == chatId ? 0 : 1,
      );
      
      // 添加到列表顶部
      _chats.insert(0, newChat);
      
      // 打印调试信息
      print('创建新聊天: $chatId, 名称: $name');
    }
  }
  
  // 加载聊天列表
  Future<void> loadChats(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // 先从本地存储加载消息
      await _loadMessagesFromStorage();
      
      // 从消息构建聊天列表
      await _loadChatsFromMessages(token);
      
      // 尝试从API获取聊天列表
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/chats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final apiChats = data.map((item) => Chat.fromJson(item)).toList();
        
        // 合并API获取的聊天和本地构建的聊天
        _mergeChats(apiChats);
      }
    } catch (e) {
      print('加载聊天列表时发生错误: $e');
      // 如果API调用失败，我们仍然有本地构建的聊天列表
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 合并API获取的聊天和本地构建的聊天
  void _mergeChats(List<Chat> apiChats) {
    for (final apiChat in apiChats) {
      final existingIndex = _chats.indexWhere((chat) => chat.id == apiChat.id);
      if (existingIndex >= 0) {
        // 更新现有聊天的信息，但保留本地的未读计数和最后消息
        final existingChat = _chats[existingIndex];
        _chats[existingIndex] = apiChat.copyWith(
          lastMessage: existingChat.lastMessage ?? apiChat.lastMessage,
          lastMessageTime: existingChat.lastMessageTime ?? apiChat.lastMessageTime,
          unreadCount: existingChat.unreadCount,
        );
      } else {
        // 添加新聊天
        _chats.add(apiChat);
      }
    }
    
    // 按最后消息时间排序
    _chats.sort((a, b) {
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
  }
  
  // 备用方案：从消息历史构建聊天列表
  Future<void> _loadChatsFromMessages(String token) async {
    try {
      // 清空现有聊天列表
      _chats.clear();
      
      // 从本地存储加载联系人列表
      // 这里我们需要一个简单的方法来获取联系人列表
      // 由于我们没有直接访问联系人提供者，我们可以使用一个简单的方法
      
      // 如果有消息历史，从消息历史中构建聊天列表
      if (_messages.isNotEmpty) {
        print('从现有消息历史构建聊天列表...');
        
        for (final entry in _messages.entries) {
          final chatId = entry.key;
          final messages = entry.value;
          
          if (messages.isNotEmpty) {
            // 获取最新消息
            final latestMessage = messages.reduce(
              (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b
            );
            
            // 确定聊天类型和名称
            final isGroup = latestMessage.isGroupMessage;
            String name;
            String? avatarUrl;
            
            if (isGroup) {
              name = '群聊 ${latestMessage.groupId}';
              avatarUrl = null;
            } else {
              name = latestMessage.senderName ?? '联系人';
              avatarUrl = latestMessage.senderAvatar;
            }
            
            // 创建聊天对象
            final chat = Chat(
              id: chatId,
              name: name,
              avatarUrl: avatarUrl,
              type: isGroup ? ChatType.group : ChatType.private,
              lastMessage: latestMessage.content,
              lastMessageTime: latestMessage.timestamp,
              unreadCount: messages.where((m) => !m.read).length,
              isOnline: false, // 默认离线
            );
            
            // 添加到列表
            _chats.add(chat);
          }
        }
        
        // 按最后消息时间排序
        _chats.sort((a, b) {
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });
        
        print('从消息历史构建了${_chats.length}个聊天');
      } else {
        print('没有消息历史，尝试加载一些最近的消息...');
        // 如果没有消息历史，可以尝试加载一些最近的消息
        // 这里我们可以留空，等用户点击联系人时自动创建聊天
      }
    } catch (e) {
      print('从消息历史构建聊天列表时发生错误: $e');
      _setError('无法加载聊天列表: $e');
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
  Future<bool> sendMessage(
    String token,
    String content,
    [String? receiverId]
  ) async {
    try {
      // 确保token包含Bearer前缀
      final authToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
      print('发送消息使用的令牌: $authToken');
      
      // 验证参数
      final String actualReceiverId = receiverId ?? '';
      if (actualReceiverId.isEmpty) {
        print('错误: 发送消息时receiverId为空');
        _setError('发送消息失败: 接收者ID不能为空');
        return false;
      }
      
      // 准备请求体
      final requestBody = {
        'receiver_id': actualReceiverId,
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
        
        // 确定聊天ID - 修复这里的逻辑
        String chatId;
        if (message.isGroupMessage) {
          chatId = 'group_${message.groupId}';
        } else {
          // 对于私聊，聊天ID应该始终使用对方的ID
          // 如果当前用户是发送者，则使用接收者ID；如果当前用户是接收者，则使用发送者ID
          chatId = 'private_$actualReceiverId';
        }
        print('消息的聊天ID: $chatId');
        
        // 添加消息到列表
        if (_messages.containsKey(chatId)) {
          _messages[chatId]!.add(message);
          print('消息已添加到现有聊天');
        } else {
          _messages[chatId] = [message];
          print('为新聊天创建消息列表');
        }
        
        // 更新聊天列表
        _updateChatList(chatId, message);
        
        // 保存消息到本地存储
        _saveMessagesToStorage();
        
        notifyListeners();
        return true;
      } else {
        final errorMsg = '发送消息失败: ${response.statusCode} - ${response.body}';
        print(errorMsg);
        _setError(errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = '发送消息时发生错误: $e';
      print(errorMsg);
      _setError(errorMsg);
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
  
  // 添加聊天到列表
  void addChat(Chat chat) {
    // 检查是否已存在
    if (!_chats.any((existingChat) => existingChat.id == chat.id)) {
      _chats.insert(0, chat); // 添加到列表顶部
      notifyListeners();
      print('添加新聊天到列表: ${chat.id}, 名称: ${chat.name}');
    }
  }

  // 加载群组消息
  Future<void> loadGroupMessages(String token, String groupId, {int limit = 20, int offset = 0}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final chatId = 'group_$groupId';
      _currentChatId = chatId;
      
      // 确保消息列表存在
      if (!_messages.containsKey(chatId)) {
        _messages[chatId] = [];
      }
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/messages?type=group&group_id=$groupId&limit=$limit&offset=$offset'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      
      if (response.statusCode == 200) {
        // 添加空值检查
        final dynamic responseData = jsonDecode(response.body);
        
        // 如果返回null或者不是List类型，初始化为空列表
        if (responseData == null) {
          print('群组 $groupId 没有消息记录，服务器返回null');
          if (offset == 0) {
            _messages[chatId] = [];
          }
        } else if (responseData is List) {
          final messages = responseData.map((item) => Message.fromJson(item)).toList();
          
          // 更新消息列表
          if (offset == 0) {
            _messages[chatId] = messages;
          } else {
            _messages[chatId]!.addAll(messages);
          }
          
          // 保存消息到本地存储
          _saveMessagesToStorage();
        } else {
          print('群组消息格式不正确: $responseData');
          if (offset == 0) {
            _messages[chatId] = [];
          }
        }
        
        notifyListeners();
      } else if (response.statusCode == 404) {
        // 如果没有消息，初始化为空列表
        if (offset == 0) {
          _messages[chatId] = [];
        }
      } else {
        throw Exception('加载群组消息失败: ${response.body}');
      }
    } catch (e) {
      print('加载群组消息失败: $e');
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 发送群组文本消息
  Future<void> sendGroupMessage({
    required String token,
    required String groupId,
    required String content,
    required MessageType type,
  }) async {
    try {
      final chatId = 'group_$groupId';
      
      // 创建消息对象
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: _currentChatUserId?.toString() ?? '1',
        senderName: 'Me', // 当前用户名
        senderAvatar: null,
        groupId: groupId,
        type: type,
        content: content,
        timestamp: DateTime.now(),
        read: false,
      );
      
      // 将消息添加到本地列表
      if (!_messages.containsKey(chatId)) {
        _messages[chatId] = [];
      }
      _messages[chatId]!.add(message);
      
      // 更新聊天列表
      _updateChatList(chatId, message);
      
      // 保存消息到本地存储
      _saveMessagesToStorage();
      
      notifyListeners();
      
      // 确保token包含Bearer前缀
      final authToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
      print('发送群组消息使用的令牌: $authToken');
      
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authToken,
        },
        body: jsonEncode({
          'group_id': groupId,
          'type': type.toString().split('.').last,
          'content': content,
        }),
      );
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('发送消息失败: ${response.body}');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      print('发送群组消息错误: $e');
      // 不抛出异常，让用户界面继续工作
    }
  }

  // 发送群组媒体消息
  Future<void> sendGroupMediaMessage({
    required String token,
    required String groupId,
    required File file,
    required MessageType type,
  }) async {
    try {
      // 模拟上传媒体文件
      await Future.delayed(const Duration(seconds: 1));
      final mediaUrl = 'file://${file.path}';
      
      // 发送包含媒体URL的消息
      await sendGroupMessage(
        token: token,
        groupId: groupId,
        content: mediaUrl,
        type: type,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      print('发送群组媒体消息错误: $e');
      // 不抛出异常，让用户界面继续工作
    }
  }

  // 保存消息到本地存储
  Future<void> _saveMessagesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 将消息转换为可存储的格式
      final Map<String, List<String>> serializedMessages = {};
      for (final entry in _messages.entries) {
        serializedMessages[entry.key] = entry.value
            .map((message) => jsonEncode(message.toJson()))
            .toList();
      }
      
      // 将消息保存到本地存储
      for (final entry in serializedMessages.entries) {
        await prefs.setStringList('messages_${entry.key}', entry.value);
      }
      
      // 保存聊天ID列表，用于加载时恢复
      final chatIds = _messages.keys.toList();
      await prefs.setStringList('chat_ids', chatIds);
      
      print('已保存 ${_messages.length} 个聊天的消息到本地存储');
    } catch (e) {
      print('保存消息到本地存储时出错: $e');
    }
  }
  
  // 从本地存储加载消息
  Future<void> _loadMessagesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取聊天ID列表
      final chatIds = prefs.getStringList('chat_ids') ?? [];
      
      // 清空现有消息
      _messages.clear();
      
      // 加载每个聊天的消息
      for (final chatId in chatIds) {
        final messageJsonList = prefs.getStringList('messages_$chatId') ?? [];
        if (messageJsonList.isNotEmpty) {
          _messages[chatId] = messageJsonList
              .map((json) => Message.fromJson(jsonDecode(json)))
              .toList();
        }
      }
      
      print('从本地存储加载了 ${_messages.length} 个聊天的消息');
    } catch (e) {
      print('从本地存储加载消息时出错: $e');
    }
  }
} 