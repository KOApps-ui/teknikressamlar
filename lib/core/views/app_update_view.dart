import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_version.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../utils/pwa_helper.dart';

class AppUpdateView extends StatefulWidget {
  const AppUpdateView({super.key});

  @override
  State<AppUpdateView> createState() => _AppUpdateViewState();
}

class _AppUpdateViewState extends State<AppUpdateView> {
  final _updateService = UpdateService();
  bool _isChecking = true;
  UpdateInfo? _info;
  String? _checkError;

  // Download state
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  File? _downloadedApk;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _checkUpdates(force: false);
  }

  Future<void> _checkUpdates({bool force = true}) async {
    setState(() {
      _isChecking = true;
      _checkError = null;
    });

    try {
      final info = await _updateService.checkForUpdate(force: force);
      if (mounted) {
        setState(() {
          _info = info;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkError = e.toString();
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _startUpdate() async {
    if (kIsWeb) {
      PWAHelper.reloadApp();
      await launchUrl(Uri.base, webOnlyWindowName: '_self');
      return;
    }

    if (_info == null) return;

    setState(() {
      _isDownloading = true;
      _downloadError = null;
      _progress = 0.0;
    });

    final file = await _updateService.downloadApk(
      downloadUrl: _info!.downloadUrl,
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
        _downloadError = 'Güncelleme dosyası indirilemedi. İnternet bağlantınızı kontrol edin.';
      });
      return;
    }

    setState(() {
      _isDownloading = false;
      _downloadedApk = file;
    });

    await _installApk(file);
  }

  Future<void> _installApk(File apk) async {
    setState(() => _isInstalling = true);
    final result = await _updateService.installApk(apk);
    if (!mounted) return;

    setState(() => _isInstalling = false);
    if (result.type != ResultType.done) {
      setState(() {
        _downloadError = 'Yükleyici başlatılamadı: ${result.message}';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = _info != null && _info!.hasUpdate;

    return Scaffold(
      backgroundColor: AppTheme.blueprintDark,
      appBar: AppBar(
        backgroundColor: AppTheme.blueprintSurface,
        title: const Text(
          'Uygulama Güncelleme Merkezi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.cyanLine),
            tooltip: 'Yeniden Denetle',
            onPressed: _isChecking || _isDownloading ? null : () => _checkUpdates(force: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Banner & Version Hero
            _buildHeroBanner(),
            const SizedBox(height: 16),

            // Status Card
            _buildStatusCard(hasUpdate),
            const SizedBox(height: 16),

            // Download / Progress Card (if downloading or downloaded)
            if (_isDownloading || _downloadedApk != null) ...[
              _buildProgressCard(),
              const SizedBox(height: 16),
            ],

            // Changelog / Release Notes
            if (_info != null && _info!.changelog.isNotEmpty) ...[
              _buildChangelogCard(),
              const SizedBox(height: 16),
            ],

            // Platform Specific Actions
            _buildActionButtons(hasUpdate),
            const SizedBox(height: 16),

            // Decentralized Network Info
            _buildNetworkInfoCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyanLine.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.cyanLine.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.system_update_alt, color: AppTheme.cyanLine, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KO|Apps Teknik Ressamlar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cyanLine.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Yüklü: v${AppVersion.version}',
                        style: TextStyle(
                          color: AppTheme.cyanLine,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Yapı #${AppVersion.buildNumber}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool hasUpdate) {
    if (_isChecking) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.blueprintSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.steelBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.cyanLine),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Güncellemeler denetleniyor...',
                style: TextStyle(color: AppTheme.textLight, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_checkError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.blueprintSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.statusDanger.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: AppTheme.statusDanger, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ağ Bağlantısı Hatası',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.statusDanger, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _checkError!,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _checkUpdates(force: true),
              child: const Text('Tekrar Dene', style: TextStyle(color: AppTheme.cyanLine, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (hasUpdate) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.amberSteel.withValues(alpha: 0.15),
              AppTheme.blueprintSurface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.amberSteel.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.new_releases, color: AppTheme.amberSteel, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YENİ GÜNCELLEME MEVCUT!',
                        style: TextStyle(
                          color: AppTheme.amberSteel,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _info?.releaseName ?? 'Yeni Sürüm',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_info?.fileSizeText.isNotEmpty == true) ...[
                  const Icon(Icons.attach_file, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Boyut: ${_info!.fileSizeText}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Yayın: ${_formatDate(_info?.publishedAt)}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Up to date
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.statusSuccess.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: AppTheme.statusSuccess, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uygulama En Güncel Sürümde',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.statusSuccess,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Harika! Cihazınızda en son optimizasyonlar ve özellikler yüklü.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _downloadedApk != null
                    ? 'İndirme Tamamlandı'
                    : 'İndiriliyor: %${(_progress * 100).toStringAsFixed(0)}',
                style: const TextStyle(color: AppTheme.cyanLine, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_totalBytes > 0)
                Text(
                  '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _downloadedApk != null ? 1.0 : _progress,
              minHeight: 8,
              backgroundColor: AppTheme.blueprintDark,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyanLine),
            ),
          ),
          if (_downloadError != null) ...[
            const SizedBox(height: 8),
            Text(
              _downloadError!,
              style: const TextStyle(color: AppTheme.statusDanger, fontSize: 11),
            ),
          ],
          if (_downloadedApk != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.statusSuccess,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.install_mobile, size: 18),
                label: Text(
                  _isInstalling ? 'Yükleyici Çalışıyor...' : 'APK Yükleyiciyi Başlat',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _isInstalling ? null : () => _installApk(_downloadedApk!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangelogCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.steelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes, color: AppTheme.cyanLine, size: 18),
              SizedBox(width: 8),
              Text(
                'Sürüm Değişiklik Günlüğü (Changelog)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.blueprintDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _info!.changelog,
              style: const TextStyle(color: AppTheme.textLight, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool hasUpdate) {
    return Column(
      children: [
        if (hasUpdate && !_isDownloading && _downloadedApk == null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amberSteel,
                foregroundColor: AppTheme.blueprintDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              icon: Icon(kIsWeb ? Icons.refresh : Icons.download, size: 20),
              label: Text(
                kIsWeb ? 'UYGULAMAYI YENİLE VE GÜNCELLE' : 'GÜNCELLEMEYİ İNDİR VE YÜKLE (APK)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
              onPressed: _startUpdate,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cyanLine,
                  side: const BorderSide(color: AppTheme.cyanLine),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Şimdi Denetle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _isChecking || _isDownloading ? null : () => _checkUpdates(force: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  side: const BorderSide(color: AppTheme.steelBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.open_in_browser, size: 16),
                label: const Text('GitHub Sürümü', style: TextStyle(fontSize: 12)),
                onPressed: () => _updateService.openReleasePage(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNetworkInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, color: AppTheme.textMuted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merkeziyetsiz Dağıtım & Doğrulama',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Uygulama güncellemeleri KO|Apps GitHub ve Nostr P2P dağıtım ağı üzerinden güvenli ve şifreli olarak senkronize edilir.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
