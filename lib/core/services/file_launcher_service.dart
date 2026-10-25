import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';

class FileLauncherService {
  /// Opens a file with the system default application.
  /// On Android, uses OpenFilex intent.
  /// On Linux, uses OpenFilex with xdg-open fallback.
  static Future<bool> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('FileLauncherService: file does not exist at $filePath');
        return false;
      }

      final result = await OpenFilex.open(filePath);
      if (result.type == ResultType.done) {
        return true;
      }

      if (!kIsWeb && Platform.isLinux) {
        final res = await Process.run('xdg-open', [filePath]);
        return res.exitCode == 0;
      }

      return false;
    } catch (e) {
      debugPrint('FileLauncherService error: $e');
      if (!kIsWeb && Platform.isLinux) {
        try {
          final res = await Process.run('xdg-open', [filePath]);
          return res.exitCode == 0;
        } catch (_) {}
      }
      return false;
    }
  }
}
