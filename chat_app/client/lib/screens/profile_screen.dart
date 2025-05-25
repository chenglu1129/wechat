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
  
  const ProfileScreen({
    Key? key,
    this.user,
    this.isContact = false,
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
        appBar: AppBar(
          title: const Text('用户资料'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? '我的资料' : '用户资料'),
        actions: [
          if (isSelf)
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
      body: SingleChildScrollView(
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
              padding: const EdgeInsets.only(top: 30, bottom: 40),
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
                  ],
                ),
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
            ] else ...[
              // 如果是自己的资料，显示修改密码和退出登录按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.lock),
                      label: const Text('修改密码'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.changePassword);
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('退出登录'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: () {
                        _showLogoutConfirmation(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
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
        content: Text('确定要删除 ${user.username} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // 显示加载指示器
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在删除联系人...')),
              );
              
              // 调用ContactProvider删除联系人
              try {
                await Provider.of<ContactProvider>(context, listen: false).removeContact(user.id);
                
                if (context.mounted) {
                  // 显示成功消息
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已从联系人中删除 ${user.username}')),
                  );
                  // 返回到上一页
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除联系人失败: $e')),
                  );
                }
              }
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // 显示加载指示器
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在添加联系人...')),
              );
              
              // 调用ContactProvider添加联系人
              try {
                await Provider.of<ContactProvider>(context, listen: false).addContact(user.id);
                
                if (context.mounted) {
                  // 显示成功消息
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加 ${user.username} 为联系人')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加联系人失败: $e')),
                  );
                }
              }
            },
            child: const Text('添加'),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 实现退出登录的逻辑
              Provider.of<AuthProvider>(context, listen: false).logout();
              // 返回到登录页
              Navigator.of(context).pushReplacementNamed(AppRoutes.login);
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 