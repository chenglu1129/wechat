import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../services/media_service.dart';

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
  
  @override
  void initState() {
    super.initState();
    _contact = widget.user; // 初始化联系人
    _initChat();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
                
                if (chatProvider.error != null && chatProvider.currentMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '加载消息失败: ${chatProvider.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initChat,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }
                
                final messages = chatProvider.currentMessages;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('没有消息，开始聊天吧'),
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
          ChatInput(
            onSendText: _sendTextMessage,
            onSendMedia: _sendMediaMessage,
            mediaService: Provider.of<MediaService>(context, listen: false),
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
      // 使用现有的sendMessage方法发送消息
      chatProvider.sendMessage(
        authProvider.token!,
        text,
        receiverId: _contact!.id.toString(),
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