import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      final success = await authProvider.register(
        _usernameController.text,
        _emailController.text,
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
                '注册账号',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 40),
              
              // 注册表单
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 用户名输入框
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入用户名';
                        }
                        if (value.length < 3) {
                          return '用户名至少需要3个字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // 邮箱输入框
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入邮箱';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return '请输入有效的邮箱地址';
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
                        if (value.length < 6) {
                          return '密码至少需要6个字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // 确认密码输入框
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: '确认密码',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请确认密码';
                        }
                        if (value != _passwordController.text) {
                          return '两次输入的密码不一致';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    
                    // 注册按钮
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('注册'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 登录链接
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                      },
                      child: const Text('已有账号？立即登录'),
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