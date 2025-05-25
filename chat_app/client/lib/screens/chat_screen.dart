import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

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
  
  @override
  void initState() {
    super.initState();
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
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.user.avatarUrl != null
                  ? NetworkImage(widget.user.avatarUrl!)
                  : null,
              child: widget.user.avatarUrl == null
                  ? Text(widget.user.username[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.username),
                Text(
                  widget.user.isOnline ? '在线' : '离线',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.user.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // 显示联系人信息
              Navigator.of(context).pushNamed(
                '/profile',
                arguments: {
                  'user': widget.user,
                  'isContact': true, // 假设从聊天界面进入的用户都是联系人
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (ctx, chatProvider, child) {
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
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // 显示附件选择
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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