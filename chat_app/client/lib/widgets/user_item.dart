import 'package:flutter/material.dart';
import '../models/user.dart';

class UserItem extends StatelessWidget {
  final User user;
  final bool isContact;
  final VoidCallback? onAddContact;
  final VoidCallback? onRemoveContact;
  final VoidCallback? onTap;
  
  const UserItem({
    Key? key,
    required this.user,
    this.isContact = false,
    this.onAddContact,
    this.onRemoveContact,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
            ? Text(user.username.substring(0, 1).toUpperCase())
            : null,
      ),
      title: Text(user.username),
      subtitle: Text(user.email),
      trailing: isContact
          ? onRemoveContact != null
              ? IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.red),
                  onPressed: onRemoveContact,
                )
              : const Icon(Icons.check_circle, color: Colors.green)
          : onAddContact != null
              ? IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.blue),
                  onPressed: onAddContact,
                )
              : null,
      onTap: onTap,
    );
  }
} 