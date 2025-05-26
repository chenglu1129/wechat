import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? senderName;
  
  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.senderName,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 显示发送者名称（仅在群聊中且不是自己发送的消息时）
                if (!isMe && senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text(
                      senderName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe 
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(),
                      const SizedBox(height: 4),
                      Text(
                        message.formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }
  
  Widget _buildAvatar() {
    // 在实际应用中，这里应该显示发送者的头像
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
      decoration: BoxDecoration(
        color: isMe ? Colors.green : Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          isMe ? 'Me' : (senderName?.substring(0, 1).toUpperCase() ?? message.senderId.substring(0, 1).toUpperCase()),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.video:
        return _buildVideoMessage();
      case MessageType.audio:
        return _buildAudioMessage();
      case MessageType.file:
        return _buildFileMessage();
      case MessageType.location:
        return _buildLocationMessage();
      case MessageType.system:
        return _buildSystemMessage();
      case MessageType.text:
      default:
        return _buildTextMessage();
    }
  }
  
  Widget _buildTextMessage() {
    return Text(
      message.content,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black,
      ),
    );
  }
  
  Widget _buildImageMessage() {
    // 实际应用中应该加载图片
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: message.mediaUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.mediaUrl!,
                    fit: BoxFit.cover,
                  ),
                )
              : const Center(
                  child: Icon(Icons.image, size: 40, color: Colors.grey),
                ),
        ),
        if (message.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildVideoMessage() {
    // 实际应用中应该显示视频缩略图和播放按钮
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_filled, size: 40, color: Colors.grey),
          ),
        ),
        if (message.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildAudioMessage() {
    // 实际应用中应该显示音频播放控件
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 30,
          decoration: BoxDecoration(
            color: isMe ? Colors.white24 : Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '0:${message.content}秒',
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFileMessage() {
    // 实际应用中应该显示文件图标和文件名
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file),
        const SizedBox(width: 8),
        Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLocationMessage() {
    // 实际应用中应该显示地图缩略图
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.location_on, size: 40, color: Colors.grey),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSystemMessage() {
    // 系统消息居中显示
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
        ),
      ),
    );
  }
} 