import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/contact_provider.dart';
import '../providers/friend_request_provider.dart';
import '../widgets/user_item.dart';
import '../providers/auth_provider.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({Key? key}) : super(key: key);

  @override
  _SearchUsersScreenState createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showSendRequestDialog = false;
  User? _selectedUser;
  final _requestMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _requestMessageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 2) {
      // 只有当搜索词至少有两个字符时才触发搜索
      setState(() {
        _isSearching = true;
      });
      
      // 搜索用户
      _searchUsers(_searchController.text);
    } else if (_searchController.text.isEmpty) {
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      contactProvider.clearSearchResults();
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    
    try {
      await contactProvider.searchUsers(query, reset: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _showAddFriendDialog(User user) {
    // 获取当前用户信息
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUsername = authProvider.user?.username ?? "用户";
    
    setState(() {
      _selectedUser = user;
      _showSendRequestDialog = true;
      _requestMessageController.text = '我是$currentUsername，请求添加您为好友';
    });
  }

  Future<void> _sendFriendRequest() async {
    if (_selectedUser == null) return;
    
    // 隐藏对话框
    setState(() {
      _showSendRequestDialog = false;
    });
    
    // 显示加载指示器
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在发送好友请求...')),
    );
    
    try {
      final requestProvider = Provider.of<FriendRequestProvider>(context, listen: false);
      final success = await requestProvider.sendRequest(
        _selectedUser!.id,
        _requestMessageController.text,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已发送好友请求给 ${_selectedUser!.username}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送好友请求失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索用户'),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '搜索用户',
                hintText: '输入用户名或邮箱',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          
          // 搜索结果
          Expanded(
            child: Consumer<ContactProvider>(
              builder: (ctx, contactProvider, child) {
                if (_isSearching) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                if (contactProvider.searchError != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '搜索失败: ${contactProvider.searchError}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_searchController.text.isNotEmpty) {
                              _searchUsers(_searchController.text);
                            }
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }
                
                final searchResult = contactProvider.searchResult;
                if (searchResult == null || searchResult.users.isEmpty) {
                  if (_searchController.text.isEmpty) {
                    return const Center(
                      child: Text('输入用户名或邮箱开始搜索'),
                    );
                  } else {
                    return const Center(
                      child: Text('未找到匹配的用户'),
                    );
                  }
                }
                
                return ListView.builder(
                  itemCount: searchResult.users.length + (searchResult.hasMore ? 1 : 0),
                  itemBuilder: (ctx, index) {
                    if (index == searchResult.users.length) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              contactProvider.searchUsers(
                                _searchController.text,
                                offset: searchResult.users.length,
                                reset: false,
                              );
                            },
                            child: const Text('加载更多'),
                          ),
                        ),
                      );
                    }
                    
                    final user = searchResult.users[index];
                    return UserItem(
                      user: user,
                      isContact: contactProvider.isContact(user.id),
                      onAddContact: () {
                        _showAddFriendDialog(user);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      
      // 添加好友请求对话框
      bottomSheet: _showSendRequestDialog
          ? Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '添加 ${_selectedUser?.username ?? ""} 为好友',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _requestMessageController,
                      decoration: const InputDecoration(
                        labelText: '验证消息',
                        hintText: '请输入验证消息',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showSendRequestDialog = false;
                            });
                          },
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _sendFriendRequest,
                          child: const Text('发送请求'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
} 