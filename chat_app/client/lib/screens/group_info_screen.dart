import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/custom_button.dart';
import '../utils/app_routes.dart';

class GroupInfoScreen extends StatefulWidget {
  final Group group;

  const GroupInfoScreen({Key? key, required this.group}) : super(key: key);

  @override
  _GroupInfoScreenState createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _announcementController = TextEditingController();
  bool _isEditing = false;
  File? _avatarFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController.text = widget.group.name;
    _announcementController.text = widget.group.announcement ?? '';

    // 加载群组成员
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupProvider>(context, listen: false).setCurrentGroup(widget.group);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _announcementController.dispose();
    super.dispose();
  }

  // 选择头像
  Future<void> _pickImage() async {
    if (!_isEditing) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }

  // 切换编辑模式
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // 取消编辑，恢复原始值
        _nameController.text = widget.group.name;
        _announcementController.text = widget.group.announcement ?? '';
        _avatarFile = null;
      }
    });
  }

  // 保存群组信息
  Future<void> _saveGroupInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final success = await groupProvider.updateGroupInfo(
        groupId: widget.group.id,
        name: _nameController.text.trim(),
        announcement: _announcementController.text.trim(),
        avatarFile: _avatarFile,
      );

      if (success) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('群组信息更新成功')),
        );
      } else {
        throw Exception('更新群组信息失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新群组信息失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 退出群组
  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出群组'),
        content: const Text('确定要退出该群组吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final success = await groupProvider.leaveGroup(widget.group.id);

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pop(true); // 返回true表示已退出群组
      } else {
        throw Exception('退出群组失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('退出群组失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 解散群组
  Future<void> _disbandGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解散群组'),
        content: const Text('确定要解散该群组吗？此操作不可撤销！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final success = await groupProvider.disbandGroup(widget.group.id);

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pop(true); // 返回true表示已解散群组
      } else {
        throw Exception('解散群组失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解散群组失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 邀请成员
  void _inviteMembers() {
    // 跳转到联系人选择页面
    Navigator.of(context).pushNamed(
      AppRoutes.contacts,
      arguments: {
        'selectionMode': true,
        'title': '邀请成员',
        'onContactsSelected': (List<User> selectedContacts) async {
          if (selectedContacts.isEmpty) return;
          
          setState(() {
            _isLoading = true;
          });
          
          try {
            final groupProvider = Provider.of<GroupProvider>(context, listen: false);
            final userIds = selectedContacts.map((contact) => contact.id).toList();
            
            final success = await groupProvider.inviteMembers(widget.group.id, userIds);
            
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('邀请已发送')),
              );
            } else {
              throw Exception('邀请成员失败');
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('邀请成员失败: $e')),
            );
          } finally {
            setState(() {
              _isLoading = false;
            });
          }
        },
      },
    );
  }

  // 移除成员
  Future<void> _removeMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要将 ${member.user.username} 移出群组吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final success = await groupProvider.removeMember(widget.group.id, int.parse(member.user.id.toString()));

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将 ${member.user.username} 移出群组')),
        );
      } else {
        throw Exception('移除成员失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移除成员失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 设置/取消管理员
  Future<void> _toggleAdmin(GroupMember member) async {
    final isAdmin = member.role == GroupMemberRole.admin;
    final action = isAdmin ? '取消' : '设置';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action}管理员'),
        content: Text('确定要${action} ${member.user.username} 的管理员权限吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final success = await groupProvider.setAdmin(
        widget.group.id,
        int.parse(member.user.id.toString()),
        !isAdmin,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已${action} ${member.user.username} 的管理员权限')),
        );
      } else {
        throw Exception('${action}管理员失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action}管理员失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = Provider.of<GroupProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;
    
    final group = groupProvider.currentGroup ?? widget.group;
    final members = groupProvider.currentGroupMembers;
    final isLoading = groupProvider.isLoading || _isLoading;
    
    // 检查当前用户是否为群主或管理员
    final isOwner = currentUser != null && group.isOwner(currentUser.id.toString());
    final isAdmin = currentUser != null && group.isAdmin(currentUser.id.toString());
    final canEdit = isOwner || isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('群组信息'),
        actions: [
          if (canEdit && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleEditMode,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '群组信息'),
            Tab(text: '成员管理'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 群组信息标签页
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 群组头像
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              _avatarFile != null
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundImage: FileImage(_avatarFile!),
                                    )
                                  : AvatarWidget(
                                      avatarUrl: group.avatarUrl,
                                      name: group.name,
                                      radius: 50,
                                    ),
                              if (_isEditing)
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
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 群组名称
                      _buildInfoField(
                        title: '群组名称',
                        value: group.name,
                        controller: _nameController,
                        isEditing: _isEditing,
                        icon: Icons.group,
                      ),
                      const SizedBox(height: 16),

                      // 群组ID
                      _buildInfoField(
                        title: '群组ID',
                        value: group.id,
                        isEditing: false,
                        icon: Icons.tag,
                      ),
                      const SizedBox(height: 16),

                      // 创建时间
                      _buildInfoField(
                        title: '创建时间',
                        value: group.formattedCreatedAt,
                        isEditing: false,
                        icon: Icons.calendar_today,
                      ),
                      const SizedBox(height: 16),

                      // 群组公告
                      _buildInfoField(
                        title: '群组公告',
                        value: group.announcement ?? '暂无公告',
                        controller: _announcementController,
                        isEditing: _isEditing,
                        icon: Icons.campaign,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 24),

                      // 保存按钮
                      if (_isEditing)
                        CustomButton(
                          onPressed: _saveGroupInfo,
                          text: '保存修改',
                          isLoading: _isLoading,
                        ),

                      const SizedBox(height: 24),

                      // 退出/解散群组
                      if (!_isEditing)
                        CustomButton(
                          onPressed: isOwner ? _disbandGroup : _leaveGroup,
                          text: isOwner ? '解散群组' : '退出群组',
                          backgroundColor: Colors.red,
                          isLoading: _isLoading,
                        ),
                    ],
                  ),
                ),

                // 成员管理标签页
                Column(
                  children: [
                    // 成员数量和邀请按钮
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '成员 (${members.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (canEdit)
                            ElevatedButton.icon(
                              onPressed: _inviteMembers,
                              icon: const Icon(Icons.person_add),
                              label: const Text('邀请'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 成员列表
                    Expanded(
                      child: members.isEmpty
                          ? const Center(child: Text('暂无成员'))
                          : ListView.builder(
                              itemCount: members.length,
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final isCurrentUser = currentUser != null && 
                                    member.user.id.toString() == currentUser.id.toString();
                                
                                // 角色标签
                                String roleText;
                                Color roleColor;
                                switch (member.role) {
                                  case GroupMemberRole.owner:
                                    roleText = '群主';
                                    roleColor = Colors.red;
                                    break;
                                  case GroupMemberRole.admin:
                                    roleText = '管理员';
                                    roleColor = Colors.blue;
                                    break;
                                  case GroupMemberRole.member:
                                  default:
                                    roleText = '成员';
                                    roleColor = Colors.grey;
                                }

                                return ListTile(
                                  leading: AvatarWidget(
                                    avatarUrl: member.user.avatarUrl,
                                    name: member.user.username,
                                    radius: 20,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(member.user.username),
                                      if (isCurrentUser)
                                        const Text(' (我)', style: TextStyle(color: Colors.grey)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: roleColor),
                                        ),
                                        child: Text(
                                          roleText,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: roleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text('加入时间: ${member.formattedJoinedAt}'),
                                  trailing: canEdit && !isCurrentUser && member.role != GroupMemberRole.owner
                                      ? PopupMenuButton<String>(
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'remove':
                                                _removeMember(member);
                                                break;
                                              case 'admin':
                                                _toggleAdmin(member);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            if (isOwner && member.role != GroupMemberRole.owner)
                                              PopupMenuItem(
                                                value: 'admin',
                                                child: Text(
                                                  member.role == GroupMemberRole.admin
                                                      ? '取消管理员'
                                                      : '设为管理员',
                                                ),
                                              ),
                                            if ((isOwner || (isAdmin && member.role == GroupMemberRole.member)) &&
                                                member.role != GroupMemberRole.owner)
                                              const PopupMenuItem(
                                                value: 'remove',
                                                child: Text('移出群组'),
                                              ),
                                          ],
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildInfoField({
    required String title,
    required String value,
    TextEditingController? controller,
    required bool isEditing,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isEditing && controller != null)
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
      ],
    );
  }
} 