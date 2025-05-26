import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/token_manager.dart';
import 'media_service.dart';

// 有条件地导入平台特定实现
import 'media_service_impl.dart';
import 'media_service_web.dart' if (dart.library.io) 'media_service_impl.dart';

/// MediaService工厂类
class MediaServiceFactory {
  // 禁止实例化
  MediaServiceFactory._();
  
  /// 创建适合当前平台的MediaService实例
  static MediaService create({required TokenManager tokenManager}) {
    if (kIsWeb) {
      // Web平台
      print('创建Web平台的MediaService');
      return MediaServiceWeb(tokenManager: tokenManager);
    } else {
      // 移动平台
      print('创建移动平台的MediaService');
      return MediaServiceImpl(tokenManager: tokenManager);
    }
  }
} 