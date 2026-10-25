import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_version.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class AppUpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const AppUpdateDialog({super.key, required this.info});

  /// Static helper to check and show update dialog if available.
  static Future<void> checkAndShow(
    BuildContext context, {
    bool force = false,
    bool showIfNotAvailable = false,
  }) async {
    final updateService = UpdateService();
    final info = await updateService.checkForUpdate(force: force);

    if (!context.mounted) return;

    if (info != null && info.hasUpdate) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AppUpdateDialog(info: info),
      );
    } else if (showIfNotAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.blueprintSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.statusSuccess),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.statusSuccess, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Uygulama en güncel sürümde (v${AppVersion.version}).',
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  final _updateService = UpdateService();
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    if (kIsWeb) {
      // Reload on web
      await launchUrl(Uri.base, webOnlyWindowName: '_self');
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    final file = await _updateService.downloadApk(
      downloadUrl: widget.info.downloadUrl,
      onProgress: (progress, received, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        }
      },
    );

    if (!mounted) return;

    if (file == null || !file.existsSync()) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'İndirme tamamlanamadı. Lütfen internetinizi kontrol edin veya tarayıcıdan indirin.';
      });
      return;
    }

    setState(() {
      _isDownloading = false;
      _isInstalling = true;
    });

    final result = await _updateService.installApk(file);
    if (!mounted) return;

    if (result.type != ResultType.done) {
      setState(() {
        _isInstalling = false;
        _errorMessage = 'Yükleyici başlatılamadı (${result.message}). Dosyayı tarayıcıdan indirebilirsiniz.';
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    return AlertDialog(
      backgroundColor: AppTheme.blueprintDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.cyanLine, width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cyanLine.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded, color: AppTheme.cyanLine, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yeni Güncelleme Mevcut!',
                  style: TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mevcut: v${AppVersion.version}  ➜  Yeni: ${info.latestVersion}',
                  style: const TextStyle(color: AppTheme.cyanLine, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.fileSizeText.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.steelBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppTheme.amberSteel, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Paket Boyutu: ${info.fileSizeText}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],

            if (info.changelog.isNotEmpty) ...[
              const Text(
                'Yenilikler & Notlar:',
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.steelBorder),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.changelog,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.4,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppTheme.blueprintSurface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyanLine),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _totalBytes > 0
                        ? '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                        : 'İndiriliyor...',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  Text(
                    '%${(_progress * 100).toInt()}',
                    style: const TextStyle(
                      color: AppTheme.cyanLine,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            if (_isInstalling) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.amberSteel),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Yükleyiciye aktarılıyor...',
                      style: TextStyle(color: AppTheme.amberSteel, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.statusDanger, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading && !_isInstalling) ...[
          TextButton(
            child: const Text('Daha Sonra', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
              side: const BorderSide(color: AppTheme.steelBorder),
            ),
            icon: const Icon(Icons.open_in_browser, size: 14),
            label: const Text('Tarayıcıda Aç', style: TextStyle(fontSize: 11)),
            onPressed: () => _updateService.openReleasePage(),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyanLine,
              foregroundColor: AppTheme.blueprintDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(kIsWeb ? Icons.refresh : Icons.download_rounded, size: 16),
            label: Text(
              kIsWeb ? 'Şimdi Yenile' : 'Şimdi Güncelle',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: _startUpdate,
          ),
        ],
      ],
    );
  }
}
