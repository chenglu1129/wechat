import 'dart:io';
import 'package:flutter/material.dart';
import '../services/media_service.dart';

class MediaPreview extends StatelessWidget {
  final MediaItem mediaItem;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final TextEditingController? captionController;
  
  const MediaPreview({
    Key? key,
    required this.mediaItem,
    required this.onCancel,
    required this.onSend,
    this.captionController,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部标题栏
          Row(
            children: [
              Text(
                _getPreviewTitle(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 媒体预览内容
          _buildMediaPreview(),
          
          const SizedBox(height: 8),
          
          // 说明文字输入框
          if (captionController != null)
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                hintText: '添加说明文字...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              minLines: 1,
            ),
          
          const SizedBox(height: 12),
          
          // 发送按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('发送'),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPreviewTitle() {
    switch (mediaItem.type) {
      case MediaType.image:
        return '图片预览';
      case MediaType.video:
        return '视频预览';
      case MediaType.audio:
        return '音频预览';
      case MediaType.file:
        return '文件预览';
      default:
        return '媒体预览';
    }
  }
  
  Widget _buildMediaPreview() {
    switch (mediaItem.type) {
      case MediaType.image:
        return _buildImagePreview();
      case MediaType.video:
        return _buildVideoPreview();
      case MediaType.audio:
        return _buildAudioPreview();
      case MediaType.file:
        return _buildFilePreview();
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildImagePreview() {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(mediaItem.path),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
  
  Widget _buildVideoPreview() {
    // 在实际应用中，这里可以使用video_player包来播放视频预览
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 视频缩略图
          if (mediaItem.thumbnailPath != null)
            Image.file(
              File(mediaItem.thumbnailPath!),
              fit: BoxFit.contain,
              width: double.infinity,
            )
          else
            Container(
              color: Colors.grey[800],
              width: double.infinity,
              height: 200,
            ),
          
          // 播放按钮
          const Icon(
            Icons.play_circle_fill,
            size: 64,
            color: Colors.white70,
          ),
          
          // 视频信息
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                mediaItem.formattedSize,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAudioPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: Row(
        children: [
          const Icon(Icons.audiotrack, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mediaItem.name ?? '音频文件',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  mediaItem.formattedSize,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_arrow, size: 32),
        ],
      ),
    );
  }
  
  Widget _buildFilePreview() {
    String fileExtension = '';
    if (mediaItem.name != null) {
      final parts = mediaItem.name!.split('.');
      if (parts.length > 1) {
        fileExtension = parts.last.toUpperCase();
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                fileExtension.isEmpty ? '文件' : fileExtension,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mediaItem.name ?? '未知文件',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  mediaItem.formattedSize,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 