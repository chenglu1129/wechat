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
  bool _isRefreshing = false;
  MockWebSocketService? _mockWebSocketService;

  @override
  void initState() {
    super.initState();
    
    // 使用addPostFrameCallback确保在构建完成后才加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    print('初始化应用...');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 确保用户已登录
    if (authProvider.token != null && authProvider.user != null) {
      print('用户已登录，加载聊天列表和连接WebSocket');
      
      try {
        // 连接WebSocket
        chatProvider.connectWebSocket(
          authProvider.token!,
          authProvider.user!.id.toString(),
        );
        
        // 加载聊天列表
        await _loadChats();
        
        // 启动模拟服务
        _startMockService();
      } catch (e) {
        print('初始化应用时发生错误: $e');
        // 显示错误提示，但不中断流程
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化应用时发生错误: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                _initializeApp();
              },
            ),
          ),
        );
      }
    } else {
      print('用户未登录，尝试从本地存储加载用户数据');
      // 用户可能未完全初始化，等待一下再尝试
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 重新检查用户状态
      if (authProvider.token != null && authProvider.user != null) {
        print('用户数据已加载，初始化应用');
        _initializeApp();
      } else {
        print('用户仍未登录，跳转到登录页面');
        // 如果用户仍未登录，可能需要跳转到登录页面
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mockWebSocketService?.stopMockService();
    
    // 断开WebSocket连接
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.disconnectWebSocket();
    
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
        print('开始加载聊天列表...');
        await chatProvider.loadChats(authProvider.token!);
        print('聊天列表加载完成，共${chatProvider.chats.length}个聊天');
      } else {
        print('无法加载聊天列表: 令牌为空');
      }
    } catch (e) {
      print('加载聊天列表时发生错误: $e');
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载聊天列表失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 刷新聊天列表
  Future<void> _refreshChats() async {
    setState(() {
      _isRefreshing = true;
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
          _isRefreshing = false;
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
              showSearch(
                context: context,
                delegate: ChatSearchDelegate(chatProvider.chats),
              );
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
          : RefreshIndicator(
              onRefresh: _refreshChats,
              child: chatProvider.chats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '没有聊天记录',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppRoutes.contacts);
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('添加联系人'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: chatProvider.chats.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final chat = chatProvider.chats[index];
                        return ChatListItem(chat: chat);
                      },
                    ),
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

// 聊天搜索代理
class ChatSearchDelegate extends SearchDelegate<String> {
  final List<Chat> chats;
  
  ChatSearchDelegate(this.chats);
  
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }
  
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }
  
  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }
  
  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }
  
  Widget _buildSearchResults() {
    final filteredChats = chats.where((chat) => 
      chat.name.toLowerCase().contains(query.toLowerCase()) ||
      (chat.lastMessage?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();
    
    if (filteredChats.isEmpty) {
      return const Center(
        child: Text('没有找到相关聊天'),
      );
    }
    
    return ListView.builder(
      itemCount: filteredChats.length,
      itemBuilder: (context, index) {
        return ChatListItem(chat: filteredChats[index]);
      },
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: chat.avatarUrl != null
                ? NetworkImage(chat.avatarUrl!)
                : null,
            child: chat.avatarUrl == null
                ? Text(
                    chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 18),
                  )
                : null,
          ),
          if (chat.isOnline && chat.type == ChatType.private)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            chat.formattedLastMessageTime,
            style: TextStyle(
              fontSize: 12,
              color: chat.unreadCount > 0 ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: chat.lastMessage != null
                ? Text(
                    chat.lastMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chat.unreadCount > 0 ? Colors.black87 : Colors.grey,
                    ),
                  )
                : const Text(
                    '[没有消息]',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      onTap: () {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.setCurrentChat(chat.id);
        
        // 直接传递Chat对象
        print('点击聊天项: ${chat.id}, 名称: ${chat.name}');
        Navigator.of(context).pushNamed(
          AppRoutes.chat,
          arguments: chat,
        );
      },
    );
  }
} 