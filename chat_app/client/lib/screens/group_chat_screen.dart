import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/group.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/avatar_widget.dart';
import '../utils/app_routes.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({Key? key, required this.group}) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isAttachmentMenuOpen = false;

  @override
  void initState() {
    super.initState();
    
    // 加载群组信息和消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroupInfo();
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    
    // 清除当前聊天ID
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.clearCurrentChat();
    
    super.dispose();
  }

  // 加载群组信息
  Future<void> _loadGroupInfo() async {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    await groupProvider.setCurrentGroup(widget.group);
  }

  // 加载消息
  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.token != null) {
        // 设置当前聊天ID
        final chatId = 'group_${widget.group.id}';
        chatProvider.setCurrentChat(chatId);
        
        // 加载群组消息
        await chatProvider.loadGroupMessages(
          authProvider.token!,
          widget.group.id,
        );
        
        // 滚动到底部
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载消息失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 发送消息
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    _messageController.clear();
    
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user != null) {
        await chatProvider.sendGroupMessage(
          groupId: widget.group.id,
          content: message,
          type: MessageType.text,
        );
        
        // 滚动到底部
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送消息失败: $e')),
      );
    }
  }

  // 发送图片
  Future<void> _sendImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        setState(() {
          _isAttachmentMenuOpen = false;
        });
        
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        
        await chatProvider.sendGroupMediaMessage(
          groupId: widget.group.id,
          file: File(image.path),
          type: MessageType.image,
        );
        
        // 滚动到底部
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送图片失败: $e')),
      );
    }
  }

  // 发送文件
  Future<void> _sendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        setState(() {
          _isAttachmentMenuOpen = false;
        });
        
        final file = File(result.files.single.path!);
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        
        await chatProvider.sendGroupMediaMessage(
          groupId: widget.group.id,
          file: file,
          type: MessageType.file,
        );
        
        // 滚动到底部
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送文件失败: $e')),
      );
    }
  }

  // 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    
    final currentUser = authProvider.user;
    final group = groupProvider.currentGroup ?? widget.group;
    final messages = chatProvider.currentMessages;
    
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.groupInfo,
              arguments: group,
            );
          },
          child: Row(
            children: [
              AvatarWidget(
                avatarUrl: group.avatarUrl,
                name: group.name,
                radius: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${group.memberCount}人',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.groupInfo,
                arguments: group,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无消息，开始聊天吧',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: messages.length,
                        itemBuilder: (ctx, index) {
                          final message = messages[index];
                          final isMe = currentUser != null && 
                              message.senderId == currentUser.id.toString();
                          
                          // 获取发送者信息
                          String senderName = message.senderName ?? '未知用户';
                          
                          // 计算时间显示
                          String timeText = '';
                          if (message.timestamp != null) {
                            if (index == 0 || _shouldShowDate(messages[index - 1], message)) {
                              timeText = DateFormat('yyyy-MM-dd HH:mm').format(message.timestamp!);
                            } else {
                              // 如果与上一条消息时间相差超过5分钟，显示时间
                              final prevTimestamp = messages[index - 1].timestamp;
                              if (prevTimestamp != null && 
                                  message.timestamp!.difference(prevTimestamp).inMinutes > 5) {
                                timeText = DateFormat('HH:mm').format(message.timestamp!);
                              }
                            }
                          }
                          
                          return Column(
                            children: [
                              if (timeText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    timeText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              MessageBubble(
                                message: message,
                                isMe: isMe,
                                senderName: isMe ? null : senderName,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          
          // 附件菜单
          if (_isAttachmentMenuOpen)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentButton(
                    icon: Icons.photo_camera,
                    label: '拍照',
                    onTap: () => _sendImage(ImageSource.camera),
                  ),
                  _buildAttachmentButton(
                    icon: Icons.photo_library,
                    label: '相册',
                    onTap: () => _sendImage(ImageSource.gallery),
                  ),
                  _buildAttachmentButton(
                    icon: Icons.insert_drive_file,
                    label: '文件',
                    onTap: _sendFile,
                  ),
                ],
              ),
            ),
          
          // 消息输入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
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

  // 构建附件按钮
  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // 判断是否需要显示日期
  bool _shouldShowDate(Message prev, Message current) {
    if (prev.timestamp == null || current.timestamp == null) return false;
    
    final prevDate = DateTime(
      prev.timestamp!.year,
      prev.timestamp!.month,
      prev.timestamp!.day,
    );
    final currentDate = DateTime(
      current.timestamp!.year,
      current.timestamp!.month,
      current.timestamp!.day,
    );
    
    return prevDate != currentDate;
  }
} 