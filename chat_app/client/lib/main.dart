import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/friend_requests_screen.dart';
import 'screens/change_password_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/friend_request_provider.dart';
import 'services/contact_service.dart';
import 'services/friend_request_service.dart';
import 'utils/app_routes.dart';
import 'utils/token_manager.dart';
import 'models/user.dart';

void main() {
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
    
    // 监听登录状态变化，连接/断开WebSocket
    authProvider.addListener(() {
      if (authProvider.isAuthenticated && authProvider.user != null) {
        // 登录成功，连接WebSocket
        chatProvider.connectWebSocket(
          authProvider.token!,
          authProvider.user!.id.toString(),
        );
      } else {
        // 登出，断开WebSocket
        chatProvider.disconnectWebSocket();
      }
    });
    
    // 设置用户状态变化回调
    chatProvider.onUserStatusChanged = (userId, isOnline) {
      // 更新联系人在线状态
      contactProvider.updateContactStatus(userId, isOnline);
    };
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => chatProvider),
        ChangeNotifierProvider(create: (_) => contactProvider),
        ChangeNotifierProvider(create: (_) => friendRequestProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '聊天应用',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
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