import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> showOfferNotification({
    required String companyName,
    required String title,
    required String budget,
  }) async {
    await init();
    try {
      final androidDetails = AndroidNotificationDetails(
        'ko_apps_offers_v3',
        'İş Teklifleri (Doğrudan P2P)',
        channelDescription: 'Yeni şifreli P2P iş teklifi bildirimleri (Arka plan & Uyku modu aktif)',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          'Proje: $title\nBütçe: $budget\nİşveren: $companyName',
          contentTitle: '📬 Yeni İş Teklifi: $companyName',
          summaryText: 'P2P Canlı Ağ Bildirimi',
        ),
      );

      const linuxDetails = LinuxNotificationDetails();

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _plugin.show(
        id,
        '📬 Yeni İş Teklifi: $companyName',
        '$title • $budget',
        notificationDetails,
      );
      debugPrint('System notification posted for offer from $companyName');
    } catch (e) {
      debugPrint('Error showing system notification: $e');
    }
  }

  Future<void> showOfferAcceptedNotification({
    required String draftsmanName,
    required String projectTitle,
  }) async {
    await init();
    try {
      final androidDetails = AndroidNotificationDetails(
        'ko_apps_offer_accepted_v3',
        'Teklif Kabul Bildirimleri',
        channelDescription: 'Teknik ressam teklif kabul bildirimleri (Arka plan & Uyku modu aktif)',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          '$draftsmanName, "$projectTitle" için teklifinizi kabul etti. İletişim bilgileri ve CAD paftası açıldı.',
          contentTitle: '🎉 İş Teklifiniz Kabul Edildi!',
          summaryText: 'P2P Sözleşme Bildirimi',
        ),
      );

      const linuxDetails = LinuxNotificationDetails();

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _plugin.show(
        id,
        '🎉 İş Teklifiniz Kabul Edildi!',
        '$draftsmanName, "$projectTitle" için teklifinizi kabul etti. İletişim bilgileri açıldı.',
        notificationDetails,
      );
      debugPrint('System notification posted for accepted offer from $draftsmanName');
    } catch (e) {
      debugPrint('Error showing accepted notification: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await init();
    try {
      const androidDetails = AndroidNotificationDetails(
        'ko_apps_general',
        'Genel Bildirimler',
        channelDescription: 'Uygulama ve abonelik bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const linuxDetails = LinuxNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      );
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _plugin.show(id, title, body, notificationDetails);
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
