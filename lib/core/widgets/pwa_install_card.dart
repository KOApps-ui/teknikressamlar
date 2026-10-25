import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/pwa_helper.dart';

class PWAInstallCard extends StatefulWidget {
  final bool compact;

  const PWAInstallCard({super.key, this.compact = false});

  @override
  State<PWAInstallCard> createState() => _PWAInstallCardState();
}

class _PWAInstallCardState extends State<PWAInstallCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _dismissed) {
      return const SizedBox.shrink();
    }

    if (PWAHelper.isInstalled()) {
      return const SizedBox.shrink();
    }

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (widget.compact) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.blueprintSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.install_mobile_rounded, color: AppTheme.cyanLine, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Web uygulamasını ana ekranınıza ekleyin',
                style: TextStyle(color: AppTheme.textLight, fontSize: 11),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyanLine,
                foregroundColor: AppTheme.blueprintDark,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                if (isIOS) {
                  _showIOSGuide(context);
                } else {
                  PWAHelper.promptInstall();
                }
              },
              child: const Text('Yükle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cyanLine, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyanLine.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cyanLine.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.install_mobile_rounded, color: AppTheme.cyanLine, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uygulamayı Cihazınıza Ekleyin',
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mağaza veya APK gerekmeden tek tıkla kurun',
                      style: TextStyle(color: AppTheme.cyanLine, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _dismissed = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isIOS
                ? 'Apple iOS Safari üzerinden açtığınızda tam ekran deneyimi için alt menüdeki "Paylaş" simgesine basıp "Ana Ekrana Ekle" seçeneğini seçebilirsiniz.'
                : 'KO|Apps\'i bilgisayarınıza veya telefonunuza yükleyerek tarayıcı sekmelerinden bağımsız, tam ekran ve anında açılacak şekilde kullanabilirsiniz.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _dismissed = true),
                child: const Text('Daha Sonra', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyanLine,
                  foregroundColor: AppTheme.blueprintDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(isIOS ? Icons.ios_share : Icons.download_rounded, size: 16),
                label: Text(
                  isIOS ? 'Nasıl Eklenir?' : '📲 CİHAZA YÜKLE',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  if (isIOS) {
                    _showIOSGuide(context);
                  } else {
                    PWAHelper.promptInstall();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showIOSGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cyanLine, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.apple, color: AppTheme.textLight, size: 24),
            SizedBox(width: 8),
            Text(
              'iOS Ana Ekrana Ekleme',
              style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Safari alt çubuğundaki Paylaş (Share) simgesine dokunun.\n\n'
              '2. Açılan menüde aşağı kaydırıp "Ana Ekrana Ekle" (Add to Home Screen) seçeneğine dokunun.\n\n'
              '3. Sağ üstteki "Ekle" butonuna basarak tamamlayın.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyanLine,
              foregroundColor: AppTheme.blueprintDark,
            ),
            child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
