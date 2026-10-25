import 'dart:js_interop';

@JS('canInstallPWA')
external bool _canInstallPWA();

@JS('triggerPWAInstall')
external void _triggerPWAInstall();

@JS('isPWAInstalled')
external bool _isPWAInstalled();

@JS('refreshPWA')
external void _refreshPWA();

class PWAHelper {
  static bool get isSupported => true;

  static bool canInstall() {
    try {
      return _canInstallPWA();
    } catch (_) {
      return false;
    }
  }

  static void promptInstall() {
    try {
      _triggerPWAInstall();
    } catch (_) {}
  }

  static bool isInstalled() {
    try {
      return _isPWAInstalled();
    } catch (_) {
      return false;
    }
  }

  static void reloadApp() {
    try {
      _refreshPWA();
    } catch (_) {}
  }
}
