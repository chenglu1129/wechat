import 'user.dart';

class ContactList {
  final List<User> contacts;
  
  ContactList({
    required this.contacts,
  });
  
  // 从JSON列表创建联系人列表
  factory ContactList.fromJson(List<dynamic> json) {
    try {
      final contacts = json
          .where((item) => item != null) // 过滤null项
          .map((contactJson) {
            try {
              return User.fromJson(contactJson);
            } catch (e) {
              // 如果单个用户解析失败，跳过该用户
              return null;
            }
          })
          .where((user) => user != null) // 过滤解析失败的用户
          .cast<User>() // 转换为User类型
          .toList();
      return ContactList(contacts: contacts);
    } catch (e) {
      // 如果解析过程中出现任何错误，返回空列表
      return ContactList(contacts: []);
    }
  }
  
  // 添加联系人
  ContactList addContact(User contact) {
    final updatedContacts = List<User>.from(contacts);
    // 检查是否已存在
    if (!updatedContacts.any((c) => c.id == contact.id)) {
      updatedContacts.add(contact);
    }
    return ContactList(contacts: updatedContacts);
  }
  
  // 移除联系人
  ContactList removeContact(int contactId) {
    final updatedContacts = contacts.where((c) => c.id != contactId).toList();
    return ContactList(contacts: updatedContacts);
  }
  
  // 获取联系人索引
  int indexOfContact(int contactId) {
    return contacts.indexWhere((c) => c.id == contactId);
  }
  
  // 检查是否为联系人
  bool isContact(int userId) {
    return contacts.any((c) => c.id == userId);
  }
  
  // 更新联系人状态
  ContactList updateContactStatus(int contactId, bool isOnline) {
    final updatedContacts = List<User>.from(contacts);
    final index = indexOfContact(contactId);
    if (index != -1) {
      updatedContacts[index] = updatedContacts[index].copyWith(isOnline: isOnline);
    }
    return ContactList(contacts: updatedContacts);
  }
  
  // 按用户名排序
  ContactList sortByUsername({bool ascending = true}) {
    final sortedContacts = List<User>.from(contacts);
    sortedContacts.sort((a, b) => ascending
        ? a.username.toLowerCase().compareTo(b.username.toLowerCase())
        : b.username.toLowerCase().compareTo(a.username.toLowerCase()));
    return ContactList(contacts: sortedContacts);
  }
  
  // 按在线状态排序
  ContactList sortByOnlineStatus({bool onlineFirst = true}) {
    final sortedContacts = List<User>.from(contacts);
    sortedContacts.sort((a, b) {
      if (a.isOnline == b.isOnline) {
        // 如果在线状态相同，按用户名排序
        return a.username.toLowerCase().compareTo(b.username.toLowerCase());
      }
      // 在线状态不同，根据onlineFirst决定排序
      return onlineFirst
          ? (a.isOnline ? -1 : 1)
          : (a.isOnline ? 1 : -1);
    });
    return ContactList(contacts: sortedContacts);
  }
  
  // 根据搜索关键字过滤
  ContactList filter(String keyword) {
    if (keyword.isEmpty) {
      return this;
    }
    
    final lowercaseKeyword = keyword.toLowerCase();
    final filteredContacts = contacts.where((contact) {
      return contact.username.toLowerCase().contains(lowercaseKeyword) ||
             contact.email.toLowerCase().contains(lowercaseKeyword);
    }).toList();
    
    return ContactList(contacts: filteredContacts);
  }
}

class SearchResult {
  final List<User> users;
  final int total;
  final bool hasMore;
  
  SearchResult({
    required this.users,
    required this.total,
    required this.hasMore,
  });
  
  // 从JSON创建搜索结果
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    try {
      List<User> usersList = [];
      
      if (json.containsKey('users') && json['users'] is List) {
        usersList = (json['users'] as List)
            .where((item) => item != null)
            .map((userJson) {
              try {
                return User.fromJson(userJson);
              } catch (e) {
                return null;
              }
            })
            .where((user) => user != null)
            .cast<User>()
            .toList();
      }
      
      return SearchResult(
        users: usersList,
        total: json['total'] ?? usersList.length,
        hasMore: json['has_more'] ?? false,
      );
    } catch (e) {
      // 如果解析过程中出现任何错误，返回空结果
      return SearchResult(users: [], total: 0, hasMore: false);
    }
  }
  
  // 合并搜索结果
  SearchResult merge(SearchResult other) {
    final mergedUsers = [...users, ...other.users];
    return SearchResult(
      users: mergedUsers,
      total: other.total,
      hasMore: other.hasMore,
    );
  }
} 