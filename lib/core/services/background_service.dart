import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
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
        channelId: 'ko_apps_bg_listener_v2',
        channelName: 'KO|Apps Canlı Ağ & Bildirim Servisi',
        channelDescription: 'Uygulama kapalıyken veya uyku modundayken yeni iş tekliflerini kesintisiz dinler',
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
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  static Future<bool> requestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
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
          ? 'Yeni iş teklifleri uyku modunda da anlık dinleniyor...'
          : 'Teklif yanıtları uyku modunda da anlık dinleniyor...';

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
    'wss://offchain.pub',
    'wss://relay.damus.io',
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
      if (_sockets.containsKey(url)) {
        final existingWs = _sockets[url];
        if (existingWs?.readyState == WebSocket.open) continue;
        try {
          existingWs?.close();
        } catch (_) {}
        _sockets.remove(url);
      }

      try {
        final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 8));
        // Critical Keep-Alive Ping Interval to survive mobile doze and carrier NAT drop
        ws.pingInterval = const Duration(seconds: 15);
        _sockets[url] = ws;

        final subId = 'bg_sub_${cleanPub.substring(0, cleanPub.length >= 8 ? 8 : cleanPub.length)}';
        _sendSubscription(ws, subId, cleanPub);

        ws.listen(
          (msg) => _handleRelayIncoming(ws, subId, cleanPub, msg.toString()),
          onError: (e) {
            debugPrint('[BackgroundService] Socket error on $url: $e');
            _sockets.remove(url);
          },
          onDone: () {
            debugPrint('[BackgroundService] Socket closed on $url');
            _sockets.remove(url);
          },
        );
        debugPrint('[BackgroundService] Connected and subscribed to $url for #p: $cleanPub');
      } catch (e) {
        debugPrint('[BackgroundService] Connect error for $url: $e');
      }
    }
  }

  void _sendSubscription(WebSocket ws, String subId, String cleanPub) {
    try {
      ws.add(json.encode([
        'REQ',
        subId,
        {
          'kinds': [21000],
          '#p': [cleanPub],
        }
      ]));
    } catch (e) {
      debugPrint('[BackgroundService] Failed to send REQ: $e');
    }
  }

  void _handleRelayIncoming(WebSocket ws, String subId, String cleanPub, String rawMsg) {
    try {
      final parsed = json.decode(rawMsg) as List;
      if (parsed.isEmpty) return;
      final type = parsed[0] as String?;

      if (type == 'EVENT') {
        _handleMessage(rawMsg);
      } else if (type == 'CLOSED') {
        debugPrint('[BackgroundService] Relay closed subscription $subId, renewing...');
        _sendSubscription(ws, subId, cleanPub);
      }
    } catch (_) {}
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

            // 1. Persist directly to disk for 100% offline sync across isolates
            await _persistBackgroundOffer(offerMap);

            // 2. High priority notification banner with sound and vibration
            await NotificationService().showOfferNotification(
              companyName: companyName,
              title: projectTitle,
              budget: budget,
            );

            // 3. Update sticky foreground notification
            await FlutterForegroundTask.updateService(
              notificationTitle: '📬 Yeni İş Teklifi Geldi!',
              notificationText: '$companyName: $projectTitle ($budget)',
            );

            // 4. Send event to main isolate if running
            try {
              FlutterForegroundTask.sendDataToMain({
                'type': 'OFFER_DIRECT',
                'offer': offerMap,
              });
            } catch (_) {}
          }
        } else if (type == 'OFFER_RESPONSE') {
          final offerId = data['offerId'] as String?;
          final status = data['status'] as String?;
          final draftsmanName = data['draftsmanName'] as String? ?? 'Teknik Ressam';

          // 1. Persist response directly to disk
          if (offerId != null) {
            await _persistBackgroundOfferResponse(data);
          }

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

          // Send event to main isolate if running
          try {
            FlutterForegroundTask.sendDataToMain({
              'type': 'OFFER_RESPONSE',
              'data': data,
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[BackgroundService] Message decode error: $e');
    }
  }

  Future<void> _persistBackgroundOffer(Map<String, dynamic> offerMap) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pendingDir = Directory('${dir.path}/pending_bg_offers');
      if (!await pendingDir.exists()) {
        await pendingDir.create(recursive: true);
      }
      final offerId = offerMap['id'] as String? ?? 'offer_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${pendingDir.path}/offer_$offerId.json');
      await file.writeAsString(json.encode(offerMap));
      debugPrint('[BackgroundService] Successfully persisted background offer: $offerId');
    } catch (e) {
      debugPrint('[BackgroundService] Error persisting offer: $e');
    }
  }

  Future<void> _persistBackgroundOfferResponse(Map<String, dynamic> responseData) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pendingDir = Directory('${dir.path}/pending_bg_offers');
      if (!await pendingDir.exists()) {
        await pendingDir.create(recursive: true);
      }
      final offerId = responseData['offerId'] as String? ?? 'resp_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${pendingDir.path}/response_$offerId.json');
      await file.writeAsString(json.encode(responseData));
      debugPrint('[BackgroundService] Successfully persisted background offer response: $offerId');
    } catch (e) {
      debugPrint('[BackgroundService] Error persisting response: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Purge stale or half-closed sockets
    for (final entry in _sockets.entries.toList()) {
      if (entry.value.readyState != WebSocket.open) {
        try {
          entry.value.close();
        } catch (_) {}
        _sockets.remove(entry.key);
      }
    }

    // Reconnect any missing or dropped relays
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
