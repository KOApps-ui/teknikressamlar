class PWAHelper {
  static bool get isSupported => false;
  static bool canInstall() => false;
  static void promptInstall() {}
  static bool isInstalled() => false;
  static void reloadApp() {}
  static void downloadBase64File(String base64Data, String fileName, [String? mimeType]) {}
}
