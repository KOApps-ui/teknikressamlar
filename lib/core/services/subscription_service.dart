import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nostr/nostr.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/user_profile.dart';
import 'local_db_service.dart';
import 'notification_service.dart';

class CompanyLicense {
  final String planId; // 'pack_5', 'pro_monthly', 'yearly_corporate'
  final String planName; // '5 Teklif Paketi', 'Pro Kurumsal (30 Gün)', 'Yıllık Kurumsal'
  final String licenseKey;
  final DateTime activatedAt;
  final DateTime? expiresAt;
  final int remainingCredits; // for pay-as-you-go or 0 if unlimited
  final bool isUnlimited;

  CompanyLicense({
    required this.planId,
    required this.planName,
    required this.licenseKey,
    required this.activatedAt,
    this.expiresAt,
    this.remainingCredits = 0,
    this.isUnlimited = false,
  });

  bool get isExpired {
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    if (!isUnlimited && remainingCredits <= 0) return true;
    return false;
  }

  int get remainingDays {
    if (expiresAt == null) return 999;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpiringSoon {
    if (isExpired) return false;
    if (expiresAt != null && remainingDays <= 3) return true;
    if (!isUnlimited && remainingCredits == 1) return true;
    return false;
  }

  String get remainingOffersText {
    if (isUnlimited) return 'Sınırsız Teklif';
    return '$remainingCredits Teklif Kaldı';
  }

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'planName': planName,
      'licenseKey': licenseKey,
      'activatedAt': activatedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'remainingCredits': remainingCredits,
      'isUnlimited': isUnlimited,
    };
  }

  factory CompanyLicense.fromMap(Map<String, dynamic> map) {
    return CompanyLicense(
      planId: map['planId'] as String? ?? 'pro_monthly',
      planName: map['planName'] as String? ?? 'Pro Kurumsal',
      licenseKey: map['licenseKey'] as String? ?? '',
      activatedAt: map['activatedAt'] != null
          ? DateTime.tryParse(map['activatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'] as String)
          : null,
      remainingCredits: map['remainingCredits'] as int? ?? 0,
      isUnlimited: map['isUnlimited'] as bool? ?? false,
    );
  }
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final _localDb = LocalDbService();
  static const int freeOfferLimit = 1;

  // FAST / Bank details for zero-commission direct transfer
  static const String fastIban = 'TR33 0006 4000 0011 2345 6789 01';
  static const String fastAccountName = 'KO|Apps Teknoloji - Şirket Abonelikleri';
  static const String fastBankName = 'Türkiye İş Bankası';
  static const String fastKolayAdres = 'odeme@koapps.net';

  /// Validates a license key or promotional code and returns target planId, or null if invalid
  String? validatePromoOrLicenseKey(String key) {
    final cleaned = key.trim().toUpperCase();
    if (cleaned.isEmpty) return null;
    if (cleaned == 'KO-PRO-2026' ||
        cleaned == 'KO-PRO-DEMO' ||
        cleaned == 'VIP-PRO' ||
        cleaned.startsWith('KO-PRO-') ||
        cleaned.startsWith('KO-FAST-PRO')) {
      return 'pro_monthly';
    }
    if (cleaned == 'KO-PACK5' ||
        cleaned == 'KO-5-TEKLIF' ||
        cleaned.startsWith('KO-PACK-') ||
        cleaned.startsWith('KO-FAST-PACK')) {
      return 'pack_5';
    }
    if (cleaned == 'KO-YEARLY-2026' ||
        cleaned == 'KO-VIP-YEAR' ||
        cleaned.startsWith('KO-YEAR-') ||
        cleaned.startsWith('KO-FAST-YEAR')) {
      return 'yearly_corporate';
    }
    if (cleaned.startsWith('KO-') && cleaned.length >= 8) {
      return 'pro_monthly';
    }
    return null;
  }

  Future<void> cancelOrResetSubscription({UserProfile? profile}) async {
    await _localDb.clearCompanyLicense();
  }

  final List<String> _relays = [
    'wss://nos.lol',
    'wss://relay.primal.net',
    'wss://nostr.mom',
  ];

  static const int dailyFreeOfferLimit = 1;

  /// Checks if company can send an offer.
  /// Returns a record: (allowed, isFree, reason)
  Future<({bool allowed, bool isFree, String? reason})> canSendOffer() async {
    final license = await getActiveLicense();
    if (license != null && !license.isExpired) {
      if (license.isUnlimited || license.remainingCredits > 0) {
        return (allowed: true, isFree: false, reason: license.planName);
      }
    }

    final todaySent = await _localDb.getTodayOffersSentCount();
    if (todaySent < dailyFreeOfferLimit) {
      return (allowed: true, isFree: true, reason: 'Günlük 1 Ücretsiz Teklif Hakkı');
    }

    return (
      allowed: false,
      isFree: false,
      reason: 'Bugünkü 1 adet ücretsiz teklif hakkınızı kullandınız. Yarın otomatik olarak yeni hakkınız tanımlanacaktır.'
    );
  }

  /// Deducts credit or records free offer usage
  Future<void> recordOfferSent() async {
    final license = await getActiveLicense();
    if (license != null && !license.isExpired) {
      if (!license.isUnlimited && license.remainingCredits > 0) {
        final updated = CompanyLicense(
          planId: license.planId,
          planName: license.planName,
          licenseKey: license.licenseKey,
          activatedAt: license.activatedAt,
          expiresAt: license.expiresAt,
          remainingCredits: license.remainingCredits - 1,
          isUnlimited: false,
        );
        await saveLicense(updated);
        return;
      }
      if (license.isUnlimited) return;
    }

    await _localDb.incrementTodayOffersSentCount();
    await _localDb.incrementFreeOffersSentCount();
  }

  Future<CompanyLicense?> getActiveLicense() async {
    final map = await _localDb.getCompanyLicense();
    if (map == null) return null;
    try {
      final license = CompanyLicense.fromMap(map);
      if (license.isExpired) return null;
      return license;
    } catch (_) {
      return null;
    }
  }

  Future<CompanyLicense?> getLicense() => getActiveLicense();

  /// Activates a plan and backs it up to Nostr encrypted relay storage
  Future<CompanyLicense> activatePlan({
    required String planId,
    required String licenseKey,
    UserProfile? profile,
  }) async {
    late CompanyLicense license;
    final now = DateTime.now();

    if (planId == 'pack_5') {
      license = CompanyLicense(
        planId: 'pack_5',
        planName: '5 Tekliflik Paket',
        licenseKey: licenseKey,
        activatedAt: now,
        remainingCredits: 5,
        isUnlimited: false,
      );
    } else if (planId == 'yearly_corporate') {
      license = CompanyLicense(
        planId: 'yearly_corporate',
        planName: 'Yıllık Kurumsal Sınırsız',
        licenseKey: licenseKey,
        activatedAt: now,
        expiresAt: now.add(const Duration(days: 365)),
        isUnlimited: true,
      );
    } else {
      // Default: Pro Monthly
      license = CompanyLicense(
        planId: 'pro_monthly',
        planName: 'Pro Kurumsal Aylık (Sınırsız)',
        licenseKey: licenseKey,
        activatedAt: now,
        expiresAt: now.add(const Duration(days: 30)),
        isUnlimited: true,
      );
    }

    await saveLicense(license, profile: profile);
    return license;
  }

  Future<void> saveLicense(CompanyLicense license, {UserProfile? profile}) async {
    await _localDb.saveCompanyLicense(license.toMap());

    // Zero-server Nostr backup (Encrypted Kind 30078 replaceable event)
    if (profile != null) {
      try {
        await _backupLicenseToNostr(license, profile);
      } catch (e) {
        debugPrint('[SubscriptionService] Nostr backup warning: $e');
      }
    }
  }

  /// Publishes encrypted license to Nostr relays under company's own key
  Future<void> _backupLicenseToNostr(CompanyLicense license, UserProfile profile) async {
    final cleanPriv = profile.privateKey.replaceAll('0x', '').trim();
    final cleanPub = profile.publicKey
        .replaceAll('did:nostr:', '')
        .replaceAll('did:ko:comp:', '')
        .replaceAll('did:ko:tr:', '')
        .trim();

    final payloadJson = json.encode(license.toMap());
    final encryptedContent = await Encryption.encrypt(
      plaintext: payloadJson,
      senderSecretKey: cleanPriv,
      recipientPubkey: cleanPub,
    );

    final event = Event.from(
      kind: 30078,
      content: encryptedContent,
      secretKey: cleanPriv,
      tags: [
        ['d', 'ko_company_license'],
        ['app', 'ko_apps_teknikressamlar'],
      ],
    );

    final eventJson = json.encode(['EVENT', event.toMap()]);
    for (final r in _relays) {
      try {
        final channel = WebSocketChannel.connect(Uri.parse(r));
        await channel.ready.timeout(const Duration(seconds: 3));
        channel.sink.add(eventJson);
        await Future.delayed(const Duration(milliseconds: 500));
        await channel.sink.close();
      } catch (_) {}
    }
    debugPrint('[SubscriptionService] Encrypted license backed up to Nostr relays.');
  }

  /// Restores license from Nostr relays if user reinstalls or switches device
  Future<CompanyLicense?> restoreLicenseFromNostr(UserProfile profile) async {
    try {
      final cleanPriv = profile.privateKey.replaceAll('0x', '').trim();
      final cleanPub = profile.publicKey
          .replaceAll('did:nostr:', '')
          .replaceAll('did:ko:comp:', '')
          .replaceAll('did:ko:tr:', '')
          .trim();

      for (final r in _relays) {
        try {
          final channel = WebSocketChannel.connect(Uri.parse(r));
          await channel.ready.timeout(const Duration(seconds: 4));
          final subId = 'restore_${DateTime.now().millisecondsSinceEpoch}';
          final reqJson = json.encode([
            'REQ',
            subId,
            {
              'kinds': [30078],
              'authors': [cleanPub],
              '#d': ['ko_company_license'],
              'limit': 1,
            }
          ]);

          final completer = Completer<String?>();
          final sub = channel.stream.listen((message) async {
            try {
              final parsed = json.decode(message as String);
              if (parsed is List && parsed.isNotEmpty) {
                if (parsed[0] == 'EVENT' && parsed.length >= 3) {
                  final ev = parsed[2] as Map<String, dynamic>;
                  final content = ev['content'] as String? ?? '';
                  if (content.isNotEmpty && !completer.isCompleted) {
                    completer.complete(content);
                  }
                } else if (parsed[0] == 'EOSE') {
                  if (!completer.isCompleted) completer.complete(null);
                }
              }
            } catch (_) {}
          });

          channel.sink.add(reqJson);
          final cipherText = await completer.future.timeout(const Duration(seconds: 4), onTimeout: () => null);
          await sub.cancel();
          await channel.sink.close();

          if (cipherText != null && cipherText.isNotEmpty) {
            final decrypted = await Encryption.decrypt(
              payload: cipherText,
              senderPubkey: cleanPub,
              recipientSecretKey: cleanPriv,
            );
            final map = Map<String, dynamic>.from(json.decode(decrypted) as Map);
            final license = CompanyLicense.fromMap(map);
            await _localDb.saveCompanyLicense(license.toMap());
            debugPrint('[SubscriptionService] License successfully restored from Nostr!');
            return license;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Error restoring license: $e');
    }
    return null;
  }

  /// Checks if company license is expiring soon and notifies
  Future<void> checkExpiringNotification() async {
    final license = await getActiveLicense();
    if (license == null) return;

    if (license.isExpiringSoon) {
      String msg;
      if (license.expiresAt != null) {
        msg = 'Paketinizin bitmesine ${license.remainingDays} gün kaldı! Kesintisiz teklif vermek için yenileyebilirsiniz.';
      } else {
        msg = 'Yalnızca ${license.remainingCredits} teklif hakkınız kaldı!';
      }

      await NotificationService().showNotification(
        title: '⚠️ KO|Apps - Lisans Bildirimi',
        body: msg,
      );
    }
  }
}
