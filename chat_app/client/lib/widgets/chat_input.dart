import 'package:flutter/material.dart';
import '../services/media_service.dart';
import 'media_picker.dart';
import 'media_preview.dart';

enum ChatInputMode {
  text,
  media,
}

class ChatInput extends StatefulWidget {
  final Function(String) onSendText;
  final Function(MediaItem, String?) onSendMedia;
  final MediaService mediaService;
  final bool isFirstMessage;
  
  const ChatInput({
    Key? key,
    required this.onSendText,
    required this.onSendMedia,
    required this.mediaService,
    this.isFirstMessage = false,
  }) : super(key: key);
  
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  
  ChatInputMode _inputMode = ChatInputMode.text;
  MediaItem? _selectedMedia;
  bool _showMediaPicker = false;
  
  @override
  void dispose() {
    _messageController.dispose();
    _captionController.dispose();
    super.dispose();
  }
  
  void _sendTextMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text);
      _messageController.clear();
    }
  }
  
  void _sendMediaMessage() {
    if (_selectedMedia != null) {
      final caption = _captionController.text.trim();
      widget.onSendMedia(_selectedMedia!, caption.isNotEmpty ? caption : null);
      _resetMediaInput();
    }
  }
  
  void _onMediaSelected(MediaItem mediaItem) {
    setState(() {
      _selectedMedia = mediaItem;
      _inputMode = ChatInputMode.media;
      _showMediaPicker = false;
    });
  }
  
  void _resetMediaInput() {
    setState(() {
      _selectedMedia = null;
      _inputMode = ChatInputMode.text;
      _captionController.clear();
    });
  }
  
  void _toggleMediaPicker() {
    setState(() {
      _showMediaPicker = !_showMediaPicker;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 首条消息提示
        if (widget.isFirstMessage)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '这是你们的第一次对话，说声"你好"吧！',
                    style: TextStyle(color: Colors.amber[800]),
                  ),
                ),
              ],
            ),
          ),
          
        // 媒体预览
        if (_inputMode == ChatInputMode.media && _selectedMedia != null)
          MediaPreview(
            mediaItem: _selectedMedia!,
            onCancel: _resetMediaInput,
            onSend: _sendMediaMessage,
            captionController: _captionController,
          ),
        
        // 媒体选择器
        if (_showMediaPicker)
          MediaPicker(
            onMediaSelected: _onMediaSelected,
            mediaService: widget.mediaService,
          ),
        
        // 文本输入栏
        if (_inputMode == ChatInputMode.text)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _toggleMediaPicker,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: widget.isFirstMessage ? '发送第一条消息...' : '输入消息...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendTextMessage,
                ),
              ],
            ),
          ),
      ],
    );
  }
} 