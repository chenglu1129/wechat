import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact.dart';
import '../models/user.dart';
import '../services/contact_service.dart';
import '../providers/auth_provider.dart';

class ContactProvider with ChangeNotifier {
  final ContactService _contactService;
  
  ContactList _contacts = ContactList(contacts: []);
  bool _isLoading = false;
  String? _error;
  
  // 搜索结果
  SearchResult? _searchResult;
  bool _isSearching = false;
  String? _searchError;
  
  // 过滤和排序
  String _filterKeyword = '';
  SortOption _sortOption = SortOption.nameAsc;
  
  ContactProvider({required ContactService contactService})
      : _contactService = contactService;
  
  // Getters
  ContactList get contacts {
    // 应用过滤和排序
    ContactList filteredContacts = _contacts.filter(_filterKeyword);
    
    switch (_sortOption) {
      case SortOption.nameAsc:
        return filteredContacts.sortByUsername(ascending: true);
      case SortOption.nameDesc:
        return filteredContacts.sortByUsername(ascending: false);
      case SortOption.onlineFirst:
        return filteredContacts.sortByOnlineStatus(onlineFirst: true);
      case SortOption.offlineFirst:
        return filteredContacts.sortByOnlineStatus(onlineFirst: false);
    }
  }
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  SearchResult? get searchResult => _searchResult;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  String get filterKeyword => _filterKeyword;
  SortOption get sortOption => _sortOption;
  
  // 设置过滤关键字
  void setFilterKeyword(String keyword) {
    _filterKeyword = keyword;
    notifyListeners();
  }
  
  // 设置排序选项
  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }
  
  // 加载联系人
  Future<void> loadContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final contacts = await _contactService.getContacts();
      _contacts = contacts;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 添加联系人
  Future<void> addContact(int contactId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _contactService.addContact(contactId);
      await loadContacts(); // 重新加载联系人列表
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 删除联系人
  Future<void> removeContact(int contactId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _contactService.removeContact(contactId);
      // 从本地列表中删除
      _contacts = _contacts.removeContact(contactId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 搜索用户
  Future<void> searchUsers(String query, {int offset = 0, int limit = 20, bool reset = true}) async {
    if (query.trim().isEmpty) {
      _searchResult = SearchResult(users: [], total: 0, hasMore: false);
      _searchError = null;
      _isSearching = false;
      notifyListeners();
      return;
    }
    
    _isSearching = true;
    _searchError = null;
    if (reset) {
      _searchResult = null;
    }
    notifyListeners();
    
    try {
      final result = await _contactService.searchUsers(query, offset: offset, limit: limit);
      
      if (_searchResult != null && !reset) {
        // 合并结果
        _searchResult = _searchResult!.merge(result);
      } else {
        _searchResult = result;
      }
      _searchError = null;
    } catch (e) {
      _searchError = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
  
  // 清除搜索结果
  void clearSearchResults() {
    _searchResult = null;
    _searchError = null;
    _isSearching = false;
    notifyListeners();
  }
  
  // 更新联系人在线状态
  void updateContactStatus(int contactId, bool isOnline) {
    if (_contacts.isContact(contactId)) {
      _contacts = _contacts.updateContactStatus(contactId, isOnline);
      notifyListeners();
    }
  }
  
  // 批量更新联系人在线状态
  void updateContactsStatus(Map<int, bool> statusMap) {
    bool updated = false;
    ContactList updatedContacts = _contacts;
    
    statusMap.forEach((userId, isOnline) {
      if (updatedContacts.isContact(userId)) {
        updatedContacts = updatedContacts.updateContactStatus(userId, isOnline);
        updated = true;
      }
    });
    
    if (updated) {
      _contacts = updatedContacts;
      notifyListeners();
    }
  }
  
  // 检查是否为联系人
  bool isContact(int userId) {
    return _contacts.isContact(userId);
  }
  
  // 获取联系人
  User? getContact(int userId) {
    final index = _contacts.indexOfContact(userId);
    if (index != -1) {
      return _contacts.contacts[index];
    }
    return null;
  }
  
  // 获取当前用户名（用于好友请求）
  String get currentUserName {
    // 这里不能直接访问AuthProvider，所以返回默认值
    // 在实际使用时需要在界面上下文中获取AuthProvider
    return '用户';
  }
}

// 排序选项枚举
enum SortOption {
  nameAsc,      // 按用户名升序
  nameDesc,     // 按用户名降序
  onlineFirst,  // 在线优先
  offlineFirst, // 离线优先
} 