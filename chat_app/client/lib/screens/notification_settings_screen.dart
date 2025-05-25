import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;
  
  // 通知设置
  late bool _notificationsEnabled;
  late bool _soundEnabled;
  late bool _vibrationEnabled;
  
  @override
  void initState() {
    super.initState();
    _notificationsEnabled = _notificationService.isNotificationsEnabled;
    _soundEnabled = _notificationService.isSoundEnabled;
    _vibrationEnabled = _notificationService.isVibrationEnabled;
  }
  
  // 保存设置
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _notificationService.setNotificationsEnabled(_notificationsEnabled);
      await _notificationService.setSoundEnabled(_soundEnabled);
      await _notificationService.setVibrationEnabled(_vibrationEnabled);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知设置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存设置失败: $e')),
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
  
  // 发送测试通知
  Future<void> _sendTestNotification() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 给自己发送测试通知
      await _notificationService.showChatMessageNotification(
        senderId: 0, // 使用0表示系统消息
        senderName: '系统通知',
        message: '这是一条测试通知，发送时间: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('测试通知已发送')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送测试通知失败: $e')),
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
        title: const Text('通知设置'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveSettings,
                  tooltip: '保存设置',
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 通知开关
            SwitchListTile(
              title: const Text('启用通知'),
              subtitle: const Text('接收新消息和其他活动的通知'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                  
                  // 如果禁用通知，同时禁用声音和振动
                  if (!value) {
                    _soundEnabled = false;
                    _vibrationEnabled = false;
                  }
                });
              },
              secondary: Icon(
                _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                color: _notificationsEnabled ? Theme.of(context).primaryColor : Colors.grey,
              ),
            ),
            
            const Divider(),
            
            // 声音设置
            SwitchListTile(
              title: const Text('通知声音'),
              subtitle: const Text('收到通知时播放声音'),
              value: _soundEnabled,
              onChanged: _notificationsEnabled
                  ? (value) {
                      setState(() {
                        _soundEnabled = value;
                      });
                    }
                  : null,
              secondary: Icon(
                _soundEnabled ? Icons.volume_up : Icons.volume_off,
                color: _notificationsEnabled && _soundEnabled
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ),
            
            // 振动设置
            SwitchListTile(
              title: const Text('通知振动'),
              subtitle: const Text('收到通知时振动'),
              value: _vibrationEnabled,
              onChanged: _notificationsEnabled
                  ? (value) {
                      setState(() {
                        _vibrationEnabled = value;
                      });
                    }
                  : null,
              secondary: Icon(
                _vibrationEnabled ? Icons.vibration : Icons.do_not_disturb_on,
                color: _notificationsEnabled && _vibrationEnabled
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ),
            
            const Divider(),
            
            // 测试通知按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('发送测试通知'),
                  onPressed: _notificationsEnabled ? _sendTestNotification : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ),
            
            // 通知说明
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '通知类型',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• 聊天消息: 当您收到新消息时'),
                  Text('• 好友请求: 当有人请求添加您为好友时'),
                  Text('• 联系人更新: 当有人接受您的好友请求时'),
                  SizedBox(height: 16),
                  Text(
                    '注意事项',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• 您需要在设备设置中允许应用发送通知'),
                  Text('• 您可能需要在特定聊天中单独设置消息通知'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 