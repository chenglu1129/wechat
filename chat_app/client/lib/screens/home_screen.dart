import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../models/chat.dart';
import '../models/group.dart';
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
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    
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
        
        // 加载群组列表
        await groupProvider.loadUserGroups();
        
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
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (authProvider.token != null) {
        await chatProvider.loadChats(authProvider.token!);
        await groupProvider.loadUserGroups();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
  
  // 创建群组
  Future<void> _createGroup() async {
    final result = await Navigator.of(context).pushNamed(AppRoutes.createGroup);
    
    if (result != null && result is Group) {
      // 创建成功，打开群组聊天页面
      final chat = Chat(
        id: 'group_${result.id}',
        name: result.name,
        avatarUrl: result.avatarUrl,
        type: ChatType.group,
      );
      
      // 跳转到群聊页面
      Navigator.of(context).pushNamed(
        AppRoutes.chat,
        arguments: chat,
      );
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
        onPressed: _createGroup,
        tooltip: '创建群组',
        child: const Icon(Icons.group_add),
      ),
    );
  }
}

// 聊天搜索代理
class ChatSearchDelegate extends SearchDelegate<Chat> {
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
        close(context, chats.first);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final results = query.isEmpty
        ? chats
        : chats.where((chat) => chat.name.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final chat = results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
            child: chat.avatarUrl == null
                ? Text(
                    chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          title: Text(chat.name),
          subtitle: Text(
            chat.lastMessage ?? '暂无消息',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: chat.type == ChatType.group
              ? const Icon(Icons.group)
              : (chat.isOnline
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null),
          onTap: () {
            close(context, chat);
            
            // 设置当前聊天ID，用于标记消息已读
            final chatProvider = Provider.of<ChatProvider>(context, listen: false);
            chatProvider.setCurrentChat(chat.id);
            
            // 导航到聊天页面
            Navigator.of(context).pushNamed(
              AppRoutes.chat,
              arguments: chat,
            );
          },
        );
      },
    );
  }
}

// 聊天列表项
class ChatListItem extends StatelessWidget {
  final Chat chat;

  const ChatListItem({
    Key? key,
    required this.chat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
        child: chat.avatarUrl == null
            ? Text(
                chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(child: Text(chat.name)),
          if (chat.lastMessageTime != null)
            Text(
              _formatTime(chat.lastMessageTime!),
              style: TextStyle(
                fontSize: 12,
                color: chat.unreadCount > 0 ? Colors.blue : Colors.grey,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          if (chat.isOnline && chat.type == ChatType.private)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(
              chat.lastMessage ?? '暂无消息',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        // 设置当前聊天ID，用于标记消息已读
        chatProvider.setCurrentChat(chat.id);
        
        // 导航到聊天页面
        Navigator.of(context).pushNamed(
          AppRoutes.chat,
          arguments: chat,
        );
      },
      onLongPress: () {
        // 长按显示操作菜单
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chat.type == ChatType.group)
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('查看群组信息'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // 导航到群组信息页面
                    final groupId = chat.id.split('_')[1];
                    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                    final group = groupProvider.groups.firstWhere(
                      (g) => g.id == groupId,
                      orElse: () => throw Exception('未找到群组信息'),
                    );
                    Navigator.of(context).pushNamed(
                      AppRoutes.groupInfo,
                      arguments: group,
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('删除聊天'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // 显示确认对话框
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除聊天'),
                      content: const Text('确定要删除此聊天吗？这将删除所有聊天记录。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            // 删除聊天
                            // TODO: 实现删除聊天功能
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('删除聊天功能尚未实现')),
                            );
                          },
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (chat.type == ChatType.group)
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('退出群组'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // 显示确认对话框
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('退出群组'),
                        content: const Text('确定要退出此群组吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              // 退出群组
                              final groupId = chat.id.split('_')[1];
                              final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                              groupProvider.leaveGroup(groupId).then((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已退出群组')),
                                );
                              }).catchError((error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('退出群组失败: $error')),
                                );
                              });
                            },
                            child: const Text('退出'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      // 今天的消息只显示时间
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      // 昨天的消息显示"昨天"
      return '昨天';
    } else {
      // 其他日期显示月/日
      return '${time.month}/${time.day}';
    }
  }
} 