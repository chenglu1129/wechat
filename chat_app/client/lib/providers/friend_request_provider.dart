import 'package:flutter/material.dart';

import '../models/friend_request.dart';
import '../services/friend_request_service.dart';

class FriendRequestProvider with ChangeNotifier {
  final FriendRequestService _friendRequestService;
  
  List<FriendRequest> _pendingRequests = [];
  List<FriendRequest> _allRequests = [];
  bool _isLoading = false;
  String? _error;
  
  FriendRequestProvider({required FriendRequestService friendRequestService})
      : _friendRequestService = friendRequestService;
  
  // Getters
  List<FriendRequest> get pendingRequests => _pendingRequests;
  List<FriendRequest> get allRequests => _allRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // 加载待处理的好友请求
  Future<void> loadPendingRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final requests = await _friendRequestService.getPendingRequests();
      _pendingRequests = requests;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 加载所有好友请求历史
  Future<void> loadAllRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final requests = await _friendRequestService.getAllRequests();
      _allRequests = requests;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 发送好友请求
  Future<bool> sendRequest(int receiverId, String message) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final request = await _friendRequestService.sendRequest(receiverId, message);
      
      // 添加到历史记录
      _allRequests = [request, ..._allRequests];
      
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // 接受好友请求
  Future<bool> acceptRequest(int requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _friendRequestService.acceptRequest(requestId);
      
      // 更新请求状态
      _updateRequestStatus(requestId, FriendRequestStatus.accepted);
      
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // 拒绝好友请求
  Future<bool> rejectRequest(int requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _friendRequestService.rejectRequest(requestId);
      
      // 更新请求状态
      _updateRequestStatus(requestId, FriendRequestStatus.rejected);
      
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // 取消好友请求
  Future<bool> cancelRequest(int requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _friendRequestService.cancelRequest(requestId);
      
      // 从列表中删除
      _pendingRequests.removeWhere((request) => request.id == requestId);
      _allRequests.removeWhere((request) => request.id == requestId);
      
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // 更新请求状态
  void _updateRequestStatus(int requestId, FriendRequestStatus status) {
    // 找到对应请求
    final pendingIndex = _pendingRequests.indexWhere((request) => request.id == requestId);
    final allIndex = _allRequests.indexWhere((request) => request.id == requestId);
    
    // 如果状态不是待处理，从待处理列表中移除
    if (pendingIndex >= 0 && status != FriendRequestStatus.pending) {
      _pendingRequests.removeAt(pendingIndex);
    }
    
    // 更新全部请求列表中的状态
    if (allIndex >= 0) {
      final request = _allRequests[allIndex];
      final updatedRequest = FriendRequest(
        id: request.id,
        sender: request.sender,
        receiver: request.receiver,
        message: request.message,
        status: status,
        createdAt: request.createdAt,
        updatedAt: DateTime.now(),
      );
      _allRequests[allIndex] = updatedRequest;
    }
  }
  
  // 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 