import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // 禁止实例化
  ApiConstants._();
  
  // 根据平台获取正确的主机地址
  static String get _host {
    // 如果是Web平台，直接使用window.location.hostname
    if (kIsWeb) {
      return 'localhost'; // Web平台使用当前域名
    }
    
    // 非Web平台
    if (Platform.isAndroid) {
      // Android模拟器访问主机的特殊IP
      return '10.0.2.2';
    } else if (Platform.isIOS) {
      // iOS模拟器访问主机的特殊IP
      return '127.0.0.1';
    } else {
      // 桌面平台直接使用localhost
      return 'localhost';
    }
  }
  
  // API基础URL
  static String get baseUrl => 'http://${_host}:8080';
  
  // WebSocket URL
  static String get wsUrl => 'ws://${_host}:8080/ws';
} 