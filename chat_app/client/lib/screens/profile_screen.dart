import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../utils/app_routes.dart';
import 'edit_profile_screen.dart';
import '../widgets/online_status_indicator.dart';

class ProfileScreen extends StatelessWidget {
  final User? user; // 如果为null，则显示当前登录用户的资料
  final bool isContact; // 是否为联系人
  final bool isTabView; // 是否作为Tab页面显示
  
  const ProfileScreen({
    Key? key,
    this.user,
    this.isContact = false,
    this.isTabView = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 获取当前登录用户
    final authProvider = Provider.of<AuthProvider>(context);
    
    // 判断是查看自己的资料还是他人的资料
    final isSelf = user == null || (authProvider.user != null && user!.id == authProvider.user!.id);
    
    // 确定要显示的用户
    final displayUser = isSelf ? authProvider.user : user;
    
    // 如果没有用户数据，显示加载中
    if (displayUser == null) {
      return Scaffold(
        appBar: isTabView ? null : AppBar(
          title: const Text('用户资料'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 头像和基本信息背景
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
              ),
            ),
            padding: EdgeInsets.only(
              top: isTabView ? 60 : 30, 
              bottom: 40
            ),
            child: Column(
              children: [
                // 头像
                Hero(
                  tag: 'profile-avatar-${displayUser.id}',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: displayUser.avatarUrl != null && displayUser.avatarUrl!.isNotEmpty
                          ? NetworkImage(displayUser.avatarUrl!)
                          : null,
                      child: displayUser.avatarUrl == null || displayUser.avatarUrl!.isEmpty
                          ? Text(
                              displayUser.username.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 用户名
                Text(
                  displayUser.username,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                // 在线状态
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OnlineStatusIndicator(
                      isOnline: displayUser.isOnline,
                      size: 10,
                      onlineColor: Colors.lightGreenAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      displayUser.isOnline ? '在线' : '离线',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 个人信息卡片
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '基本信息',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  _buildInfoItem(
                    context,
                    icon: Icons.email,
                    title: '邮箱',
                    value: displayUser.email,
                  ),
                  if (isSelf && isTabView) ...[
                    const SizedBox(height: 8),
                    _buildActionItem(
                      context,
                      icon: Icons.edit,
                      title: '编辑个人资料',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => EditProfileScreen(user: displayUser),
                          ),
                        ).then((_) {
                          // 刷新页面以显示更新后的数据
                          Provider.of<AuthProvider>(context, listen: false).refreshUserProfile();
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 功能卡片
          if (isSelf && isTabView)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildActionItem(
                      context,
                      icon: Icons.lock,
                      title: '修改密码',
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.changePassword);
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionItem(
                      context,
                      icon: Icons.notifications,
                      title: '通知设置',
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.notificationSettings);
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionItem(
                      context,
                      icon: Icons.qr_code,
                      title: '我的二维码',
                      onTap: () {
                        _showQrCode(context, displayUser);
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionItem(
                      context,
                      icon: Icons.color_lens,
                      title: '主题设置',
                      onTap: () {
                        // 实现主题设置功能
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('主题设置功能开发中')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // 退出登录按钮
          if (isSelf && isTabView)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  _showLogoutConfirmation(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('退出登录'),
              ),
            ),
          
          // 操作按钮
          if (!isSelf) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.message),
                      label: const Text('发送消息'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        // 返回到聊天界面
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  
                  if (isContact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        label: const Text('删除联系人', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          _showDeleteConfirmation(context, displayUser);
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_add, color: Colors.green),
                        label: const Text('添加联系人', style: TextStyle(color: Colors.green)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          _showAddConfirmation(context, displayUser);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          // 底部空间
          const SizedBox(height: 30),
        ],
      ),
    );
    
    return Scaffold(
      appBar: isTabView ? null : AppBar(
        title: Text(isSelf ? '我的资料' : '用户资料'),
        actions: [
          if (isSelf && !isTabView)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => EditProfileScreen(user: displayUser),
                  ),
                ).then((_) {
                  // 刷新页面以显示更新后的数据
                  Provider.of<AuthProvider>(context, listen: false).refreshUserProfile();
                });
              },
            ),
        ],
      ),
      body: content,
    );
  }
  
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).primaryColor,
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
  
  void _showQrCode(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('我的二维码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              color: Colors.grey[200],
              child: Center(
                child: Text(
                  'ID: ${user.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.username,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 执行退出登录操作
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.logout();
              Navigator.of(context).pushReplacementNamed(AppRoutes.login);
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定要删除联系人 ${user.username} 吗？'),
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
              contactProvider.removeContact(user.id).then((_) {
                Navigator.of(context).pop(); // 返回联系人列表
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除联系人 ${user.username}')),
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

  void _showAddConfirmation(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加联系人'),
        content: Text('确定要添加 ${user.username} 为联系人吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 执行添加联系人操作
              final contactProvider = Provider.of<ContactProvider>(context, listen: false);
              contactProvider.addContact(user.id).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加 ${user.username} 为联系人')),
                );
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('添加联系人失败: $error')),
                );
              });
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
} 