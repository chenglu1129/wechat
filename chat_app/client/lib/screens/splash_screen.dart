import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // 延迟2秒，然后检查认证状态
    Future.delayed(const Duration(seconds: 2), () {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.isAuthenticated) {
        // 已登录，跳转到主页
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else {
        // 未登录，跳转到登录页
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用图标
            Icon(
              Icons.chat,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            
            // 应用名称
            Text(
              '聊天应用',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 加载指示器
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
} 