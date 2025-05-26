import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/friend_requests_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/group_info_screen.dart';
import 'screens/main_screen.dart';
import 'screens/group_chat_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/friend_request_provider.dart';
import 'providers/group_provider.dart';
import 'services/contact_service.dart';
import 'services/friend_request_service.dart';
import 'services/notification_service.dart';
import 'services/media_service.dart';
import 'services/group_service.dart';
import 'utils/app_routes.dart';
import 'utils/token_manager.dart';
import 'models/user.dart';
import 'models/chat.dart';
import 'models/group.dart';

// 全局导航键，用于在通知服务中导航
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置屏幕方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 初始化通知服务
  await NotificationService().initialize();
  
  // 设置导航键
  NotificationService().setNavigatorKey(navigatorKey);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 创建共享的TokenManager实例
    final tokenManager = TokenManager();
    final contactService = ContactService(tokenManager: tokenManager);
    final friendRequestService = FriendRequestService(tokenManager: tokenManager);
    final groupService = GroupService(tokenManager: tokenManager);
    final authProvider = AuthProvider(tokenManager: tokenManager);
    final chatProvider = ChatProvider();
    final contactProvider = ContactProvider(contactService: contactService);
    final friendRequestProvider = FriendRequestProvider(friendRequestService: friendRequestService);
    final groupProvider = GroupProvider(groupService: groupService);
    final mediaService = MediaService(tokenManager: tokenManager);
    
    // 监听登录状态变化，连接/断开WebSocket
    authProvider.addListener(() async {
      if (authProvider.isAuthenticated && authProvider.user != null) {
        // 登录成功，连接WebSocket
        chatProvider.connectWebSocket(
          authProvider.token!,
          authProvider.user!.id.toString(),
        );
        
        // 获取FCM令牌并发送到服务器
        final fcmToken = await NotificationService().getFCMToken();
        if (fcmToken != null) {
          NotificationService().sendFCMTokenToServer(
            authProvider.user!.id.toString(),
            fcmToken,
          );
        }
        
        // 加载用户的群组列表
        groupProvider.loadUserGroups();
      } else {
        // 登出，断开WebSocket
        chatProvider.disconnectWebSocket();
        
        // 清除所有通知
        NotificationService().cancelAllNotifications();
      }
    });
    
    // 设置用户状态变化回调
    chatProvider.onUserStatusChanged = (userId, isOnline) {
      // 更新联系人在线状态
      contactProvider.updateContactStatus(userId, isOnline);
    };
    
    // 设置消息接收回调，用于显示通知
    chatProvider.onMessageReceived = (message) {
      // 简化处理：只在消息不是当前聊天窗口的时候显示通知
      final currentChatUserId = chatProvider.currentChatUserId;
      if (currentChatUserId == null || message.senderId != currentChatUserId.toString()) {
        // 显示本地通知
        if (message.senderName != null) {
          NotificationService().showChatMessageNotification(
            senderId: int.parse(message.senderId),
            senderName: message.senderName ?? "未知用户",
            senderAvatar: message.senderAvatar,
            message: message.content,
          );
        }
      }
    };
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => chatProvider),
        ChangeNotifierProvider(create: (_) => contactProvider),
        ChangeNotifierProvider(create: (_) => friendRequestProvider),
        ChangeNotifierProvider(create: (_) => groupProvider),
        Provider<MediaService>(create: (_) => mediaService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '聊天应用',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            // 设置全局导航键，用于通知导航
            navigatorKey: navigatorKey,
            initialRoute: AppRoutes.splash,
            routes: {
              AppRoutes.splash: (context) => const SplashScreen(),
              AppRoutes.login: (context) => const LoginScreen(),
              AppRoutes.register: (context) => const RegisterScreen(),
              AppRoutes.home: (context) => const MainScreen(),
              AppRoutes.contacts: (context) => const ContactsScreen(),
              AppRoutes.profile: (context) => const ProfileScreen(isTabView: false),
              AppRoutes.friendRequests: (context) => const FriendRequestsScreen(),
              AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
              AppRoutes.notificationSettings: (context) => const NotificationSettingsScreen(),
              AppRoutes.createGroup: (context) => const CreateGroupScreen(),
            },
            // 处理命名路由中传递复杂参数
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.chat) {
                // 处理聊天路由
                final args = settings.arguments;
                if (args is User) {
                  // 如果参数是User对象
                  return MaterialPageRoute(
                    builder: (context) => ChatScreen(user: args),
                  );
                } else if (args is Chat) {
                  // 如果参数是Chat对象
                  if (args.type == ChatType.private) {
                    // 私聊
                    final chatId = args.id;
                    final parts = chatId.split('_');
                    if (parts.length == 2 && parts[0] == 'private') {
                      final userId = int.tryParse(parts[1]);
                      if (userId != null) {
                        final tempUser = User(
                          id: userId,
                          username: args.name,
                          email: 'unknown@example.com', // 临时值
                          avatarUrl: args.avatarUrl,
                          isOnline: args.isOnline,
                        );
                        return MaterialPageRoute(
                          builder: (context) => ChatScreen(user: tempUser),
                        );
                      }
                    }
                  } else if (args.type == ChatType.group) {
                    // 群聊
                    final chatId = args.id;
                    final parts = chatId.split('_');
                    if (parts.length == 2 && parts[0] == 'group') {
                      final groupId = parts[1];
                      
                      // 从群组提供者中获取群组信息
                      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                      late Group group;
                      
                      try {
                        // 尝试从群组列表中查找群组
                        group = groupProvider.groups.firstWhere((g) => g.id == groupId);
                      } catch (e) {
                        // 如果找不到，创建一个临时群组对象
                        group = Group(
                          id: groupId,
                          name: args.name,
                          avatarUrl: args.avatarUrl,
                          ownerId: '0', // 临时值
                          adminIds: [],
                          createdAt: DateTime.now(),
                        );
                      }
                      
                      return MaterialPageRoute(
                        builder: (context) => GroupChatScreen(group: group),
                      );
                    }
                  }
                  // 如果无法解析聊天ID，显示错误页面
                  return MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('错误')),
                      body: const Center(
                        child: Text('无法打开聊天，无效的聊天ID'),
                      ),
                    ),
                  );
                } else if (args is Map<String, dynamic>) {
                  // 兼容旧的参数格式
                  final user = args['user'] as User;
                  return MaterialPageRoute(
                    builder: (context) => ChatScreen(user: user),
                  );
                }
                // 如果参数格式不正确，显示错误页面
                return MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('错误')),
                    body: const Center(
                      child: Text('无法打开聊天，参数格式不正确'),
                    ),
                  ),
                );
              } else if (settings.name == AppRoutes.profile) {
                // 处理资料页路由
                if (settings.arguments != null) {
                  final args = settings.arguments as Map<String, dynamic>;
                  final user = args['user'] as User;
                  final isContact = args['isContact'] as bool? ?? false;
                  return MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      user: user,
                      isContact: isContact,
                    ),
                  );
                } else {
                  // 如果没有参数，显示当前用户的资料
                  return MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  );
                }
              } else if (settings.name == AppRoutes.groupInfo) {
                // 处理群组信息页路由
                if (settings.arguments != null) {
                  final group = settings.arguments as Group;
                  return MaterialPageRoute(
                    builder: (context) => GroupInfoScreen(group: group),
                  );
                }
                // 如果没有参数，显示错误页面
                return MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('错误')),
                    body: const Center(
                      child: Text('无法打开群组信息，参数格式不正确'),
                    ),
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
} 