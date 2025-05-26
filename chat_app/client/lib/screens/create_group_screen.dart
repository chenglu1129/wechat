import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user.dart';
import '../models/contact.dart';
import '../models/group.dart';
import '../providers/group_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/custom_button.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  File? _avatarFile;
  final Set<User> _selectedContacts = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 加载联系人列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactProvider>(context, listen: false).loadContacts();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 选择头像
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }

  // 切换联系人选择状态
  void _toggleContactSelection(User contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  // 创建群组
  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个联系人')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;
      
      if (currentUser == null) {
        throw Exception('未登录');
      }
      
      // 获取选中联系人的ID列表
      final memberIds = _selectedContacts.map((contact) => contact.id).toList();
      
      // 创建群组
      final group = await groupProvider.createGroup(
        name: _nameController.text.trim(),
        memberIds: memberIds,
        avatarFile: _avatarFile,
      );
      
      if (group != null) {
        if (!mounted) return;
        
        // 创建成功，跳转到群聊页面
        Navigator.of(context).pop(group);
      } else {
        throw Exception('创建群组失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建群组失败: $e')),
      );
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
    final contactProvider = Provider.of<ContactProvider>(context);
    final contactList = contactProvider.contacts;
    final isLoading = contactProvider.isLoading || _isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群组'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // 群组信息部分
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Theme.of(context).cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 群组头像
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _avatarFile != null
                                      ? FileImage(_avatarFile!)
                                      : null,
                                  child: _avatarFile == null
                                      ? const Icon(Icons.group, size: 40, color: Colors.grey)
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 群组名称
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: '群组名称',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.group),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入群组名称';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 已选择的联系人数量
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '选择联系人 (${_selectedContacts.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_selectedContacts.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedContacts.clear();
                              });
                            },
                            child: const Text('清除全部'),
                          ),
                      ],
                    ),
                  ),
                  
                  // 联系人列表
                  Expanded(
                    child: contactList.contacts.isEmpty
                        ? const Center(child: Text('没有联系人'))
                        : ListView.builder(
                            itemCount: contactList.contacts.length,
                            itemBuilder: (context, index) {
                              final contact = contactList.contacts[index];
                              final isSelected = _selectedContacts.contains(contact);
                              
                              return ListTile(
                                leading: AvatarWidget(
                                  avatarUrl: contact.avatarUrl,
                                  name: contact.username,
                                  radius: 20,
                                ),
                                title: Text(contact.username),
                                trailing: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleContactSelection(contact),
                                ),
                                onTap: () => _toggleContactSelection(contact),
                              );
                            },
                          ),
                  ),
                  
                  // 创建按钮
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CustomButton(
                      onPressed: _createGroup,
                      text: '创建群组',
                      isLoading: _isLoading,
                      disabled: _selectedContacts.isEmpty,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 