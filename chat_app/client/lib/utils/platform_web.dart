// Web平台的Platform类替代实现
class Platform {
  // 禁止实例化
  Platform._();

  // Web平台上的操作系统始终返回"web"
  static String get operatingSystem => 'web';
  
  // 平台检测方法
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
  static bool get isWeb => true;
} 