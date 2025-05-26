import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../models/chat.dart';
import '../providers/contact_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/contact_item.dart';
import '../utils/app_routes.dart';
import 'search_users_screen.dart';
import 'chat_screen.dart';
import '../models/group.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with SingleTickerProviderStateMixin {
  bool _isInit = false;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _showSortOptions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    contactProvider.setFilterKeyword(_searchController.text);
  }

  void _toggleSortOptions() {
    setState(() {
      _showSortOptions = !_showSortOptions;
    });
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      // 使用addPostFrameCallback确保在构建完成后才加载数据
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 加载联系人列表
        Provider.of<ContactProvider>(context, listen: false).loadContacts();
        // 加载群组列表
        Provider.of<GroupProvider>(context, listen: false).loadUserGroups();
      });
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '联系人'),
            Tab(text: '群组'),
          ],
        ),
        actions: [
          // 排序按钮
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onPressed: _toggleSortOptions,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '添加联系人',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const SearchUsersScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: '好友请求',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.friendRequests);
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
                hintText: '搜索联系人或群组',
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
          if (_showSortOptions)
            Container(
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
          
          // Tab内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 联系人列表
                _buildContactsList(),
                
                // 群组列表
                _buildGroupsList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            // 添加联系人
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => const SearchUsersScreen(),
              ),
            );
          } else {
            // 创建群组
            Navigator.of(context).pushNamed(AppRoutes.createGroup);
          }
        },
        child: Icon(_tabController.index == 0 ? Icons.person_add : Icons.group_add),
      ),
    );
  }
  
  Widget _buildContactsList() {
    return Consumer<ContactProvider>(
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
                  const Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '暂无联系人',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('添加联系人'),
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
            );
          }
        }

        // 显示联系人列表
        return ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (ctx, index) {
            final contact = contacts[index];
            return ContactItem(
              user: contact,
              onTap: () {
                // 构建聊天ID
                final chatId = 'private_${contact.id}';
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      user: contact,
                      chatId: chatId,
                    ),
                  ),
                );
              },
              onLongPress: () {
                _showContactOptions(contact);
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildGroupsList() {
    return Consumer<GroupProvider>(
      builder: (ctx, groupProvider, child) {
        if (groupProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (groupProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '加载失败: ${groupProvider.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    groupProvider.loadUserGroups();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final groups = groupProvider.groups;
        final keyword = _searchController.text.toLowerCase();
        final filteredGroups = keyword.isEmpty
            ? groups
            : groups.where((group) => group.name.toLowerCase().contains(keyword)).toList();
        
        if (filteredGroups.isEmpty) {
          if (keyword.isNotEmpty) {
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
                    '没有找到匹配 "$keyword" 的群组',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else {
            // 无群组
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '暂无群组',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.group_add),
                    label: const Text('创建群组'),
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.createGroup);
                    },
                  ),
                ],
              ),
            );
          }
        }

        // 显示群组列表
        return ListView.builder(
          itemCount: filteredGroups.length,
          itemBuilder: (ctx, index) {
            final group = filteredGroups[index];
            return _buildGroupItem(group);
          },
        );
      },
    );
  }
  
  Widget _buildGroupItem(Group group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: group.avatarUrl != null ? NetworkImage(group.avatarUrl!) : null,
        child: group.avatarUrl == null
            ? Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(group.name),
      subtitle: Text('${group.memberCount ?? 0}人'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // 打开群聊
        Navigator.of(context).pushNamed(
          AppRoutes.chat,
          arguments: _convertGroupToChat(group),
        );
      },
      onLongPress: () {
        _showGroupOptions(group);
      },
    );
  }
  
  // 将Group对象转换为Chat对象，用于导航到聊天页面
  Chat _convertGroupToChat(Group group) {
    return Chat(
      id: 'group_${group.id}',
      name: group.name,
      avatarUrl: group.avatarUrl,
      type: ChatType.group,
    );
  }
  
  void _showContactOptions(User contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('发送消息'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    user: contact,
                    chatId: 'private_${contact.id}',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('查看资料'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamed(
                AppRoutes.profile,
                arguments: {'user': contact, 'isContact': true},
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除联系人', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _showDeleteConfirmation(contact);
            },
          ),
        ],
      ),
    );
  }
  
  void _showGroupOptions(Group group) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('发送消息'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamed(
                AppRoutes.chat,
                arguments: _convertGroupToChat(group),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('群组信息'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamed(
                AppRoutes.groupInfo,
                arguments: group,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('退出群组', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _showLeaveGroupConfirmation(group);
            },
          ),
        ],
      ),
    );
  }
  
  void _showDeleteConfirmation(User contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定要删除联系人 ${contact.username} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 执行删除联系人操作
              final contactProvider = Provider.of<ContactProvider>(context, listen: false);
              contactProvider.removeContact(contact.id).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除联系人 ${contact.username}')),
                );
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除联系人失败: $error')),
                );
              });
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _showLeaveGroupConfirmation(Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出群组'),
        content: Text('确定要退出群组 ${group.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 执行退出群组操作
              final groupProvider = Provider.of<GroupProvider>(context, listen: false);
              groupProvider.leaveGroup(group.id).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已退出群组 ${group.name}')),
                );
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('退出群组失败: $error')),
                );
              });
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
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
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        contactProvider.setSortOption(sortOption);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
} 