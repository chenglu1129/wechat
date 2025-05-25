import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/contact_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../services/media_service.dart';
import '../services/user_service.dart';
import '../utils/token_manager.dart';

class ChatScreen extends StatefulWidget {
  final User user;
  
  const ChatScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  String? _error;
  String? _chatId;
  User? _contact;
  bool _isLoadingContact = false;
  
  @override
  void initState() {
    super.initState();
    _contact = widget.user; // 初始化联系人
    _initChat();
    _scrollController.addListener(_onScroll);
    
    // 如果联系人信息不完整，尝试加载完整信息
    if (_contact?.email == 'unknown@example.com') {
      _loadContactInfo();
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  // 加载联系人完整信息
  Future<void> _loadContactInfo() async {
    if (_isLoadingContact || _contact == null) return;
    
    setState(() {
      _isLoadingContact = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      
      if (authProvider.token != null) {
        // 首先尝试从联系人列表中获取
        final contactFromList = contactProvider.contacts.contacts.firstWhere(
          (contact) => contact.id == _contact!.id,
          orElse: () => _contact!,
        );
        
        if (contactFromList.email != 'unknown@example.com') {
          // 如果找到了完整的联系人信息，更新当前联系人
          setState(() {
            _contact = contactFromList;
            _isLoadingContact = false;
          });
          return;
        }
        
        // 如果联系人列表中没有，尝试从API获取
        final tokenManager = TokenManager();
        final userService = UserService(tokenManager: tokenManager);
        
        try {
          await tokenManager.saveToken(authProvider.token!);
          final user = await userService.getUserProfile(_contact!.id);
          
          setState(() {
            _contact = user;
          });
        } catch (e) {
          print('加载联系人信息失败: $e');
          // 不显示错误，继续使用现有的联系人信息
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContact = false;
        });
      }
    }
  }
  
  void _initChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      if (authProvider.token != null) {
        // 构建聊天ID
        _chatId = 'private_${widget.user.id}';
        
        // 设置当前聊天
        chatProvider.setCurrentChat(_chatId!);
        
        // 加载消息历史
        chatProvider.loadMessages(authProvider.token!, _chatId!);
        
        // 确保此聊天添加到聊天列表中
        // 如果没有消息历史，创建一个空的聊天项
        final existingChat = chatProvider.chats.firstWhere(
          (chat) => chat.id == _chatId,
          orElse: () => Chat(
            id: _chatId!,
            name: widget.user.username,
            avatarUrl: widget.user.avatarUrl,
            type: ChatType.private,
            isOnline: widget.user.isOnline,
          ),
        );
        
        // 如果是新聊天，添加到列表中
        if (!chatProvider.chats.any((chat) => chat.id == _chatId)) {
          chatProvider.addChat(existingChat);
        }
      }
    });
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels <= 100) {
      // 当滚动到顶部时，加载更多历史消息
      _loadMoreMessages();
    }
  }
  
  void _loadMoreMessages() {
    if (_isLoading || _chatId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.token != null) {
      final currentMessages = chatProvider.currentMessages;
      chatProvider.loadMessages(
        authProvider.token!,
        _chatId!,
        offset: currentMessages.length,
      ).then((_) {
        setState(() {
          _isLoading = false;
        });
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.token != null) {
      chatProvider.sendMessage(
        authProvider.token!,
        message,
        receiverId: widget.user.id.toString(),
      ).then((success) {
        if (success) {
          _messageController.clear();
          // 滚动到底部
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_contact?.username ?? '聊天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // 显示聊天选项菜单
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (ctx, chatProvider, _) {
                if (chatProvider.isLoading && chatProvider.currentMessages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                final messages = chatProvider.currentMessages;
                if (messages.isEmpty) {
                  // 即使有错误，如果没有消息，也显示友好的空聊天提示，而不是错误信息
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '没有消息记录',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '发送一条消息开始聊天吧',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // 按时间倒序排列消息
                final sortedMessages = List<Message>.from(messages)
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // 从底部开始显示
                  padding: const EdgeInsets.all(10),
                  itemCount: sortedMessages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (ctx, index) {
                    if (_isLoading && index == 0) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    
                    final realIndex = _isLoading ? index - 1 : index;
                    final message = sortedMessages[realIndex];
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final isMe = message.senderId == authProvider.user?.id.toString();
                    
                    // 显示日期分隔符
                    final showDate = realIndex == sortedMessages.length - 1 ||
                        _shouldShowDate(sortedMessages[realIndex], 
                                      realIndex < sortedMessages.length - 1 
                                          ? sortedMessages[realIndex + 1] 
                                          : null);
                    
                    return Column(
                      children: [
                        if (showDate)
                          _buildDateDivider(message.timestamp),
                        MessageBubble(
                          message: message,
                          isMe: isMe,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // 输入框
          Consumer<ChatProvider>(
            builder: (ctx, chatProvider, _) => ChatInput(
              onSendText: _sendTextMessage,
              onSendMedia: _sendMediaMessage,
              mediaService: Provider.of<MediaService>(context, listen: false),
              isFirstMessage: chatProvider.currentMessages.isEmpty,
            ),
          ),
        ],
      ),
    );
  }
  
  // 发送文本消息
  void _sendTextMessage(String text) {
    if (text.isEmpty) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.user != null && _contact != null && authProvider.token != null) {
      print('发送消息: "${text}" 到用户: ${_contact!.username} (ID: ${_contact!.id})');
      
      // 使用现有的sendMessage方法发送消息
      chatProvider.sendMessage(
        authProvider.token!,
        text,
        receiverId: _contact!.id.toString(),
      ).then((success) {
        if (success) {
          print('消息发送成功');
          
          // 确保聊天被添加到首页列表
          final chatId = 'private_${_contact!.id}';
          final existingChat = chatProvider.chats.firstWhere(
            (chat) => chat.id == chatId,
            orElse: () => Chat(
              id: chatId,
              name: _contact!.username,
              avatarUrl: _contact!.avatarUrl,
              type: ChatType.private,
              lastMessage: text,
              lastMessageTime: DateTime.now(),
              isOnline: _contact!.isOnline,
            ),
          );
          
          // 如果是新聊天，添加到列表中
          if (!chatProvider.chats.any((chat) => chat.id == chatId)) {
            print('将新聊天添加到列表: $chatId');
            chatProvider.addChat(existingChat);
          }
        } else {
          print('消息发送失败: ${chatProvider.error}');
          // 显示错误提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('发送失败: ${chatProvider.error ?? "未知错误"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }).catchError((error) {
        print('发送消息时发生错误: $error');
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送错误: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } else {
      print('无法发送消息: 用户未登录或联系人为空');
      print('authProvider.user: ${authProvider.user}');
      print('_contact: $_contact');
      print('authProvider.token: ${authProvider.token != null ? "非空" : "为空"}');
      
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法发送消息: 请确保您已登录'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 发送媒体消息
  void _sendMediaMessage(MediaItem mediaItem, String? caption) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final mediaService = Provider.of<MediaService>(context, listen: false);
    
    if (authProvider.user != null && _contact != null && authProvider.token != null) {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在上传媒体文件...'),
            ],
          ),
        ),
      );
      
      try {
        // 上传媒体文件
        final mediaUrl = await mediaService.uploadMedia(mediaItem);
        
        // 关闭加载指示器
        Navigator.pop(context);
        
        if (mediaUrl != null) {
          // 准备媒体消息内容
          String content = caption ?? '';
          
          // 使用sendMediaMessage方法发送媒体消息
          chatProvider.sendMediaMessage(
            authProvider.token!,
            _getMessageTypeFromMediaType(mediaItem.type),
            mediaUrl,
            content,
            receiverId: _contact!.id.toString(),
            metadata: {
              'name': mediaItem.name,
              'size': mediaItem.size,
              'mime_type': mediaItem.mimeType,
            },
          );
        } else {
          // 显示错误
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('上传媒体文件失败')),
          );
        }
      } catch (e) {
        // 关闭加载指示器
        Navigator.pop(context);
        
        // 显示错误
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传媒体文件失败: $e')),
        );
      }
    }
  }
  
  // 根据媒体类型获取消息类型
  MessageType _getMessageTypeFromMediaType(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.image:
        return MessageType.image;
      case MediaType.video:
        return MessageType.video;
      case MediaType.audio:
        return MessageType.audio;
      case MediaType.file:
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }
  
  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return '今天';
    } else if (messageDate == yesterday) {
      return '昨天';
    } else if (now.difference(date).inDays < 7) {
      return _getWeekday(date.weekday);
    } else {
      return DateFormat('yyyy年MM月dd日').format(date);
    }
  }
  
  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return '星期一';
      case 2:
        return '星期二';
      case 3:
        return '星期三';
      case 4:
        return '星期四';
      case 5:
        return '星期五';
      case 6:
        return '星期六';
      case 7:
        return '星期日';
      default:
        return '';
    }
  }
  
  bool _shouldShowDate(Message current, Message? previous) {
    if (previous == null) return true;
    
    final currentDate = DateTime(
      current.timestamp.year,
      current.timestamp.month,
      current.timestamp.day,
    );
    final previousDate = DateTime(
      previous.timestamp.year,
      previous.timestamp.month,
      previous.timestamp.day,
    );
    
    return currentDate != previousDate;
  }
} 