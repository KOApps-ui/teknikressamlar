import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import '../models/offer_model.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  static const String _userBoxName = 'ko_user_box';
  static const String _offersBoxName = 'ko_offers_box';
  static const String _settingsBoxName = 'ko_settings_box';

  Box? _userBox;
  Box? _offersBox;
  Box? _settingsBox;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    _userBox = await Hive.openBox(_userBoxName);
    _offersBox = await Hive.openBox(_offersBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    final cleaned = _settingsBox?.get('offers_cleaned_v2') as bool? ?? false;
    if (!cleaned) {
      await _offersBox?.clear();
      await _settingsBox?.put('offers_cleaned_v2', true);
      debugPrint('Old dummy offers cleared for fresh start.');
    }

    _isInitialized = true;
    await syncPendingBackgroundOffers();
    debugPrint('LocalDbService initialized with encrypted local boxes.');
  }

  // --- USER PROFILE OPERATIONS ---

  Future<UserProfile?> getUserProfile() async {
    await _ensureInit();
    final raw = _userBox?.get('current_user');
    if (raw == null) return null;
    try {
      final map = json.decode(raw as String);
      return UserProfile.fromMap(Map<String, dynamic>.from(map as Map));
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return null;
    }
  }

  Future<bool> isUserLoggedIn() async {
    await _ensureInit();
    final profile = await getUserProfile();
    if (profile == null) return false;
    final loggedIn = _userBox?.get('is_logged_in') as bool?;
    return loggedIn ?? true;
  }

  Future<void> setLoggedIn(bool loggedIn) async {
    await _ensureInit();
    await _userBox?.put('is_logged_in', loggedIn);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _ensureInit();
    final jsonStr = json.encode(profile.toMap());
    await _userBox?.put('current_user', jsonStr);
    await _userBox?.put('is_logged_in', true);
    await setActiveRole(profile.role);
  }

  Future<void> deleteUserProfile() async {
    await _ensureInit();
    await _userBox?.clear();
    await _userBox?.flush();
    await _settingsBox?.delete('active_role');
    await _settingsBox?.flush();
  }

  Future<void> addPortfolioFile(PortfolioFile file) async {
    final profile = await getUserProfile();
    if (profile == null) return;

    final updatedFiles = List<PortfolioFile>.from(profile.portfolioFiles)
      ..removeWhere((f) => f.id == file.id)
      ..add(file);

    final updatedProfile = profile.copyWith(
      portfolioFiles: updatedFiles,
      updatedAt: DateTime.now(),
    );

    await saveUserProfile(updatedProfile);
  }

  Future<void> removePortfolioFile(String fileId) async {
    final profile = await getUserProfile();
    if (profile == null) return;

    final updatedFiles = List<PortfolioFile>.from(profile.portfolioFiles)
      ..removeWhere((f) => f.id == fileId);

    final updatedProfile = profile.copyWith(
      portfolioFiles: updatedFiles,
      updatedAt: DateTime.now(),
    );

    await saveUserProfile(updatedProfile);
  }

  Future<void> addCertificate(CertificateItem certificate) async {
    final profile = await getUserProfile();
    if (profile == null) return;

    final updated = List<CertificateItem>.from(profile.certificates)
      ..removeWhere((c) => c.id == certificate.id)
      ..add(certificate);

    final updatedProfile = profile.copyWith(
      certificates: updated,
      updatedAt: DateTime.now(),
    );

    await saveUserProfile(updatedProfile);
  }

  Future<void> removeCertificate(String certificateId) async {
    final profile = await getUserProfile();
    if (profile == null) return;

    final updated = List<CertificateItem>.from(profile.certificates)
      ..removeWhere((c) => c.id == certificateId);

    final updatedProfile = profile.copyWith(
      certificates: updated,
      updatedAt: DateTime.now(),
    );

    await saveUserProfile(updatedProfile);
  }

  // --- OFFERS OPERATIONS ---

  String _cleanId(String id) => id
      .replaceAll('did:nostr:', '')
      .replaceAll('did:ko:tr:', '')
      .replaceAll('did:ko:comp:', '')
      .trim();

  Future<void> syncPendingBackgroundOffers() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pendingDir = Directory('${dir.path}/pending_bg_offers');
      if (!await pendingDir.exists()) return;

      final entities = pendingDir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final map = json.decode(content) as Map<String, dynamic>;
            if (entity.path.contains('/offer_')) {
              final offer = OfferModel.fromMap(map);
              await saveOfferIfNew(offer);
            } else if (entity.path.contains('/response_')) {
              final offerId = map['offerId'] as String?;
              final status = map['status'] as String?;
              final note = map['responseNote'] as String?;
              final draftsmanEmail = map['draftsmanEmail'] as String?;
              final draftsmanPhone = map['draftsmanPhone'] as String?;
              final draftsmanCity = map['draftsmanCity'] as String?;
              final draftsmanTitle = map['draftsmanTitle'] as String?;
              final draftsmanBio = map['draftsmanBio'] as String?;
              final draftsmanLinkedin = map['draftsmanLinkedin'] as String?;
              final draftsmanKariyerNet = map['draftsmanKariyerNet'] as String?;
              if (offerId != null && status != null) {
                await updateOfferStatus(
                  offerId,
                  status,
                  responseNote: note,
                  draftsmanEmail: draftsmanEmail,
                  draftsmanPhone: draftsmanPhone,
                  draftsmanCity: draftsmanCity,
                  draftsmanTitle: draftsmanTitle,
                  draftsmanBio: draftsmanBio,
                  draftsmanLinkedin: draftsmanLinkedin,
                  draftsmanKariyerNet: draftsmanKariyerNet,
                );
              }
            }
            await entity.delete();
          } catch (e) {
            debugPrint('Error syncing pending bg offer file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error in syncPendingBackgroundOffers: $e');
    }
  }

  Future<List<OfferModel>> getOffers({String? forDraftsmanId, String? forCompanyId}) async {
    await _ensureInit();
    await syncPendingBackgroundOffers();
    final List<OfferModel> offers = [];
    final keys = _offersBox?.keys ?? [];

    final cleanDraftsmanId = forDraftsmanId != null ? _cleanId(forDraftsmanId) : null;
    final cleanCompanyId = forCompanyId != null ? _cleanId(forCompanyId) : null;

    for (final key in keys) {
      final raw = _offersBox?.get(key);
      if (raw != null) {
        try {
          final map = json.decode(raw as String);
          final offer = OfferModel.fromMap(Map<String, dynamic>.from(map as Map));

          if (cleanDraftsmanId != null && cleanDraftsmanId.isNotEmpty) {
            final target = _cleanId(offer.draftsmanId);
            if (target != cleanDraftsmanId &&
                !target.contains(cleanDraftsmanId) &&
                !cleanDraftsmanId.contains(target)) {
              continue;
            }
          }
          if (cleanCompanyId != null && cleanCompanyId.isNotEmpty) {
            final target = _cleanId(offer.companyId);
            if (target != cleanCompanyId &&
                !target.contains(cleanCompanyId) &&
                !cleanCompanyId.contains(target)) {
              continue;
            }
          }

          offers.add(offer);
        } catch (e) {
          debugPrint('Error decoding offer $key: $e');
        }
      }
    }

    // Sort newest first
    offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return offers;
  }

  Future<void> saveOffer(OfferModel offer) async {
    await _ensureInit();
    final jsonStr = json.encode(offer.toMap());
    await _offersBox?.put(offer.id, jsonStr);
  }

  /// Saves offer only if it is genuinely new; prevents replayed Nostr events from reverting resolved status
  Future<bool> saveOfferIfNew(OfferModel offer) async {
    await _ensureInit();
    final raw = _offersBox?.get(offer.id);
    if (raw != null) {
      try {
        final existingMap = json.decode(raw as String);
        final existing = OfferModel.fromMap(Map<String, dynamic>.from(existingMap as Map));
        // If locally accepted or rejected, NEVER revert back to pending from relay replay!
        if (existing.status != 'pending') {
          return false;
        }
        // If incoming offer has response status and local is pending, update it
        if (offer.status != 'pending' && existing.status == 'pending') {
          await saveOffer(existing.copyWith(
            status: offer.status,
            responseNote: offer.responseNote,
            respondedAt: offer.respondedAt ?? DateTime.now(),
          ));
        }
        return false; // Offer already known
      } catch (_) {}
    }
    final jsonStr = json.encode(offer.toMap());
    await _offersBox?.put(offer.id, jsonStr);
    return true; // Genuinely brand new offer!
  }

  Future<void> clearAllOffers() async {
    await _ensureInit();
    await _offersBox?.clear();
  }

  Future<void> updateOfferStatus(
    String offerId,
    String newStatus, {
    String? responseNote,
    String? draftsmanEmail,
    String? draftsmanPhone,
    String? draftsmanCity,
    String? draftsmanTitle,
    String? draftsmanBio,
    String? draftsmanLinkedin,
    String? draftsmanKariyerNet,
  }) async {
    await _ensureInit();
    final raw = _offersBox?.get(offerId);
    if (raw == null) return;

    try {
      final map = json.decode(raw as String);
      final offer = OfferModel.fromMap(Map<String, dynamic>.from(map as Map));
      final updated = offer.copyWith(
        status: newStatus,
        responseNote: responseNote ?? offer.responseNote,
        draftsmanEmail: draftsmanEmail ?? offer.draftsmanEmail,
        draftsmanPhone: draftsmanPhone ?? offer.draftsmanPhone,
        draftsmanCity: draftsmanCity ?? offer.draftsmanCity,
        draftsmanTitle: draftsmanTitle ?? offer.draftsmanTitle,
        draftsmanBio: draftsmanBio ?? offer.draftsmanBio,
        draftsmanLinkedin: draftsmanLinkedin ?? offer.draftsmanLinkedin,
        draftsmanKariyerNet: draftsmanKariyerNet ?? offer.draftsmanKariyerNet,
        respondedAt: DateTime.now(),
      );
      await saveOffer(updated);
    } catch (e) {
      debugPrint('Error updating offer $offerId: $e');
    }
  }

  Future<void> deleteOffer(String offerId) async {
    await _ensureInit();
    await _offersBox?.delete(offerId);
  }

  // --- SETTINGS & ROLES ---

  Future<String> getActiveRole() async {
    await _ensureInit();
    return (_settingsBox?.get('active_role') as String?) ?? 'draftsman';
  }

  Future<void> setActiveRole(String role) async {
    await _ensureInit();
    await _settingsBox?.put('active_role', role);
  }

  Future<bool> isCompanySubscribed() async {
    await _ensureInit();
    return (_settingsBox?.get('is_company_subscribed') as bool?) ?? false;
  }

  Future<String> getSubscriptionTier() async {
    await _ensureInit();
    return (_settingsBox?.get('subscription_tier') as String?) ?? 'Ücretsiz';
  }

  Future<void> setCompanySubscription({
    required bool isSubscribed,
    required String tier,
  }) async {
    await _ensureInit();
    await _settingsBox?.put('is_company_subscribed', isSubscribed);
    await _settingsBox?.put('subscription_tier', tier);
  }

  Future<void> addDeletedCandidate(String candidateId) async {
    await _ensureInit();
    final raw = _settingsBox?.get('deleted_candidates');
    final list = raw is List ? List<String>.from(raw) : <String>[];
    if (!list.contains(candidateId)) {
      list.add(candidateId);
      await _settingsBox?.put('deleted_candidates', list);
    }
  }

  Future<bool> isCandidateDeleted(String candidateId) async {
    await _ensureInit();
    final raw = _settingsBox?.get('deleted_candidates');
    final list = raw is List ? List<String>.from(raw) : <String>[];
    return list.contains(candidateId);
  }

  Future<List<String>> getDeletedCandidates() async {
    await _ensureInit();
    final raw = _settingsBox?.get('deleted_candidates');
    return raw is List ? List<String>.from(raw) : <String>[];
  }

  Future<void> clearDeletedCandidates() async {
    await _ensureInit();
    await _settingsBox?.delete('deleted_candidates');
  }

  // --- BLOCKED / IGNORED USERS (Şirket & Ressam Engelleme) ---

  Future<void> blockUser({
    required String userId,
    required String name,
    required String role,
    String? note,
  }) async {
    await _ensureInit();
    final raw = _settingsBox?.get('blocked_users_list');
    final list = raw is List ? List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map))) : <Map<String, dynamic>>[];
    list.removeWhere((item) => item['id'] == userId);
    list.add({
      'id': userId,
      'name': name,
      'role': role,
      'note': note ?? '',
      'blockedAt': DateTime.now().toIso8601String(),
    });
    await _settingsBox?.put('blocked_users_list', list);
  }

  Future<void> unblockUser(String userId) async {
    await _ensureInit();
    final raw = _settingsBox?.get('blocked_users_list');
    if (raw is List) {
      final list = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
      list.removeWhere((item) => item['id'] == userId);
      await _settingsBox?.put('blocked_users_list', list);
    }
  }

  Future<bool> isUserBlocked(String userId) async {
    await _ensureInit();
    final raw = _settingsBox?.get('blocked_users_list');
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['id'] == userId) return true;
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    await _ensureInit();
    final raw = _settingsBox?.get('blocked_users_list');
    if (raw is List) {
      return List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return [];
  }

  // --- COMPANY SUBSCRIPTION & FREE OFFER LIMIT (1 Ücretsiz Teklif & Lisans) ---

  Future<int> getFreeOffersSentCount() async {
    await _ensureInit();
    return (_settingsBox?.get('free_offers_sent_count') as int?) ?? 0;
  }

  Future<void> incrementFreeOffersSentCount() async {
    await _ensureInit();
    final current = await getFreeOffersSentCount();
    await _settingsBox?.put('free_offers_sent_count', current + 1);
  }

  Future<int> getTodayOffersSentCount() async {
    await _ensureInit();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = _settingsBox?.get('daily_offers_sent_date') as String?;
    if (storedDate != todayStr) {
      await _settingsBox?.put('daily_offers_sent_date', todayStr);
      await _settingsBox?.put('daily_offers_sent_count', 0);
      return 0;
    }
    return (_settingsBox?.get('daily_offers_sent_count') as int?) ?? 0;
  }

  Future<void> incrementTodayOffersSentCount() async {
    await _ensureInit();
    final current = await getTodayOffersSentCount();
    await _settingsBox?.put('daily_offers_sent_count', current + 1);
  }

  Future<Map<String, dynamic>?> getCompanyLicense() async {
    await _ensureInit();
    final raw = _settingsBox?.get('company_license_data');
    if (raw == null) return null;
    try {
      if (raw is String) return Map<String, dynamic>.from(json.decode(raw) as Map);
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return null;
  }

  Future<void> saveCompanyLicense(Map<String, dynamic> licenseMap) async {
    await _ensureInit();
    await _settingsBox?.put('company_license_data', json.encode(licenseMap));
    await _settingsBox?.put('is_company_subscribed', true);
    await _settingsBox?.put('subscription_tier', licenseMap['planName'] ?? 'Pro');
  }

  Future<void> clearCompanyLicense() async {
    await _ensureInit();
    await _settingsBox?.delete('company_license_data');
    await _settingsBox?.put('is_company_subscribed', false);
    await _settingsBox?.put('subscription_tier', 'Ücretsiz');
  }

  Future<bool> isBatteryDialogDismissed() async {
    await init();
    return (_settingsBox?.get('battery_dialog_dismissed') as bool?) ?? false;
  }

  Future<void> setBatteryDialogDismissed(bool dismissed) async {
    await init();
    await _settingsBox?.put('battery_dialog_dismissed', dismissed);
  }

  Future<void> _ensureInit() async {
    if (!_isInitialized) {
      await init();
    }
  }
}
