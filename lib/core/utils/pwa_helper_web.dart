import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('canInstallPWA')
external bool _canInstallPWA();

@JS('triggerPWAInstall')
external void _triggerPWAInstall();

@JS('isPWAInstalled')
external bool _isPWAInstalled();

@JS('refreshPWA')
external void _refreshPWA();

@JS('downloadBase64File')
external void _downloadBase64File(JSString base64Data, JSString fileName, JSString? mimeType);

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

  static void downloadBase64File(String base64Data, String fileName, [String? mimeType]) {
    try {
      _downloadBase64File(base64Data.toJS, fileName.toJS, mimeType?.toJS);
    } catch (e) {
      debugPrint('PWAHelper.downloadBase64File error: $e');
    }
  }
}
