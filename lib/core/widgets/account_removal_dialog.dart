import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../services/file_launcher_service.dart';
import '../services/recovery_key_backup_service.dart';
import '../theme/app_theme.dart';

enum RemovalDecision {
  /// User cancelled.
  cancel,

  /// User confirmed, account must be removed.
  confirmDelete,

  /// User changed their mind, restore the snapshot that was just taken.
  restoreBackup,
}

class RemovalResult {
  final RemovalDecision decision;
  final AccountBackup? backup;

  const RemovalResult(this.decision, [this.backup]);
}

/// Confirmation + local backup flow that must run before an account is
/// deleted or reset, so profile, offers and the recovery key are always saved
/// onto the device — and can be brought back in one tap.
class AccountRemovalDialog {
  static Future<RemovalResult> confirm({
    required BuildContext context,
    required String title,
    required String message,
    required UserProfile? profile,
    String confirmLabel = 'DEVAM ET',
  }) async {
    final privateKey = profile?.privateKey.trim() ?? '';
    final ownerName = profile?.name ?? '';
    final role = profile?.role ?? 'draftsman';

    if (profile == null) {
      final accepted = await _showConfirm(
        context: context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        showKeyNote: false,
      );
      return RemovalResult(accepted ? RemovalDecision.confirmDelete : RemovalDecision.cancel);
    }

    final accepted = await _showConfirm(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      showKeyNote: true,
    );
    if (!accepted) return const RemovalResult(RemovalDecision.cancel);
    if (!context.mounted) return const RemovalResult(RemovalDecision.cancel);

    final backup = await RecoveryKeyBackupService().backupProfile(profile);
    if (privateKey.isNotEmpty) {
      await RecoveryKeyBackupService().backupKeyToFile(
        privateKey: privateKey,
        ownerName: ownerName,
        role: role,
      );
    }
    if (!context.mounted) return const RemovalResult(RemovalDecision.cancel);

    return _showBackupResult(
      context: context,
      backup: backup,
      privateKey: privateKey,
    );
  }

  static Future<bool> _showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required bool showKeyNote,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.statusDanger, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.statusDanger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$message${showKeyNote ? '\n\nDevam etmeden önce profiliniz, teklifleriniz ve kurtarma anahtarınız cihazınıza yedeklenecek. İsterseniz bir sonraki ekrandan vazgeçip hesabı geri alabilirsiniz.' : ''}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  static Future<RemovalResult> _showBackupResult({
    required BuildContext context,
    required AccountBackup? backup,
    required String privateKey,
  }) async {
    final success = backup != null;

    final decision = await showDialog<RemovalDecision>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: success ? AppTheme.statusSuccess : AppTheme.statusDanger,
            width: 1.5,
          ),
        ),
        title: Row(
          children: [
            Icon(
              success ? Icons.cloud_done_rounded : Icons.error_outline,
              color: success ? AppTheme.statusSuccess : AppTheme.statusDanger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                success ? 'Hesabınız Cihaza Yedeklendi' : 'Yedek Oluşturulamadı',
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              success
                  ? 'Profiliniz, portföyünüz, CV\'niz, rozetleriniz, teklifleriniz ve kurtarma anahtarınız bu cihaza kaydedildi. Silmek yerine vazgeçerseniz hesabınız aynen geri gelir.'
                  : 'Dosyaya yazılamadı. Devam ederseniz hesabınız silinir ve yerel yedeği olmadan geri getirilemez.',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5),
            ),
            if (success) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Yedek: ${backup.profile.name} • ${backup.offers.length} teklif\n${backup.filePath}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppTheme.textLight,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (privateKey.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.amberSteel,
                        side: const BorderSide(color: AppTheme.amberSteel),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Anahtarı Kopyala', style: TextStyle(fontSize: 11)),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: privateKey));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppTheme.statusSuccess,
                              content: Text('✓ Kurtarma anahtarı panoya kopyalandı.'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (success)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.cyanLine,
                        side: const BorderSide(color: AppTheme.cyanLine),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(kIsWeb ? Icons.copy : Icons.ios_share, size: 14),
                      label: Text(kIsWeb ? 'Yedeği Kopyala' : 'Yedeği Aç', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        if (kIsWeb) {
                          await Clipboard.setData(ClipboardData(text: json.encode(backup.profile.toMap())));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppTheme.statusSuccess,
                                content: Text('✓ Profil yedeği panoya kopyalandı.'),
                              ),
                            );
                          }
                        } else {
                          FileLauncherService.openFile(backup.filePath);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(ctx).pop(RemovalDecision.cancel),
          ),
          if (success)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyanLine,
                foregroundColor: AppTheme.blueprintDark,
              ),
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('VAZGEÇ & GERİ AL', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(ctx).pop(RemovalDecision.restoreBackup),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? AppTheme.statusSuccess : AppTheme.statusDanger,
              foregroundColor: success ? AppTheme.blueprintDark : Colors.white,
            ),
            child: Text(
              success ? 'SİL & DEVAM ET' : 'YİNE DE DEVAM ET',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () => Navigator.of(ctx).pop(RemovalDecision.confirmDelete),
          ),
        ],
      ),
    );

    if (decision == RemovalDecision.restoreBackup) {
      return RemovalResult(RemovalDecision.restoreBackup, backup);
    }
    if (decision == RemovalDecision.confirmDelete) {
      return RemovalResult(RemovalDecision.confirmDelete, backup);
    }
    return const RemovalResult(RemovalDecision.cancel);
  }
}
