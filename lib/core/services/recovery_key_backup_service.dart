import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import '../models/offer_model.dart';
import 'local_db_service.dart';

/// A complete local account snapshot: profile + offers belonging to it.
class AccountBackup {
  final UserProfile profile;
  final List<OfferModel> offers;
  final DateTime savedAt;
  final String filePath;

  const AccountBackup({
    required this.profile,
    required this.offers,
    required this.savedAt,
    required this.filePath,
  });
}

/// Local, zero-server account vault.
///
/// Every profile save writes a snapshot; deleting/resetting an account writes
/// one too (plus a human readable key file). Snapshots can be listed and
/// restored with a single tap, no relay or key typing required.
class RecoveryKeyBackupService {
  static final RecoveryKeyBackupService _instance = RecoveryKeyBackupService._internal();
  factory RecoveryKeyBackupService() => _instance;
  RecoveryKeyBackupService._internal();

  static const String backupFolderName = 'kurtarma_anahtarlari';
  static const String profileFolderName = 'profil_yedekleri';

  final _localDb = LocalDbService();

  Future<Directory> backupDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$backupFolderName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<Directory> profileBackupDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$profileFolderName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  // ---------------------------------------------------------------- backups

  /// Writes / overwrites the canonical snapshot for this profile and returns
  /// the stored backup.
  Future<AccountBackup?> backupProfile(UserProfile profile) async {
    if (profile.publicKey.trim().isEmpty) return null;
    try {
      final offers = await _offersOf(profile);
      final savedAt = DateTime.now();

      if (kIsWeb) {
        return AccountBackup(
          profile: profile,
          offers: offers,
          savedAt: savedAt,
          filePath: 'Tarayıcı Yerel Kasası',
        );
      }

      final payload = <String, dynamic>{
        'version': 2,
        'savedAt': savedAt.toIso8601String(),
        'profile': profile.toMap(),
        'offers': offers.map((o) => o.toMap()).toList(),
      };

      final dir = await profileBackupDirectory();
      final file = File('${dir.path}/hesap_${profile.publicKey.trim().toLowerCase()}.json');
      await file.writeAsString(json.encode(payload));

      return AccountBackup(
        profile: profile,
        offers: offers,
        savedAt: savedAt,
        filePath: file.path,
      );
    } catch (e) {
      debugPrint('RecoveryKeyBackupService backup error: $e');
      return null;
    }
  }

  Future<List<OfferModel>> _offersOf(UserProfile profile) async {
    try {
      if (profile.role == 'company') {
        return await _localDb.getOffers(forCompanyId: profile.id);
      }
      return await _localDb.getOffers(forDraftsmanId: profile.id);
    } catch (_) {
      return [];
    }
  }

  /// Reads every snapshot stored on this device, newest first.
  Future<List<AccountBackup>> listBackups() async {
    if (kIsWeb) return [];
    final result = <AccountBackup>[];
    try {
      final dir = await profileBackupDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      for (final file in files) {
        final backup = await _readBackupFile(file);
        if (backup != null) {
          result.add(backup);
        }
      }
    } catch (e) {
      debugPrint('RecoveryKeyBackupService list error: $e');
    }
    return result;
  }

  Future<AccountBackup?> loadBackupByPublicKey(String publicKey) async {
    if (kIsWeb) return null;
    final clean = publicKey.trim().toLowerCase();
    if (clean.isEmpty) return null;

    try {
      final base = await getApplicationDocumentsDirectory();
      final canonical = File('${base.path}/$profileFolderName/hesap_$clean.json');
      if (canonical.existsSync()) {
        final backup = await _readBackupFile(canonical);
        if (backup != null) return backup;
      }
    } catch (e) {
      debugPrint('RecoveryKeyBackupService load error: $e');
    }

    // Legacy scan: snapshots written by older builds.
    try {
      final dir = await profileBackupDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      for (final file in files) {
        final backup = await _readBackupFile(file);
        if (backup == null) continue;
        final stored = backup.profile.publicKey.trim().toLowerCase();
        if (stored == clean || stored.contains(clean) || clean.contains(stored)) {
          return backup;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<AccountBackup?> _readBackupFile(File file) async {
    try {
      final raw = json.decode(await file.readAsString());
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);

      // v2 format nests the profile, legacy format is the profile itself.
      final profileMap = map['profile'] is Map
          ? Map<String, dynamic>.from(map['profile'] as Map)
          : map;
      if ((profileMap['publicKey'] as String? ?? '').trim().isEmpty) return null;

      final profile = UserProfile.fromMap(profileMap);
      final offers = <OfferModel>[];
      if (map['offers'] is List) {
        for (final item in map['offers'] as List) {
          try {
            offers.add(OfferModel.fromMap(Map<String, dynamic>.from(item as Map)));
          } catch (_) {}
        }
      }

      return AccountBackup(
        profile: profile,
        offers: offers,
        savedAt: DateTime.tryParse(map['savedAt'] as String? ?? '') ??
            File(file.path).lastModifiedSync(),
        filePath: file.path,
      );
    } catch (e) {
      debugPrint('RecoveryKeyBackupService read error: $e');
      return null;
    }
  }

  /// Puts a snapshot back into the live database (profile + its offers).
  Future<UserProfile?> restoreToLocal(AccountBackup backup) async {
    try {
      await _localDb.saveUserProfile(backup.profile);
      await _localDb.setLoggedIn(true);
      for (final offer in backup.offers) {
        await _localDb.saveOfferIfNew(offer);
      }
      return backup.profile;
    } catch (e) {
      debugPrint('RecoveryKeyBackupService restore error: $e');
      return null;
    }
  }

  // ------------------------------------------------------------- key file

  Future<File?> backupKeyToFile({
    required String privateKey,
    required String ownerName,
    required String role,
  }) async {
    if (kIsWeb) return null;
    final key = privateKey.trim();
    if (key.isEmpty) return null;

    try {
      final dir = await backupDirectory();
      final now = DateTime.now();
      final stamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
      final safeName = ownerName
          .trim()
          .replaceAll(RegExp(r'[^0-9A-Za-zÇĞİÖŞÜçğıöşü_-]+'), '_');
      final roleLabel = role == 'company' ? 'sirket' : 'ressam';
      final file = File('${dir.path}/kurtarma_${roleLabel}_${safeName}_$stamp.txt');

      final content = StringBuffer()
        ..writeln('KO|Apps - Teknik Ressamlar')
        ..writeln('KURTARMA ANAHTARI YEDEĞİ')
        ..writeln('==========================================')
        ..writeln('Hesap Türü : ${role == 'company' ? 'İşveren Şirket' : 'Teknik Ressam'}')
        ..writeln('Ad         : ${ownerName.trim().isEmpty ? '-' : ownerName.trim()}')
        ..writeln(
          'Tarih      : ${now.day}.${now.month}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        )
        ..writeln('------------------------------------------')
        ..writeln('KURTARMA ANAHTARI (64 haneli):')
        ..writeln(key)
        ..writeln('------------------------------------------')
        ..writeln('Bu dosyayı güvende ve gizli saklayın.')
        ..writeln('Uygulamayı yeniden yüklediğinizde ya da yeni hesap')
        ..writeln('açıp geri dönmek istediğinizde bu anahtarı')
        ..writeln('"Hesabı Geri Yükle" ekranına yapıştırın.')
        ..writeln('Bu dosyayı kimseyle paylaşmayın.');

      await file.writeAsString(content.toString());
      return file;
    } catch (e) {
      debugPrint('RecoveryKeyBackupService error: $e');
      return null;
    }
  }
}
