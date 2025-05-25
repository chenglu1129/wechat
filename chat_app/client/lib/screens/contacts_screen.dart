import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/contact_provider.dart';
import '../widgets/contact_item.dart';
import '../utils/app_routes.dart';
import 'search_users_screen.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with SingleTickerProviderStateMixin {
  bool _isInit = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _animation;
  bool _showSortOptions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Provider.of<ContactProvider>(context, listen: false)
        .setFilterKeyword(_searchController.text);
  }

  void _toggleSortOptions() {
    setState(() {
      _showSortOptions = !_showSortOptions;
    });
    if (_showSortOptions) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      // 加载联系人列表
      Provider.of<ContactProvider>(context, listen: false).loadContacts();
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人'),
        actions: [
          // 排序按钮
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onPressed: _toggleSortOptions,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: '好友请求',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.friendRequests);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const SearchUsersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索联系人',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // 排序选项
          SizeTransition(
            sizeFactor: _animation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Consumer<ContactProvider>(
                builder: (ctx, contactProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '排序方式:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildSortChip(
                            context,
                            label: '姓名 A-Z',
                            sortOption: SortOption.nameAsc,
                            contactProvider: contactProvider,
                          ),
                          _buildSortChip(
                            context,
                            label: '姓名 Z-A',
                            sortOption: SortOption.nameDesc,
                            contactProvider: contactProvider,
                          ),
                          _buildSortChip(
                            context,
                            label: '在线优先',
                            sortOption: SortOption.onlineFirst,
                            contactProvider: contactProvider,
                          ),
                          _buildSortChip(
                            context,
                            label: '离线优先',
                            sortOption: SortOption.offlineFirst,
                            contactProvider: contactProvider,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          
          // 联系人列表
          Expanded(
            child: Consumer<ContactProvider>(
              builder: (ctx, contactProvider, child) {
                if (contactProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
  
                if (contactProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '加载失败: ${contactProvider.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            contactProvider.loadContacts();
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }
  
                final contacts = contactProvider.contacts.contacts;
                if (contacts.isEmpty) {
                  if (contactProvider.filterKeyword.isNotEmpty) {
                    // 搜索无结果
                    return Center(
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
                            '没有找到匹配 "${contactProvider.filterKeyword}" 的联系人',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  } else {
                    // 无联系人
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '暂无联系人',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => const SearchUsersScreen(),
                                ),
                              );
                            },
                            child: const Text('添加联系人'),
                          ),
                        ],
                      ),
                    );
                  }
                }
  
                return RefreshIndicator(
                  onRefresh: () => contactProvider.loadContacts(),
                  child: AnimatedList(
                    initialItemCount: contacts.length,
                    itemBuilder: (ctx, index, animation) {
                      final contact = contacts[index];
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        )),
                        child: ContactItem(
                          user: contact,
                          onTap: () {
                            // 导航到聊天界面
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => ChatScreen(user: contact),
                              ),
                            );
                          },
                          onLongPress: () {
                            _showContactOptions(context, contact);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const SearchUsersScreen(),
            ),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
  
  Widget _buildSortChip(
    BuildContext context, {
    required String label,
    required SortOption sortOption,
    required ContactProvider contactProvider,
  }) {
    final isSelected = contactProvider.sortOption == sortOption;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          contactProvider.setSortOption(sortOption);
        }
      },
    );
  }

  void _showContactOptions(BuildContext context, User contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('发送消息'),
              onTap: () {
                Navigator.of(context).pop();
                // 导航到聊天界面
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ChatScreen(user: contact),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('查看资料'),
              onTap: () {
                Navigator.of(context).pop();
                // 导航到用户资料界面
                Navigator.of(context).pushNamed(
                  '/profile',
                  arguments: {
                    'user': contact,
                    'isContact': true,
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除联系人', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteConfirmation(context, contact);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, User contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定要删除 ${contact.username} 吗？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<ContactProvider>(context, listen: false)
                  .removeContact(contact.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 