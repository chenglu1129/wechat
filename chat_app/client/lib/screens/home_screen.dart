import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../models/chat.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../utils/app_routes.dart';
import '../widgets/chat_list_item.dart';
import 'chat_screen.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        print('聊天列表已刷新，共${chatProvider.chats.length}个聊天');
      }
    } catch (e) {
      print('刷新聊天列表时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新聊天列表失败: $e')),
      );
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
                delegate: ChatSearchDelegate(Provider.of<ChatProvider>(context).chats),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshChats,
            tooltip: '刷新聊天列表',
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (chatProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '加载聊天列表失败',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chatProvider.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshChats,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          
          final chats = chatProvider.chats;
          
          if (chats.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshChats,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: '暂无聊天',
                      message: '您还没有任何聊天记录\n去联系人页面开始新的聊天吧',
                    ),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: _refreshChats,
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ChatListItem(
                  chat: chat,
                  onTap: () => _navigateToChatScreen(context, chat),
                  onLongPress: () => _showChatOptions(context, chat),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewChatOptions(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToChatScreen(BuildContext context, Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chat.id,
          user: User(
            id: int.tryParse(chat.id.split('_').last) ?? 0,
            username: chat.name,
            email: 'unknown@example.com',
            avatarUrl: chat.avatarUrl,
            isOnline: chat.isOnline ?? false,
          ),
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context, Chat chat) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('删除聊天'),
            onTap: () {
              Navigator.of(ctx).pop();
              _confirmDeleteChat(context, chat);
            },
          ),
          ListTile(
            leading: const Icon(Icons.mark_chat_read),
            title: const Text('标记为已读'),
            onTap: () {
              Navigator.of(ctx).pop();
              _markChatAsRead(context, chat);
            },
          ),
        ],
      ),
    );
  }
  
  void _confirmDeleteChat(BuildContext context, Chat chat) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除聊天'),
        content: Text('确定要删除与 ${chat.name} 的聊天吗？聊天记录将会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteChat(context, chat);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  void _deleteChat(BuildContext context, Chat chat) async {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.token != null) {
        await chatProvider.deleteChat(authProvider.token!, chat.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除与 ${chat.name} 的聊天')),
        );
      }
    } catch (e) {
      print('删除聊天时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除聊天失败: $e')),
      );
    }
  }
  
  void _markChatAsRead(BuildContext context, Chat chat) async {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.token != null) {
        await chatProvider.markChatAsRead(authProvider.token!, chat.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将与 ${chat.name} 的聊天标记为已读')),
        );
      }
    } catch (e) {
      print('标记聊天为已读时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标记聊天为已读失败: $e')),
      );
    }
  }

  // 显示新建聊天选项
  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('发起私聊'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed(AppRoutes.contacts);
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('创建群聊'),
            onTap: () {
              Navigator.of(ctx).pop();
              _createGroup();
            },
          ),
        ],
      ),
    );
  }
}

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
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final filteredChats = query.isEmpty
        ? chats
        : chats.where((chat) {
            return chat.name.toLowerCase().contains(query.toLowerCase()) ||
                (chat.lastMessage?.toLowerCase().contains(query.toLowerCase()) ?? false);
          }).toList();

    return filteredChats.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  '没有找到匹配 "$query" 的聊天',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          )
        : ListView.builder(
            itemCount: filteredChats.length,
            itemBuilder: (ctx, i) {
              return ChatListItem(
                chat: filteredChats[i],
                onTap: () {
                  close(context, '');
                  Navigator.of(context).pushNamed(
                    AppRoutes.chat,
                    arguments: filteredChats[i],
                  );
                },
              );
            },
          );
  }
} 