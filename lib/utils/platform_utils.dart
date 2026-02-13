import 'dart:io' show Platform;

abstract final class PlatformUtils {
  PlatformUtils._();

  static bool get isDesktop => Platform.isMacOS;

  static bool get isMobile => false;

  static bool get isDesktopTarget => Platform.isMacOS;

  static bool get isMobileTarget => false;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isWindows => false;

  static bool get isLinux => false;

  static bool get isAndroid => false;

  static bool get isIOS => false;
}
