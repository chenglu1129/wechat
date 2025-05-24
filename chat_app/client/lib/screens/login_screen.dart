import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
              
              // 登录表单
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 用户名/邮箱输入框
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名或邮箱',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入用户名或邮箱';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // 密码输入框
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    
                    // 登录按钮
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('登录'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 注册链接
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.register);
                      },
                      child: const Text('没有账号？立即注册'),
                    ),
                  ],
                ),
              ),
              
              // 错误消息
              Consumer<AuthProvider>(
                builder: (ctx, authProvider, _) {
                  if (authProvider.error != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        authProvider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 