import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat.dart';
import '../utils/app_routes.dart';
import '../utils/mock_websocket.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  MockWebSocketService? _mockWebSocketService;

  @override
  void initState() {
    super.initState();
    _loadChats();
    
    // 延迟一点启动模拟服务，确保Provider已经完成初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMockService();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mockWebSocketService?.stopMockService();
    super.dispose();
  }
  
  void _startMockService() {
    // 创建并启动模拟WebSocket服务
    _mockWebSocketService = MockWebSocketService(context);
    _mockWebSocketService!.startMockService();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      if (authProvider.token != null) {
        await chatProvider.loadChats(authProvider.token!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 实现搜索功能
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                authProvider.logout();
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              } else if (value == 'settings') {
                Navigator.of(context).pushNamed(AppRoutes.settings);
              } else if (value == 'profile') {
                Navigator.of(context).pushNamed(AppRoutes.profile);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('个人资料'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('设置'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('退出登录'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : chatProvider.chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('没有聊天记录'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.contacts);
                        },
                        child: const Text('添加联系人'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: chatProvider.chats.length,
                  itemBuilder: (ctx, index) {
                    final chat = chatProvider.chats[index];
                    return ChatListItem(chat: chat);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('添加联系人'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(AppRoutes.contacts);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_add),
                  title: const Text('创建群组'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(AppRoutes.createGroup);
                  },
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final Chat chat;

  const ChatListItem({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: chat.avatarUrl != null
            ? NetworkImage(chat.avatarUrl!)
            : null,
        child: chat.avatarUrl == null
            ? Text(chat.name[0].toUpperCase())
            : null,
      ),
      title: Text(chat.name),
      subtitle: chat.lastMessage != null
          ? Text(
              chat.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            chat.formattedLastMessageTime,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 5),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.setCurrentChat(chat.id);
        Navigator.of(context).pushNamed(
          AppRoutes.chat,
          arguments: chat,
        );
      },
    );
  }
} 