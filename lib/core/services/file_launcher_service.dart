import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/pwa_helper.dart';

class FileLauncherService {
  /// Opens a file with the system default application.
  /// On Android, uses OpenFilex intent.
  /// On Linux, uses OpenFilex with xdg-open fallback.
  static Future<bool> openFile(String filePath) async {
    if (kIsWeb) {
      debugPrint('FileLauncherService.openFile: not supported on web directly with path.');
      return false;
    }

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

      if (Platform.isLinux) {
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

  /// Opens or downloads a base64 encoded file across all platforms (Web, Android, Linux).
  /// On Web: Triggers immediate browser file download via Blob.
  /// On Native: Writes to temporary storage and invokes device-native viewer.
  static Future<bool> openBase64({
    required String base64Content,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      if (kIsWeb) {
        PWAHelper.downloadBase64File(base64Content, fileName, mimeType);
        return true;
      }

      final tempDir = await getTemporaryDirectory();
      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetFile = File('${tempDir.path}/$sanitizedName');

      final cleanBase64 = base64Content.contains(',')
          ? base64Content.split(',').last
          : base64Content;
      final bytes = base64Decode(cleanBase64.trim());
      await targetFile.writeAsBytes(bytes);

      return await openFile(targetFile.path);
    } catch (e) {
      debugPrint('FileLauncherService.openBase64 error: $e');
      return false;
    }
  }
}
