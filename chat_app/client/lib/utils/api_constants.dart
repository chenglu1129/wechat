import 'package:flutter/foundation.dart' show kIsWeb;
// 有条件地导入dart:io
import 'dart:io' if (dart.library.html) '../utils/platform_web.dart' as platform;

class ApiConstants {
  // 禁止实例化
  ApiConstants._();
  
  // 根据平台获取正确的主机地址
  static String get _host {
    // 如果是Web平台，使用window.location.hostname
    if (kIsWeb) {
      try {
        // 在Web平台上，使用当前窗口的主机名
        // 这样可以确保API请求发送到同一个域名，避免跨域问题
        print('Web平台: 使用当前窗口的主机名');
        return 'localhost'; // 在开发环境中使用localhost
      } catch (e) {
        print('获取Web主机名失败，使用默认值: $e');
        return 'localhost';
      }
    }
    
    // 非Web平台
    if (platform.Platform.isAndroid) {
      // Android模拟器访问主机的特殊IP
      return '10.0.2.2';
    } else if (platform.Platform.isIOS) {
      // iOS模拟器访问主机的特殊IP
      return '127.0.0.1';
    } else {
      // 桌面平台直接使用localhost
      return 'localhost';
    }
  }
  
  // API基础URL
  static String get baseUrl {
    final url = 'http://${_host}:8080';
    print('API基础URL: $url');
    return url;
  }
  
  // WebSocket URL
  static String get wsUrl {
    final url = 'ws://${_host}:8080/ws';
    print('WebSocket URL: $url');
    return url;
  }
  
  // 其他API相关常量
  static const int connectionTimeout = 10000; // 10秒
  static const int receiveTimeout = 30000; // 30秒
} 