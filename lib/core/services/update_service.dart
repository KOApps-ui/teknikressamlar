import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_version.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String releaseName;
  final String changelog;
  final String downloadUrl;
  final int fileSize;
  final DateTime publishedAt;
  final DateTime? assetUpdatedAt;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.releaseName,
    required this.changelog,
    required this.downloadUrl,
    required this.fileSize,
    required this.publishedAt,
    this.assetUpdatedAt,
  });

  String get fileSizeText {
    if (fileSize <= 0) return '';
    final mb = fileSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  DateTime? _lastCheckTime;
  UpdateInfo? _cachedInfo;

  /// Check GitHub release for newer versions.
  /// If [force] is false, throttles calls to at most once per 30 minutes.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!force && _lastCheckTime != null && _cachedInfo != null) {
      final elapsed = DateTime.now().difference(_lastCheckTime!);
      if (elapsed.inMinutes < 30) {
        return _cachedInfo;
      }
    }

    try {
      final uri = Uri.parse(AppVersion.apiUrl);
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'KOApps-TeknikRessamlar/${AppVersion.version}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('Update check HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?) ?? 'APK';
      final releaseName = (data['name'] as String?) ?? 'KO|Apps - Teknik Ressamlar';
      final changelog = (data['body'] as String?) ?? '';
      final publishedAtStr = (data['published_at'] as String?) ?? '';
      final publishedAt = DateTime.tryParse(publishedAtStr) ?? DateTime.now();

      String downloadUrl = AppVersion.releasePageUrl;
      int fileSize = 0;
      DateTime? assetUpdatedAt;

      final assets = data['assets'] as List<dynamic>?;
      if (assets != null && assets.isNotEmpty) {
        final apkAsset = assets.firstWhere(
          (a) => (a['name'] as String? ?? '').endsWith('.apk'),
          orElse: () => assets.first,
        ) as Map<String, dynamic>;

        downloadUrl = (apkAsset['browser_download_url'] as String?) ?? downloadUrl;
        fileSize = (apkAsset['size'] as int?) ?? 0;
        final updatedStr = apkAsset['updated_at'] as String?;
        if (updatedStr != null) {
          assetUpdatedAt = DateTime.tryParse(updatedStr);
        }
      }

      bool hasUpdate = false;

      // 1. Check if asset updated after current build date (with 2 min buffer)
      if (assetUpdatedAt != null) {
        hasUpdate = assetUpdatedAt.isAfter(
          AppVersion.buildDate.add(const Duration(minutes: 2)),
        );
      }

      // 2. Check semantic version if release title contains 'vX.Y.Z'
      final versionMatch = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(releaseName);
      if (versionMatch != null) {
        final onlineVer = versionMatch.group(1)!;
        if (_isVersionNewer(onlineVer, AppVersion.version)) {
          hasUpdate = true;
        }
      }

      final info = UpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: tagName,
        releaseName: releaseName,
        changelog: changelog,
        downloadUrl: downloadUrl,
        fileSize: fileSize,
        publishedAt: publishedAt,
        assetUpdatedAt: assetUpdatedAt,
      );

      _lastCheckTime = DateTime.now();
      _cachedInfo = info;
      return info;
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    }
  }

  bool _isVersionNewer(String online, String current) {
    try {
      final oParts = online.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final o = i < oParts.length ? oParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (o > c) return true;
        if (o < c) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Download APK on Android with progress reporting
  Future<File?> downloadApk({
    required String downloadUrl,
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    if (kIsWeb) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/KO_Apps_TeknikRessam_update.apk');
      if (targetFile.existsSync()) {
        await targetFile.delete();
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 10;

      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        throw Exception('Download failed with HTTP ${response.statusCode}');
      }

      final total = response.contentLength > 0 ? response.contentLength : 0;
      int received = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress(received / total, received, total);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      return targetFile;
    } catch (e) {
      debugPrint('APK download error: $e');
      return null;
    }
  }

  /// Trigger Android system APK installer
  Future<OpenResult> installApk(File apkFile) async {
    return await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
  }

  /// Open release page in external browser
  Future<void> openReleasePage() async {
    final uri = Uri.parse(AppVersion.releasePageUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
