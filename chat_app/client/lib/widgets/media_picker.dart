import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/media_service.dart';

class MediaPicker extends StatelessWidget {
  final Function(MediaItem) onMediaSelected;
  final MediaService mediaService;
  
  const MediaPicker({
    Key? key,
    required this.onMediaSelected,
    required this.mediaService,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMediaButton(
            context,
            icon: Icons.camera_alt,
            label: '相机',
            onTap: () => _pickImage(context, ImageSource.camera),
          ),
          _buildMediaButton(
            context,
            icon: Icons.photo,
            label: '相册',
            onTap: () => _pickImage(context, ImageSource.gallery),
          ),
          _buildMediaButton(
            context,
            icon: Icons.videocam,
            label: '视频',
            onTap: () => _pickVideo(context),
          ),
          _buildMediaButton(
            context,
            icon: Icons.insert_drive_file,
            label: '文件',
            onTap: () => _pickFile(context),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMediaButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      // 显示加载指示器
      _showLoadingDialog(context);
      
      // 选择图片
      final mediaItem = await mediaService.pickImage(source: source);
      
      // 关闭加载指示器
      Navigator.pop(context);
      
      if (mediaItem != null) {
        onMediaSelected(mediaItem);
      }
    } catch (e) {
      // 关闭加载指示器
      Navigator.pop(context);
      
      // 显示错误
      _showErrorDialog(context, '选择图片失败：$e');
    }
  }
  
  Future<void> _pickVideo(BuildContext context) async {
    try {
      // 显示加载指示器
      _showLoadingDialog(context);
      
      // 选择视频
      final mediaItem = await mediaService.pickVideo(source: ImageSource.gallery);
      
      // 关闭加载指示器
      Navigator.pop(context);
      
      if (mediaItem != null) {
        onMediaSelected(mediaItem);
      }
    } catch (e) {
      // 关闭加载指示器
      Navigator.pop(context);
      
      // 显示错误
      _showErrorDialog(context, '选择视频失败：$e');
    }
  }
  
  Future<void> _pickFile(BuildContext context) async {
    try {
      // 显示加载指示器
      _showLoadingDialog(context);
      
      // 选择文件
      final mediaItem = await mediaService.pickFile();
      
      // 关闭加载指示器
      Navigator.pop(context);
      
      if (mediaItem != null) {
        onMediaSelected(mediaItem);
      }
    } catch (e) {
      // 关闭加载指示器
      Navigator.pop(context);
      
      // 显示错误
      _showErrorDialog(context, '选择文件失败：$e');
    }
  }
  
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在处理...'),
          ],
        ),
      ),
    );
  }
  
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
} 