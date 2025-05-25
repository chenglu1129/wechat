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
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/friend_request_provider.dart';
import 'services/contact_service.dart';
import 'services/friend_request_service.dart';
import 'services/notification_service.dart';
import 'services/media_service.dart';
import 'utils/app_routes.dart';
import 'utils/token_manager.dart';
import 'models/user.dart';

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
    final authProvider = AuthProvider(tokenManager: tokenManager);
    final chatProvider = ChatProvider();
    final contactProvider = ContactProvider(contactService: contactService);
    final friendRequestProvider = FriendRequestProvider(friendRequestService: friendRequestService);
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
              AppRoutes.home: (context) => const HomeScreen(),
              AppRoutes.contacts: (context) => const ContactsScreen(),
              AppRoutes.profile: (context) => const ProfileScreen(),
              AppRoutes.friendRequests: (context) => const FriendRequestsScreen(),
              AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
              AppRoutes.notificationSettings: (context) => const NotificationSettingsScreen(),
            },
            // 处理命名路由中传递复杂参数
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.chat) {
                // 处理聊天路由
                final args = settings.arguments as Map<String, dynamic>;
                final user = args['user'] as User;
                return MaterialPageRoute(
                  builder: (context) => ChatScreen(user: user),
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
              }
              return null;
            },
          );
        },
      ),
    );
  }
} 