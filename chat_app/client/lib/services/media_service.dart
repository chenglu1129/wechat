import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

import '../utils/api_constants.dart';
import '../utils/token_manager.dart';

/// 媒体类型
enum MediaType {
  image,
  audio,
  video,
  file,
}

/// 媒体项
class MediaItem {
  final String id;
  final String path;
  final String? url;
  final MediaType type;
  final String? mimeType;
  final String? name;
  final int? size;
  final String? thumbnailPath;
  final Duration? duration;
  
  MediaItem({
    required this.id,
    required this.path,
    this.url,
    required this.type,
    this.mimeType,
    this.name,
    this.size,
    this.thumbnailPath,
    this.duration,
  });
  
  // 创建文件媒体项
  static Future<MediaItem> fromFile(File file, MediaType type) async {
    final filename = p.basename(file.path);
    final size = await file.length();
    final mimeType = lookupMimeType(file.path);
    
    return MediaItem(
      id: const Uuid().v4(),
      path: file.path,
      type: type,
      mimeType: mimeType,
      name: filename,
      size: size,
    );
  }
  
  // 文件大小的可读表示
  String get formattedSize {
    if (size == null) return '未知大小';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double s = size!.toDouble();
    
    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }
    
    return '${s.toStringAsFixed(1)} ${suffixes[i]}';
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'url': url,
      'type': type.toString().split('.').last,
      'mime_type': mimeType,
      'name': name,
      'size': size,
      'thumbnail_path': thumbnailPath,
      'duration': duration?.inSeconds,
    };
  }
}

/// 多媒体服务类
class MediaService {
  final ImagePicker _imagePicker = ImagePicker();
  final TokenManager _tokenManager;
  
  MediaService({required TokenManager tokenManager}) : _tokenManager = tokenManager;
  
  // 选择图片
  Future<MediaItem?> pickImage({required ImageSource source}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70, // 压缩质量
      );
      
      if (pickedFile == null) return null;
      
      final file = File(pickedFile.path);
      return await MediaItem.fromFile(file, MediaType.image);
    } catch (e) {
      debugPrint('选择图片失败: $e');
      return null;
    }
  }
  
  // 选择视频
  Future<MediaItem?> pickVideo({required ImageSource source}) async {
    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // 最大时长
      );
      
      if (pickedFile == null) return null;
      
      final file = File(pickedFile.path);
      return await MediaItem.fromFile(file, MediaType.video);
    } catch (e) {
      debugPrint('选择视频失败: $e');
      return null;
    }
  }
  
  // 选择文件
  Future<MediaItem?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) return null;
      
      final file = File(result.files.first.path!);
      final mediaType = _getMediaTypeFromMime(lookupMimeType(file.path) ?? '');
      
      return await MediaItem.fromFile(file, mediaType);
    } catch (e) {
      debugPrint('选择文件失败: $e');
      return null;
    }
  }
  
  // 根据MIME类型判断媒体类型
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
  
  // 上传媒体
  Future<String?> uploadMedia(MediaItem media) async {
    try {
      final token = await _tokenManager.getToken();
      if (token == null) {
        throw Exception('未登录');
      }
      
      // 创建多部分请求
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/media/upload'),
      );
      
      // 添加认证信息
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });
      
      // 添加文件
      final file = File(media.path);
      final fileStream = http.ByteStream(file.openRead());
      final length = await file.length();
      
      // 解析MIME类型
      final mimeTypeData = media.mimeType?.split('/');
      http.MultipartFile multipartFile;
      
      if (mimeTypeData != null && mimeTypeData.length == 2) {
        multipartFile = http.MultipartFile(
          'file',
          fileStream,
          length,
          filename: media.name ?? p.basename(media.path),
          contentType: http_parser.MediaType(mimeTypeData[0], mimeTypeData[1]),
        );
      } else {
        multipartFile = http.MultipartFile(
          'file',
          fileStream,
          length,
          filename: media.name ?? p.basename(media.path),
        );
      }
      
      request.files.add(multipartFile);
      
      // 添加媒体类型
      request.fields['type'] = media.type.toString().split('.').last;
      
      // 发送请求
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['url'];
      } else {
        throw Exception('上传失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('上传媒体失败: $e');
      return null;
    }
  }
  
  // 下载媒体
  Future<File?> downloadMedia(String url, {String? filename}) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // 获取临时目录
        final dir = await getTemporaryDirectory();
        final name = filename ?? p.basename(url);
        final file = File('${dir.path}/$name');
        
        // 写入文件
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception('下载失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('下载媒体失败: $e');
      return null;
    }
  }
  
  // 获取缩略图
  Future<String?> getThumbnail(File file, MediaType type) async {
    try {
      if (type == MediaType.image) {
        // 对于图片，直接返回路径
        return file.path;
      } else if (type == MediaType.video) {
        // 对于视频，生成缩略图（需要视频缩略图生成库）
        // 这里简化处理，实际应用中可以使用video_thumbnail库
        return null;
      } else {
        // 其他类型不生成缩略图
        return null;
      }
    } catch (e) {
      debugPrint('获取缩略图失败: $e');
      return null;
    }
  }
  
  // 清理临时文件
  Future<void> cleanupTempFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync();
      
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('清理临时文件失败: $e');
    }
  }
} 