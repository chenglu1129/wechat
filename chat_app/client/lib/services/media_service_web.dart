import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;

import '../utils/api_constants.dart';
import '../utils/token_manager.dart';
import 'media_service.dart';

/// Web平台的MediaService实现
class MediaServiceWeb implements MediaService {
  final ImagePicker _imagePicker = ImagePicker();
  final TokenManager _tokenManager;
  
  MediaServiceWeb({required TokenManager tokenManager}) : _tokenManager = tokenManager;
  
  // 选择图片
  @override
  Future<MediaItem?> pickImage({required ImageSource source}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70, // 压缩质量
      );
      
      if (pickedFile == null) return null;
      
      // 在Web平台上，我们直接使用XFile的path
      final path = pickedFile.path;
      final name = pickedFile.name;
      
      return MediaItem(
        id: const Uuid().v4(),
        path: path,
        type: MediaType.image,
        mimeType: pickedFile.mimeType,
        name: name,
        // Web平台上无法直接获取文件大小，设为0
        size: 0,
      );
    } catch (e) {
      debugPrint('选择图片失败: $e');
      return null;
    }
  }
  
  // 选择视频
  @override
  Future<MediaItem?> pickVideo({required ImageSource source}) async {
    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // 最大时长
      );
      
      if (pickedFile == null) return null;
      
      // 在Web平台上，我们直接使用XFile的path
      final path = pickedFile.path;
      final name = pickedFile.name;
      
      return MediaItem(
        id: const Uuid().v4(),
        path: path,
        type: MediaType.video,
        mimeType: pickedFile.mimeType,
        name: name,
        // Web平台上无法直接获取文件大小，设为0
        size: 0,
      );
    } catch (e) {
      debugPrint('选择视频失败: $e');
      return null;
    }
  }
  
  // 选择文件 - Web平台实现
  @override
  Future<MediaItem?> pickFile() async {
    try {
      // 创建文件输入元素
      final uploadInput = html.FileUploadInputElement();
      uploadInput.accept = '*/*'; // 接受所有类型的文件
      uploadInput.click();
      
      // 等待用户选择文件
      await for (final _ in uploadInput.onChange) {
        if (uploadInput.files!.isNotEmpty) {
          final file = uploadInput.files![0];
          final reader = html.FileReader();
          reader.readAsDataUrl(file);
          
          // 等待读取完成
          await reader.onLoad.first;
          
          // 确定媒体类型
          final mimeType = file.type;
          final mediaType = _getMediaTypeFromMime(mimeType);
          
          // 创建唯一ID
          final id = const Uuid().v4();
          
          // 创建一个临时URL，用于在Web上访问文件
          final objectUrl = html.Url.createObjectUrlFromBlob(file);
          
          return MediaItem(
            id: id,
            path: objectUrl, // 在Web上，path是一个ObjectURL
            type: mediaType,
            mimeType: mimeType,
            name: file.name,
            size: file.size,
          );
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('选择文件失败: $e');
      return null;
    }
  }
  
  // 根据MIME类型判断媒体类型
  @override
  MediaType _getMediaTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return MediaType.image;
    } else if (mimeType.startsWith('video/')) {
      return MediaType.video;
    } else if (mimeType.startsWith('audio/')) {
      return MediaType.audio;
    } else {
      return MediaType.file;
    }
  }
  
  // 上传媒体 - Web平台实现
  @override
  Future<String?> uploadMedia(MediaItem media) async {
    try {
      final token = await _tokenManager.getToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      // 记录请求开始
      print('┌───────────────────────────────────────────────────');
      print('│ 🌐 Web平台上传文件请求');
      print('│ 📋 URL: ${ApiConstants.baseUrl}/media/upload');
      print('│ 📦 文件名: ${media.name}');
      print('│ 📦 类型: ${media.mimeType}');
      
      // 在Web平台上，我们需要使用FormData
      final formData = html.FormData();
      
      // 从ObjectURL获取Blob
      final response = await http.get(Uri.parse(media.path));
      final blob = html.Blob([response.bodyBytes], media.mimeType);
      
      // 创建文件
      final file = html.File([blob], media.name!);
      
      // 添加到表单
      formData.appendBlob('file', file);
      formData.append('type', media.type.toString().split('.').last);
      
      // 创建请求
      final request = html.HttpRequest();
      request.open('POST', '${ApiConstants.baseUrl}/media/upload');
      request.setRequestHeader('Authorization', 'Bearer $token');
      
      // 记录开始时间
      final startTime = DateTime.now();
      
      // 发送请求
      request.send(formData);
      
      // 等待响应
      await request.onLoad.first;
      
      // 计算响应时间
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      if (request.status == 200) {
        final responseText = request.responseText;
        final json = jsonDecode(responseText!);
        
        // 记录响应
        print('│ ⏱️ 响应时间: ${responseTime}ms');
        print('│ 📊 状态码: ${request.status}');
        print('│ 📦 响应体: $json');
        print('└───────────────────────────────────────────────────');
        
        return json['url'];
      } else {
        // 记录错误
        print('│ ⏱️ 响应时间: ${responseTime}ms');
        print('│ ❌ 状态码: ${request.status}');
        print('│ 📦 错误: ${request.responseText}');
        print('└───────────────────────────────────────────────────');
        
        throw Exception('上传失败: ${request.status}');
      }
    } catch (e) {
      // 记录异常
      print('│ ❌ 上传异常: $e');
      print('└───────────────────────────────────────────────────');
      
      debugPrint('上传媒体失败: $e');
      return null;
    }
  }
  
  // 下载媒体 - Web平台实现
  @override
  Future<dynamic> downloadMedia(String url, {String? filename}) async {
    try {
      // 在Web平台上，我们直接打开URL
      html.window.open(url, '_blank');
      return true;
    } catch (e) {
      debugPrint('下载媒体失败: $e');
      return null;
    }
  }
  
  // 获取缩略图 - Web平台实现
  @override
  Future<String?> getThumbnail(dynamic file, MediaType type) async {
    // 在Web平台上，对于图片直接返回原路径
    if (type == MediaType.image) {
      return file.path;
    }
    return null;
  }
  
  // 清理临时文件 - Web平台实现
  @override
  Future<void> cleanupTempFiles() async {
    // Web平台上不需要手动清理，浏览器会自动管理
  }
} 