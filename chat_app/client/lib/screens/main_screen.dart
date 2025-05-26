import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../utils/app_routes.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const HomeScreen(),
    const ContactsScreen(),
    const ProfileScreen(),
  ];
  
  final List<String> _titles = ['聊天', '联系人', '我的'];
  
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
      print('用户已登录，ID: ${authProvider.user!.id}，加载聊天列表和连接WebSocket');
      
      try {
        // 连接WebSocket
        chatProvider.connectWebSocket(
          authProvider.token!,
          authProvider.user!.id.toString(),
        );
        
        // 加载聊天列表
        await _loadChats();
        
        // 加载群组列表
        print('开始加载群组列表...');
        await groupProvider.loadUserGroups();
        print('群组列表加载完成，共${groupProvider.groups.length}个群组');
        for (var group in groupProvider.groups) {
          print('群组: ID=${group.id}, 名称=${group.name}, 成员数=${group.memberCount}');
        }
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
    // 断开WebSocket连接
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.disconnectWebSocket();
    
    super.dispose();
  }

  Future<void> _loadChats() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取未读消息数量
    final chatProvider = Provider.of<ChatProvider>(context);
    final unreadCount = chatProvider.chats
        .fold(0, (sum, chat) => sum + chat.unreadCount);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (unreadCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.chat_bubble),
            label: '聊天',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: '联系人',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
} 