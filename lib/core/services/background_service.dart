import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nostr/nostr.dart';
import '../models/user_profile.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void backgroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(OfferListenerTaskHandler());
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static void init() {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ko_apps_bg_listener',
        channelName: 'KO|Apps Canlı Ağ Servisi',
        channelDescription: 'Uygulama kapalıyken yeni iş tekliflerini dinler',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  static Future<void> start(UserProfile profile) async {
    if (!Platform.isAndroid) return;

    init();

    // Store keys in SharedPreferences so background isolate has instant access
    await FlutterForegroundTask.saveData(key: 'user_pubkey', value: profile.publicKey);
    await FlutterForegroundTask.saveData(key: 'user_privkey', value: profile.privateKey);
    await FlutterForegroundTask.saveData(key: 'user_role', value: profile.role);
    await FlutterForegroundTask.saveData(key: 'user_name', value: profile.name);

    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      final title = profile.role == 'draftsman'
          ? 'KO|Apps - Teknik Ressam Ağı Aktif'
          : 'KO|Apps - İşveren Ağı Aktif';
      final text = profile.role == 'draftsman'
          ? 'Yeni iş teklifleri kapalıyken de anlık dinleniyor...'
          : 'Teklif yanıtları arka planda dinleniyor...';

      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
        callback: backgroundTaskCallback,
      );
      debugPrint('[BackgroundService] Started successfully for ${profile.name}');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
  }
}

class OfferListenerTaskHandler extends TaskHandler {
  final List<String> _relays = [
    'wss://nos.lol',
    'wss://relay.primal.net',
    'wss://nostr.mom',
  ];

  final Map<String, WebSocket> _sockets = {};
  String? _userPubkey;
  String? _userPrivkey;
  String? _userRole;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[BackgroundService] onStart triggered (starter: $starter)');

    _userPubkey = await FlutterForegroundTask.getData<String>(key: 'user_pubkey');
    _userPrivkey = await FlutterForegroundTask.getData<String>(key: 'user_privkey');
    _userRole = await FlutterForegroundTask.getData<String>(key: 'user_role');
    debugPrint('[BackgroundService] Starting background listener for role: $_userRole');

    if (_userPubkey == null || _userPubkey!.isEmpty) {
      debugPrint('[BackgroundService] No user_pubkey stored in background task');
      return;
    }

    await NotificationService().init();
    await _connectRelays();
  }

  Future<void> _connectRelays() async {
    if (_userPubkey == null || _userPubkey!.isEmpty) return;

    final cleanPub = _userPubkey!
        .replaceAll('did:nostr:', '')
        .replaceAll('did:ko:tr:', '')
        .replaceAll('did:ko:comp:', '')
        .trim();

    for (final url in _relays) {
      if (_sockets.containsKey(url)) continue;

      try {
        final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 8));
        _sockets[url] = ws;

        final subId = 'bg_sub_${cleanPub.substring(0, cleanPub.length >= 8 ? 8 : cleanPub.length)}';
        ws.add(json.encode([
          'REQ',
          subId,
          {
            'kinds': [21000],
            '#p': [cleanPub],
          }
        ]));

        ws.listen(
          (msg) => _handleMessage(msg.toString()),
          onError: (e) {
            _sockets.remove(url);
          },
          onDone: () {
            _sockets.remove(url);
          },
        );
        debugPrint('[BackgroundService] Subscribed to $url for #p: $cleanPub');
      } catch (e) {
        debugPrint('[BackgroundService] Connect error for $url: $e');
      }
    }
  }

  Future<void> _handleMessage(String rawMsg) async {
    try {
      final parsed = json.decode(rawMsg) as List;
      if (parsed.isEmpty || parsed[0] != 'EVENT') return;

      final event = parsed[2] as Map<String, dynamic>;
      final kind = event['kind'] as int?;
      final senderPubkey = event['pubkey'] as String?;
      final content = event['content'] as String? ?? '';

      if (kind == 21000 && _userPrivkey != null && senderPubkey != null) {
        final decrypted = await Encryption.decrypt(
          payload: content,
          recipientSecretKey: _userPrivkey!,
          senderPubkey: senderPubkey,
        );

        final data = json.decode(decrypted) as Map<String, dynamic>;
        final type = data['type'] as String?;

        if (type == 'OFFER_DIRECT') {
          final offerMap = data['offer'] as Map<String, dynamic>?;
          if (offerMap != null) {
            final companyName = offerMap['companyName'] as String? ?? 'İşveren';
            final projectTitle = offerMap['projectTitle'] as String? ?? 'Proje Çizimi';
            final budget = offerMap['budget'] as String? ?? '';

            await NotificationService().showOfferNotification(
              companyName: companyName,
              title: projectTitle,
              budget: budget,
            );

            await FlutterForegroundTask.updateService(
              notificationTitle: '📬 Yeni İş Teklifi Geldi!',
              notificationText: '$companyName: $projectTitle ($budget)',
            );
          }
        } else if (type == 'OFFER_RESPONSE') {
          final status = data['status'] as String?;
          final draftsmanName = data['draftsmanName'] as String? ?? 'Teknik Ressam';
          if (status == 'accepted') {
            await NotificationService().showOfferAcceptedNotification(
              draftsmanName: draftsmanName,
              projectTitle: 'Teklifiniz',
            );

            await FlutterForegroundTask.updateService(
              notificationTitle: '🎉 Teklif Kabul Edildi!',
              notificationText: '$draftsmanName teklifinizi kabul etti. İletişim bilgileri açıldı.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[BackgroundService] Message decode error: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_sockets.length < _relays.length) {
      _connectRelays();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    for (final ws in _sockets.values) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _sockets.clear();
  }
}
