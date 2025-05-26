import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../models/chat.dart';
import '../models/group.dart';
import '../utils/app_routes.dart';
import '../widgets/chat_list_item.dart';

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
        ],
      ),
      body: RefreshIndicator(
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
                    const SizedBox(height: 16),
                    Text(
                      '没有聊天记录',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击右下角按钮开始聊天',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: chatProvider.chats.length,
                itemBuilder: (ctx, i) => ChatListItem(
                  chat: chatProvider.chats[i],
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.chat,
                      arguments: chatProvider.chats[i],
                    );
                  },
                  onLongPress: () {
                    _showChatOptions(context, chatProvider.chats[i]);
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showChatOptions(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showChatOptions(BuildContext context, [Chat? chat]) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (chat != null) {
          // 显示聊天操作选项
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.push_pin),
                  title: const Text('置顶聊天'),
                  onTap: () {
                    // 实现置顶聊天功能
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('置顶功能开发中')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('删除聊天', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    // 实现删除聊天功能
                    Navigator.of(ctx).pop();
                    _showDeleteConfirmation(context, chat);
                  },
                ),
              ],
            ),
          );
        } else {
          // 显示新建聊天选项
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
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
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Chat chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除聊天'),
        content: const Text('确定要删除此聊天吗？聊天记录将会被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 实现删除聊天功能
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('删除功能开发中')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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