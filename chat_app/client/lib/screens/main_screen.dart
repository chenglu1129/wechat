import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../providers/contact_provider.dart';
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
  bool _isInitializing = false;
  late AuthProvider _authProvider;
  late ChatProvider _chatProvider;
  late ContactProvider _contactProvider;
  
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
      _initializeProviders();
      _initializeApp();
    });
  }
  
  void _initializeProviders() {
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _contactProvider = Provider.of<ContactProvider>(context, listen: false);
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      // 获取token
      final token = await _authProvider.token;
      if (token == null) {
        // 如果没有token，导航到登录页面
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // 加载用户信息
      await _authProvider.refreshUserProfile();
      
      // 确保用户ID有效
      if (_authProvider.user == null || _authProvider.user!.id <= 0) {
        print('用户信息无效，无法初始化WebSocket');
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      
      // 连接WebSocket
      _chatProvider.connectWebSocket(
        token,
        _authProvider.user!.id.toString(),
      );
      print('WebSocket已连接，用户ID: ${_authProvider.user!.id}');
      
      // 加载联系人列表
      await _contactProvider.loadContacts();
      
      // 加载聊天列表
      await _chatProvider.loadChats(token);
      
      // 如果有聊天记录，自动切换到聊天Tab
      if (_chatProvider.chats.isNotEmpty) {
        setState(() {
          _currentIndex = 0; // 聊天Tab的索引
        });
        print('找到${_chatProvider.chats.length}个聊天记录，自动切换到聊天Tab');
      }
      
    } catch (e) {
      print('初始化应用时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载数据时出错，请稍后再试')),
      );
    } finally {
      setState(() {
        _isInitializing = false;
      });
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