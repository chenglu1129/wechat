import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friend_request.dart';
import '../providers/friend_request_provider.dart';
import '../providers/contact_provider.dart';
import '../widgets/friend_request_item.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  _FriendRequestsScreenState createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriendRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final requestProvider = Provider.of<FriendRequestProvider>(context, listen: false);
      await requestProvider.loadPendingRequests();
      await requestProvider.loadAllRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载好友请求失败: $e')),
        );
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
      appBar: AppBar(
        title: const Text('好友请求'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '待处理'),
            Tab(text: '历史记录'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingRequestsList(),
                _buildAllRequestsList(),
              ],
            ),
    );
  }

  Widget _buildPendingRequestsList() {
    return Consumer<FriendRequestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '加载失败: ${provider.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadFriendRequests,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (provider.pendingRequests.isEmpty) {
          return const Center(
            child: Text('没有待处理的好友请求'),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadPendingRequests(),
          child: ListView.builder(
            itemCount: provider.pendingRequests.length,
            itemBuilder: (ctx, index) {
              final request = provider.pendingRequests[index];
              return FriendRequestItem(
                request: request,
                onAccept: () => _acceptRequest(request),
                onReject: () => _rejectRequest(request),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAllRequestsList() {
    return Consumer<FriendRequestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '加载失败: ${provider.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadFriendRequests,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (provider.allRequests.isEmpty) {
          return const Center(
            child: Text('没有好友请求历史记录'),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadAllRequests(),
          child: ListView.builder(
            itemCount: provider.allRequests.length,
            itemBuilder: (ctx, index) {
              final request = provider.allRequests[index];
              return FriendRequestItem(
                request: request,
                onAccept: request.isPending ? () => _acceptRequest(request) : null,
                onReject: request.isPending ? () => _rejectRequest(request) : null,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      final requestProvider = Provider.of<FriendRequestProvider>(context, listen: false);
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      
      // 接受好友请求
      final success = await requestProvider.acceptRequest(request.id);
      
      if (success && mounted) {
        // 刷新联系人列表
        await contactProvider.loadContacts();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${request.sender.username} 为好友')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('接受好友请求失败: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    try {
      final requestProvider = Provider.of<FriendRequestProvider>(context, listen: false);
      
      // 拒绝好友请求
      final success = await requestProvider.rejectRequest(request.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已拒绝 ${request.sender.username} 的好友请求')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拒绝好友请求失败: $e')),
        );
      }
    }
  }
} 