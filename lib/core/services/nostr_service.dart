import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nostr/nostr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/user_profile.dart';
import '../models/offer_model.dart';
import '../utils/pwa_helper.dart';
import 'local_db_service.dart';
import 'notification_service.dart';

/// Rock-solid length-prefixed framing protocol for direct LAN TCP sockets
class FrameProtocol {
  static void send(Socket socket, List<int> data) {
    final header = ByteData(4)..setUint32(0, data.length);
    socket.add(header.buffer.asUint8List());
    socket.add(data);
  }

  static Stream<Uint8List> readFrames(Socket socket) async* {
    final buffer = BytesBuilder(copy: false);
    int? expectedLength;

    await for (final chunk in socket) {
      buffer.add(chunk);
      while (true) {
        if (expectedLength == null) {
          if (buffer.length < 4) break;
          final bytes = buffer.takeBytes();
          final bd = ByteData.sublistView(bytes);
          expectedLength = bd.getUint32(0);
          final remaining = bytes.sublist(4);
          buffer.add(remaining);
        }

        final expLen = expectedLength;
        if (buffer.length < expLen) break;
        final bytes = buffer.takeBytes();
        final frame = bytes.sublist(0, expLen);
        final remaining = bytes.sublist(expLen);
        if (remaining.isNotEmpty) {
          buffer.add(remaining);
        }
        expectedLength = null;
        yield Uint8List.fromList(frame);
      }
    }
  }
}

/// Zero-Server Decentralized Nostr Engine with Multi-Relay Pooling & Local LAN Mesh
class NostrService {
  static final NostrService _instance = NostrService._internal();
  factory NostrService() => _instance;
  NostrService._internal();

  final _localDb = LocalDbService();

  static const List<String> defaultRelays = [
    'wss://nos.lol',
    'wss://relay.primal.net',
    'wss://nostr.mom',
    'wss://relay.damus.io',
    'wss://offchain.pub',
  ];

  static const String appNetworkTag = 'ko_apps_teknikressam_v2';
  static const List<String> discoveryTags = [
    'ko_apps_teknikressam',
    'ko_apps_teknikressam_v2',
    'ko_apps_teknikressam_v3',
    'ko_apps_tr',
    'çelik_yapı_&_konstrüksiyon',
    'betonarme_&_statik',
    'harita_&_altyapı',
    'mekanik_&_tesisat_&_hvac',
    'elektrik_&_otomasyon',
    'mimari_&_cephe_çizimi',
    'makine_&_endüstriyel_imalat',
  ];
  static const int _lanUdpPort = 45454;
  static const int _lanTcpPort = 45455;

  final Map<String, WebSocketChannel> _activeRelays = {};
  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;

  UserProfile? _currentUser;
  Keys? _keys;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _draftsmenDebounceTimer;

  final Map<String, Map<String, dynamic>> _discoveredDraftsmen = {};
  final Map<String, Map<String, dynamic>> _discoveredCompanies = {};
  final Set<String> _deletedCandidateIds = {};
  final Map<String, Completer<String?>> _pendingFileCompleters = {};
  final Map<String, Map<int, String>> _incomingFileChunks = {};
  final Map<String, String> _downloadedFilesBase64 = {};

  StreamController<List<Map<String, dynamic>>> _draftsmenController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  StreamController<OfferModel> _incomingOfferController =
      StreamController<OfferModel>.broadcast();
  StreamController<Map<String, dynamic>> _offerResponseController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  final List<Map<String, dynamic>> _networkAuditLogs = [];
  StreamController<List<Map<String, dynamic>>> _auditLogsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  StreamController<List<Map<String, dynamic>>> _companiesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get discoveredDraftsmenStream => _draftsmenController.stream;
  List<Map<String, dynamic>> get discoveredDraftsmen => _discoveredDraftsmen.values.toList();
  List<Map<String, dynamic>> get discoveredCompanies => _discoveredCompanies.values.toList();
  Stream<List<Map<String, dynamic>>> get discoveredCompaniesStream => _companiesController.stream;
  Stream<List<Map<String, dynamic>>> get auditLogsStream => _auditLogsController.stream;
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_networkAuditLogs);
  Stream<OfferModel> get incomingOfferStream => _incomingOfferController.stream;
  Stream<Map<String, dynamic>> get offerResponseStream => _offerResponseController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;

  void _safeAddConnectionStatus(String status) {
    if (_connectionStatusController.isClosed) {
      _connectionStatusController = StreamController<String>.broadcast();
    }
    _connectionStatusController.add(status);
  }

  void _safeAddDraftsmen(List<Map<String, dynamic>> list) {
    if (_draftsmenController.isClosed) {
      _draftsmenController = StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    _draftsmenController.add(list);
  }

  void _safeAddCompanies(List<Map<String, dynamic>> list) {
    if (_companiesController.isClosed) {
      _companiesController = StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    _companiesController.add(list);
  }

  void _safeAddOffer(OfferModel offer) {
    if (_incomingOfferController.isClosed) {
      _incomingOfferController = StreamController<OfferModel>.broadcast();
    }
    _incomingOfferController.add(offer);
  }

  void _safeAddResponse(Map<String, dynamic> response) {
    if (_offerResponseController.isClosed) {
      _offerResponseController = StreamController<Map<String, dynamic>>.broadcast();
    }
    _offerResponseController.add(response);
  }

  void _addAuditLog(Map<String, dynamic> log) {
    _networkAuditLogs.insert(0, log);
    if (_networkAuditLogs.length > 250) {
      _networkAuditLogs.removeLast();
    }
    if (_auditLogsController.isClosed) {
      _auditLogsController = StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    _auditLogsController.add(List.unmodifiable(_networkAuditLogs));
  }

  bool get isConnected => _activeRelays.isNotEmpty;
  int get activeRelaysCount => _activeRelays.length;
  List<String> get connectedRelayUrls => _activeRelays.keys.toList();

  String get connectionStatus {
    if (_activeRelays.isEmpty) return 'Röleler Aranıyor...';
    return 'Nostr Çevrimiçi (${_activeRelays.length} Röle)';
  }

  void clearDiscoveredDraftsmen() {
    _discoveredDraftsmen.clear();
    _safeAddDraftsmen([]);
    debugPrint('All discovered draftsmen cleared from memory and stream.');
  }

  String cleanHex64(String input) => _cleanHex64(input);

  Future<void> deleteCandidate(String rawId) async {
    final clean = _cleanHex64(rawId);

    // 1. Add all identifier formats to the in-memory deleted set
    _deletedCandidateIds.add(rawId);
    if (clean.isNotEmpty) {
      _deletedCandidateIds.add(clean);
      _deletedCandidateIds.add('did:nostr:$clean');
    }

    // 2. Persist to local database
    await _localDb.addDeletedCandidate(rawId);
    if (clean.isNotEmpty && clean != rawId) {
      await _localDb.addDeletedCandidate(clean);
      await _localDb.addDeletedCandidate('did:nostr:$clean');
    }

    // 3. Purge from discovered draftsmen
    _discoveredDraftsmen.remove(rawId);
    if (clean.isNotEmpty) {
      _discoveredDraftsmen.remove(clean);
      _discoveredDraftsmen.remove('did:nostr:$clean');
      _discoveredDraftsmen.removeWhere((k, v) {
        final id = v['id'] as String? ?? '';
        final pk = v['publicKey'] as String? ?? '';
        return k == rawId ||
            k == clean ||
            id == rawId ||
            id == clean ||
            pk == rawId ||
            pk == clean ||
            (clean.isNotEmpty && _cleanHex64(pk) == clean) ||
            (clean.isNotEmpty && _cleanHex64(id) == clean);
      });
    }

    // 4. Purge from discovered companies
    _discoveredCompanies.remove(rawId);
    if (clean.isNotEmpty) {
      _discoveredCompanies.remove(clean);
      _discoveredCompanies.remove('did:nostr:$clean');
      _discoveredCompanies.removeWhere((k, v) {
        final id = v['id'] as String? ?? '';
        final pk = v['publicKey'] as String? ?? '';
        return k == rawId ||
            k == clean ||
            id == rawId ||
            id == clean ||
            pk == rawId ||
            pk == clean ||
            (clean.isNotEmpty && _cleanHex64(pk) == clean) ||
            (clean.isNotEmpty && _cleanHex64(id) == clean);
      });
    }

    // 5. Notify both streams to immediately update UI
    _safeAddDraftsmen(_discoveredDraftsmen.values.toList());
    _safeAddCompanies(_discoveredCompanies.values.toList());

    debugPrint('Account $rawId ($clean) permanently purged from discovery lists.');
  }

  Future<void> broadcastModerationDelete(String rawId) async {
    await deleteCandidate(rawId);
    if (_keys == null) return;
    try {
      final clean = _cleanHex64(rawId);
      final tags = <List<String>>[
        ['p', rawId],
        if (clean.isNotEmpty && clean != rawId) ['p', clean],
        ['t', 'ko_apps_teknikressam'],
        ['t', 'moderation_ban'],
      ];
      final event = Event.from(
        kind: 5,
        content: 'Account removed by KO|Apps admin',
        secretKey: _keys!.secret,
        tags: tags,
      );
      _publishEventToPool(event);
      debugPrint('Moderation deletion event published to relays for $rawId ($clean)');
    } catch (e) {
      debugPrint('Error broadcasting moderation delete: $e');
    }
  }

  Future<void> clearDeletedCandidates() async {
    _deletedCandidateIds.clear();
    await _localDb.clearDeletedCandidates();
    _discoveredDraftsmen.clear();
    _discoveredCompanies.clear();
    _safeAddDraftsmen([]);
    _safeAddCompanies([]);
    await queryDraftsmen();
    debugPrint('Cleared deleted candidates and rescanning network...');
  }

  String _cleanHex64(String input) {
    final clean = input
        .replaceAll('did:nostr:', '')
        .replaceAll('did:ko:tr:', '')
        .replaceAll('did:ko:comp:', '')
        .trim();
    final match = RegExp(r'[0-9a-fA-F]{64}').firstMatch(clean);
    return match != null ? match.group(0)! : clean;
  }

  /// Starts both Nostr Relay Pool and LAN Direct discovery
  Future<void> start({required UserProfile userProfile}) async {
    _currentUser = userProfile;
    final cleanPriv = _cleanHex64(userProfile.privateKey);
    try {
      if (RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(cleanPriv)) {
        _keys = Keys(cleanPriv);
      } else {
        _keys = Keys.generate();
        final updated = userProfile.copyWith(
          privateKey: _keys!.secret,
          publicKey: _keys!.public,
          id: 'did:nostr:${_keys!.public}',
        );
        _currentUser = updated;
        await _localDb.saveUserProfile(updated);
      }
    } catch (_) {
      _keys = Keys.generate();
      final updated = userProfile.copyWith(
        privateKey: _keys!.secret,
        publicKey: _keys!.public,
        id: 'did:nostr:${_keys!.public}',
      );
      _currentUser = updated;
      await _localDb.saveUserProfile(updated);
    }

    final savedDeleted = await _localDb.getDeletedCandidates();
    _deletedCandidateIds.addAll(savedDeleted);

    _safeAddConnectionStatus('Nostr Ağına Bağlanılıyor...');

    // 1. Start Local LAN Direct Engine (Instant sub-1ms Wi-Fi discovery & transfer)
    await _startLanEngine();

    // 2. Connect to Nostr Decentralized Relay Pool (asynchronous background connect)
    unawaited(_connectToRelayPool().then((_) {
      if (_currentUser != null) {
        broadcastProfile(_currentUser!);
      }
    }).catchError((e) {
      debugPrint('Error in relay pool connection: $e');
    }));

    // 3. Setup periodic monitoring
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 25), (_) => _checkRelayHealth());

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 35), (_) {
      if (_currentUser != null) {
        broadcastProfile(_currentUser!);
      }
    });

    if (_currentUser?.role != 'draftsman') {
      unawaited(queryDraftsmen());
    }
  }

  // ==========================================
  // 1. LAN DIRECT ENGINE (UDP & TCP SOCKETS)
  // ==========================================

  Future<void> _startLanEngine() async {
    if (kIsWeb) return;
    try {
      _udpSocket?.close();
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _lanUdpPort,
          reuseAddress: true,
          reusePort: true,
        );
      } catch (_) {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _lanUdpPort,
          reuseAddress: true,
          reusePort: false,
        );
      }
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleLanDatagram(datagram);
          }
        }
      });

      if (_currentUser?.role == 'draftsman') {
        _tcpServer?.close();
        _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, _lanTcpPort, shared: true);
        _tcpServer!.listen(_handleIncomingTcpConnection);
        debugPrint('LAN TCP Server listening on port $_lanTcpPort');
      }
    } catch (e) {
      debugPrint('LAN Engine init error: $e');
    }
  }

  void _handleLanDatagram(Datagram datagram) {
    try {
      final raw = utf8.decode(datagram.data).trim();
      if (raw.isEmpty) return;

      final data = json.decode(raw) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'DRAFTSMAN_PRESENCE') {
        if (_currentUser?.role != 'draftsman') {
          final profileMap = data['profile'] as Map<String, dynamic>?;
          if (profileMap != null) {
            profileMap['lanIp'] = datagram.address.address;
            profileMap['lanPort'] = _lanTcpPort;
            _handleDiscoveredCandidate(profileMap);
          }
        }
      } else if (type == 'QUERY_DRAFTSMEN') {
        if (_currentUser?.role == 'draftsman') {
          _sendLanPresence();
        }
      } else if (type == 'OFFER_RESPONSE') {
        if (_currentUser?.role != 'draftsman') {
          _handleIncomingOfferResponse(data);
        }
      }
    } catch (e) {
      debugPrint('LAN datagram parse error: $e');
    }
  }

  Future<void> _sendLanBroadcast(String payload) async {
    if (kIsWeb || _udpSocket == null) return;
    try {
      final bytes = utf8.encode(payload);
      try {
        _udpSocket!.send(bytes, InternetAddress('255.255.255.255'), _lanUdpPort);
      } catch (_) {}

      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              try {
                _udpSocket!.send(bytes, InternetAddress(subnet), _lanUdpPort);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('LAN broadcast error: $e');
    }
  }

  Future<void> _sendLanPresence() async {
    if (_currentUser == null || _currentUser!.role != 'draftsman' || !_currentUser!.isAvailable) return;
    final payload = json.encode({
      'type': 'DRAFTSMAN_PRESENCE',
      'profile': _currentUser!.toPublicSummaryMap(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _sendLanBroadcast(payload);
  }

  void _handleIncomingTcpConnection(Socket socket) {
    final buffer = BytesBuilder(copy: false);
    int? expectedLength;

    socket.listen((chunk) async {
      try {
        buffer.add(chunk);
        final bytes = buffer.toBytes();
        if (bytes.isEmpty) return;

        if (bytes[0] == 0x7B) {
          final raw = utf8.decode(bytes).trim();
          if (raw.endsWith('}')) {
            final data = json.decode(raw) as Map<String, dynamic>;
            await _processTcpPayload(socket, data);
            buffer.clear();
          }
        } else {
          while (true) {
            if (expectedLength == null) {
              if (buffer.length < 4) break;
              final current = buffer.takeBytes();
              final bd = ByteData.sublistView(current);
              expectedLength = bd.getUint32(0);
              buffer.add(current.sublist(4));
            }

            if (expectedLength != null) {
              if (buffer.length < expectedLength!) break;
              final current = buffer.takeBytes();
              final frame = current.sublist(0, expectedLength!);
              buffer.add(current.sublist(expectedLength!));
              expectedLength = null;

              final data = json.decode(utf8.decode(frame)) as Map<String, dynamic>;
              await _processTcpPayload(socket, data);
            }
          }
        }
      } catch (e) {
        debugPrint('TCP connection chunk error: $e');
      }
    }, onError: (e) {
      debugPrint('TCP connection error: $e');
      socket.close();
    });
  }

  Future<void> _processTcpPayload(Socket socket, Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String?;

      if (type == 'OFFER_DIRECT') {
        final offerData = data['offer'];
        if (offerData != null) {
          final offer = OfferModel.fromMap(Map<String, dynamic>.from(offerData as Map));
          final isNew = await _localDb.saveOfferIfNew(offer);
          if (isNew) {
            _safeAddOffer(offer);
            await NotificationService().showOfferNotification(
              companyName: offer.companyName,
              title: offer.projectTitle,
              budget: offer.budget,
            );
          }
        }
        socket.write(json.encode({'status': 'RECEIVED'}));
        await socket.flush();
        await socket.close();
      } else if (type == 'OFFER_RESPONSE') {
        await _handleIncomingOfferResponse(data);
        socket.write(json.encode({'status': 'RECEIVED'}));
        await socket.flush();
        await socket.close();
      } else if (type == 'GET_PORTFOLIO_FILE') {
        final fileId = data['fileId'] as String?;
        if (fileId != null) {
          final profile = await _localDb.getUserProfile();
          PortfolioFile? targetFile;
          for (final f in (profile?.portfolioFiles ?? [])) {
            if (f.id == fileId) {
              targetFile = f;
              break;
            }
          }
          if (targetFile != null && targetFile.filePath.isNotEmpty) {
            final fileObj = File(targetFile.filePath);
            if (await fileObj.exists()) {
              final fileBytes = await fileObj.readAsBytes();
              final reply = utf8.encode(json.encode({
                'status': 'OK',
                'type': 'PORTFOLIO_FILE_DATA',
                'fileId': fileId,
                'fileName': targetFile.fileName,
                'extension': targetFile.fileExtension,
                'fileSize': fileBytes.length,
                'base64': base64Encode(fileBytes),
              }));
              FrameProtocol.send(socket, reply);
              await socket.flush();
              debugPrint('LAN TCP transferred file ${targetFile.fileName} (${fileBytes.length} bytes)');
              await socket.close();
              return;
            }
          }
        }
        final err = utf8.encode(json.encode({'status': 'ERROR', 'message': 'Dosya bulunamadı'}));
        FrameProtocol.send(socket, err);
        await socket.flush();
        await socket.close();
      }
    } catch (e) {
      debugPrint('TCP process error: $e');
      await socket.close();
    }
  }

  // ==========================================
  // 2. NOSTR RELAY POOL (WSS PORT 443 E2EE)
  // ==========================================

  Future<void> _connectToRelayPool() async {
    final futures = defaultRelays.map((relayUrl) => _connectSingleRelay(relayUrl));
    await Future.wait(futures);
  }

  Future<void> _connectSingleRelay(String relayUrl) async {
    if (_activeRelays.containsKey(relayUrl)) return;
    try {
      debugPrint('Connecting to Nostr relay $relayUrl...');
      final ws = WebSocketChannel.connect(Uri.parse(relayUrl));
      await ws.ready.timeout(const Duration(seconds: 10));
      _activeRelays[relayUrl] = ws;
      debugPrint('Connected to Nostr relay: $relayUrl');

      _safeAddConnectionStatus('Nostr Çevrimiçi (${_activeRelays.length} Röle)');

      // Subscribe to relevant messages
      _subscribeRelay(ws, relayUrl);

      // If draftsman, immediately broadcast to newly connected relay
      if (_currentUser?.role == 'draftsman' && _keys != null) {
        final summary = _currentUser!.toPublicSummaryMap();
        summary['publicKey'] = _keys!.public;
        final event = Event.from(
          kind: 0,
          content: json.encode(summary),
          secretKey: _keys!.secret,
          tags: [
            ['t', 'ko_apps_teknikressam'],
            ['t', appNetworkTag],
            ['t', _currentUser!.branch.toLowerCase().replaceAll(RegExp(r'\s+'), '_')],
            ['role', _currentUser!.role],
          ],
        );
        ws.sink.add(json.encode(['EVENT', event.toMap()]));
        debugPrint('Immediately published draftsman profile to connected relay $relayUrl');
      }

      ws.stream.listen(
        (msg) => _handleRelayMessage(msg, relayUrl),
        onDone: () {
          debugPrint('Nostr relay disconnected: $relayUrl');
          _activeRelays.remove(relayUrl);
          _safeAddConnectionStatus('Nostr (${_activeRelays.length} Röle)');
        },
        onError: (err) {
          debugPrint('Nostr relay error on $relayUrl: $err');
          _activeRelays.remove(relayUrl);
          _safeAddConnectionStatus('Nostr (${_activeRelays.length} Röle)');
        },
      );
    } catch (e) {
      debugPrint('Could not connect to Nostr relay $relayUrl: $e');
    }
  }

  void _subscribeRelay(WebSocketChannel ws, String relayUrl) {
    if (_keys == null) return;

    // 1. Subscribe to personal encrypted incoming events (Kind 21000 with tag #p = my public key)
    final subOffers = 'sub_offers_${_keys!.public.substring(0, 8)}';
    ws.sink.add(json.encode([
      'REQ',
      subOffers,
      {
        'kinds': [21000],
        '#p': [_keys!.public],
      }
    ]));

    // 2. If Company, also subscribe to all Draftsmen profiles and moderation events
    if (_currentUser?.role != 'draftsman') {
      const subDiscovery = 'sub_discovery_company';
      ws.sink.add(json.encode([
        'REQ',
        subDiscovery,
        {
          'kinds': [0, 5],
          '#t': discoveryTags,
          'limit': 250,
        },
      ]));
    }
  }

  Future<void> _handleRelayMessage(dynamic rawMsg, String relayUrl) async {
    try {
      final parsed = json.decode(rawMsg.toString()) as List;
      if (parsed.isEmpty) return;

      final msgType = parsed[0] as String;

      if (msgType == 'EVENT') {
        final eventMap = parsed[2] as Map<String, dynamic>;
        await _processNostrEvent(eventMap);
      }
    } catch (e) {
      debugPrint('Relay message parse error from $relayUrl: $e');
    }
  }

  Future<void> _processNostrEvent(Map<String, dynamic> event) async {
    final kind = event['kind'] as int?;
    final senderPubkey = event['pubkey'] as String?;
    final content = event['content'] as String? ?? '';
    final createdAt = event['created_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch((event['created_at'] as int) * 1000)
        : DateTime.now();

    if (kind == 0) {
      // Profile Metadata Event
      try {
        final profileData = json.decode(content) as Map<String, dynamic>;
        final role = profileData['role'] as String?;
        final rawPk = (profileData['publicKey'] as String?)?.isNotEmpty == true
            ? profileData['publicKey'] as String
            : (senderPubkey ?? '');
        final cleanPk = _cleanHex64(rawPk);
        final rawId = profileData['id'] as String? ?? '';
        final cleanId = _cleanHex64(rawId);
        final cleanSender = senderPubkey != null ? _cleanHex64(senderPubkey) : '';

        // Check if this account was deleted / moderated
        final isDeleted = (senderPubkey != null && _deletedCandidateIds.contains(senderPubkey)) ||
            (cleanSender.isNotEmpty && _deletedCandidateIds.contains(cleanSender)) ||
            (rawPk.isNotEmpty && _deletedCandidateIds.contains(rawPk)) ||
            (cleanPk.isNotEmpty && _deletedCandidateIds.contains(cleanPk)) ||
            (rawId.isNotEmpty && _deletedCandidateIds.contains(rawId)) ||
            (cleanId.isNotEmpty && _deletedCandidateIds.contains(cleanId));

        if (isDeleted) {
          debugPrint('Filtered out profile for deleted account: $rawPk ($cleanPk)');
          return;
        }

        profileData['id'] = senderPubkey ?? profileData['id'];
        profileData['publicKey'] = senderPubkey ?? profileData['publicKey'];

        _addAuditLog({
          'type': 'PROFILE',
          'event': role == 'company' ? 'Şirket Profili' : 'Teknik Ressam Profili',
          'name': profileData['name'] ?? 'İsimsiz',
          'branch': profileData['branch'] ?? '',
          'city': profileData['city'] ?? '',
          'pubkey': senderPubkey ?? '',
          'role': role ?? 'draftsman',
          'timestamp': createdAt,
        });

        if (role == 'company') {
          final key = cleanPk.isNotEmpty ? cleanPk : rawPk;
          if (key.isNotEmpty) {
            _discoveredCompanies[key] = profileData;
            _safeAddCompanies(_discoveredCompanies.values.toList());
          }
        } else if (_currentUser?.role != 'draftsman') {
          _handleDiscoveredCandidate(profileData);
        }
      } catch (_) {}
    } else if (kind == 5) {
      // Moderation Deletion Event (NIP-09)
      try {
        final tags = event['tags'] as List? ?? [];
        String targetPubkey = '';
        for (final t in tags) {
          if (t is List && t.length >= 2 && t[0] == 'p') {
            targetPubkey = t[1] as String;
            deleteCandidate(targetPubkey);
          }
        }
        _addAuditLog({
          'type': 'DELETION',
          'event': 'Hesap Silme Talebi (Kind 5)',
          'pubkey': senderPubkey ?? '',
          'target': targetPubkey.isNotEmpty ? targetPubkey : (senderPubkey ?? ''),
          'reason': content.isNotEmpty ? content : 'Kullanıcı bizzat sildi',
          'isSelfDelete': targetPubkey.isEmpty || targetPubkey == senderPubkey,
          'timestamp': createdAt,
        });
      } catch (_) {}
    } else if (kind == 21000) {
      _addAuditLog({
        'type': 'TRAFFIC',
        'event': 'Şifreli P2P Paket (Kind 21000)',
        'pubkey': senderPubkey != null && senderPubkey.length > 12 ? '${senderPubkey.substring(0, 10)}...' : 'P2P',
        'note': 'Uçtan uca şifreli veri (Mahremiyet korumalı)',
        'timestamp': createdAt,
      });

      // Encrypted Direct Application Event (Offers / Responses / File Chunks)
      if (_keys == null || senderPubkey == null) return;

      try {
        final decryptedJson = await Encryption.decrypt(
          payload: content,
          recipientSecretKey: _keys!.secret,
          senderPubkey: senderPubkey,
        );

        final data = json.decode(decryptedJson) as Map<String, dynamic>;
        final eventType = data['type'] as String?;

        if (eventType == 'OFFER_DIRECT') {
          final offerMap = data['offer'] as Map<String, dynamic>?;
          if (offerMap != null) {
            final offer = OfferModel.fromMap(offerMap);
            final isNew = await _localDb.saveOfferIfNew(offer);
            if (isNew) {
              _safeAddOffer(offer);
              debugPrint('Brand new encrypted offer received from Nostr: ${offer.companyName}');
              await NotificationService().showOfferNotification(
                companyName: offer.companyName,
                title: offer.projectTitle,
                budget: offer.budget,
              );
            } else {
              debugPrint('Ignored replayed/existing offer from Nostr relay: ${offer.id}');
            }
          }
        } else if (eventType == 'OFFER_RESPONSE') {
          await _handleIncomingOfferResponse(data);
        } else if (eventType == 'GET_PORTFOLIO_FILE') {
          await _handleNostrGetPortfolioFile(data, senderPubkey);
        } else if (eventType == 'PORTFOLIO_FILE_DATA') {
          await _handleNostrPortfolioFileData(data);
        }
      } catch (e) {
        debugPrint('Error decrypting Nostr event: $e');
      }
    } else if (kind == 1063) {
      // Decentralized File Storage Event (NIP-94)
      try {
        final tags = event['tags'] as List? ?? [];
        String fileId = '';
        String fileName = '';
        int chunkIdx = 0;
        int totalChunks = 1;
        for (final t in tags) {
          if (t is List && t.length >= 2) {
            final key = t[0] as String;
            if (key == 'f') fileId = t[1] as String;
            if (key == 'name') fileName = t[1] as String;
            if (key == 'chunk' && t.length >= 3) {
              chunkIdx = int.tryParse(t[1] as String) ?? 0;
              totalChunks = int.tryParse(t[2] as String) ?? 1;
            }
          }
        }
        if (fileId.isNotEmpty && content.isNotEmpty) {
          await _handleIncomingFileChunk(
            fileId: fileId,
            fileName: fileName,
            chunkIndex: chunkIdx,
            totalChunks: totalChunks,
            chunkData: content,
          );
        }
      } catch (e) {
        debugPrint('Error handling kind 1063 file event: $e');
      }
    }
  }

  Future<void> _handleIncomingFileChunk({
    required String fileId,
    required String fileName,
    required int chunkIndex,
    required int totalChunks,
    required String chunkData,
  }) async {
    _incomingFileChunks.putIfAbsent(fileId, () => {});
    _incomingFileChunks[fileId]![chunkIndex] = chunkData;

    if (_incomingFileChunks[fileId]!.length >= totalChunks) {
      final buffer = StringBuffer();
      for (int i = 0; i < totalChunks; i++) {
        buffer.write(_incomingFileChunks[fileId]![i] ?? '');
      }
      final fullBase64 = buffer.toString();
      _downloadedFilesBase64[fileId] = fullBase64;
      _incomingFileChunks.remove(fileId);

      String? savePath;
      if (kIsWeb) {
        PWAHelper.downloadBase64File(fullBase64, fileName);
        savePath = 'web_downloaded';
      } else {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final downloadsDir = Directory('${appDocDir.path}/p2p_downloads');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final cleanFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          savePath = '${downloadsDir.path}/${fileId}_$cleanFileName';
          final file = File(savePath);
          await file.writeAsBytes(base64Decode(fullBase64));
        } catch (e) {
          debugPrint('Error writing assembled file: $e');
        }
      }

      if (_pendingFileCompleters.containsKey(fileId)) {
        if (!_pendingFileCompleters[fileId]!.isCompleted) {
          _pendingFileCompleters[fileId]!.complete(savePath);
        }
        _pendingFileCompleters.remove(fileId);
      }
    }
  }

  void _handleDiscoveredCandidate(Map<String, dynamic> profileMap) {
    if (_currentUser?.role == 'draftsman') return;

    final name = (profileMap['name'] as String? ?? '').trim();
    final lowerName = name.toLowerCase();
    if (name.isEmpty || lowerName == 'null' || lowerName == 'dummy') {
      return;
    }

    final branch = (profileMap['branch'] as String? ?? '').trim();
    if (branch.isEmpty || branch.toLowerCase() == 'null') {
      return;
    }

    // Filter out dummy/empty test accounts
    if (lowerName == 'dummy' || lowerName == 'test dummy') {
      return;
    }

    final rawKey = profileMap['publicKey'] as String? ?? profileMap['id'] as String?;
    if (rawKey == null) return;
    final peerId = _cleanHex64(rawKey);
    if (peerId.isEmpty || peerId == _keys?.public || peerId == _cleanHex64(_currentUser?.id ?? '')) return;
    if (_deletedCandidateIds.contains(peerId)) return;

    profileMap['id'] = peerId;
    profileMap['publicKey'] = peerId;

    final existing = _discoveredDraftsmen[peerId];
    bool hasChanged = false;

    if (existing == null) {
      _discoveredDraftsmen[peerId] = profileMap;
      hasChanged = true;
    } else {
      // Preserve LAN IP and Avatar if incoming event (e.g. from Nostr relay) does not include them
      if (profileMap['lanIp'] == null && existing['lanIp'] != null) {
        profileMap['lanIp'] = existing['lanIp'];
      }
      if (profileMap['avatarBase64'] == null && existing['avatarBase64'] != null) {
        profileMap['avatarBase64'] = existing['avatarBase64'];
      }

      final oldName = existing['name'];
      final oldAvailable = existing['isAvailable'];
      final oldIp = existing['lanIp'];
      final oldPortfolioCount = existing['portfolioCount'];
      final oldAvatar = existing['avatarBase64'];
      final oldVerified = existing['isVerified'];

      final newName = profileMap['name'];
      final newAvailable = profileMap['isAvailable'];
      final newIp = profileMap['lanIp'];
      final newPortfolioCount = profileMap['portfolioCount'];
      final newAvatar = profileMap['avatarBase64'];
      final newVerified = profileMap['isVerified'];

      if (oldName != newName ||
          oldAvailable != newAvailable ||
          oldIp != newIp ||
          oldPortfolioCount != newPortfolioCount ||
          oldAvatar != newAvatar ||
          oldVerified != newVerified) {
        existing.addAll(profileMap);
        hasChanged = true;
      }
    }

    if (hasChanged) {
      _draftsmenDebounceTimer?.cancel();
      _draftsmenDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        _safeAddDraftsmen(_discoveredDraftsmen.values.toList());
      });
      debugPrint('Candidate found/updated: ${profileMap['name']} (${profileMap['branch']})');
    }
  }

  Future<void> _handleIncomingOfferResponse(Map<String, dynamic> data) async {
    final offerId = data['offerId'] as String?;
    final status = data['status'] as String?;
    final note = data['note'] as String?;
    if (offerId == null || status == null) return;

    await _localDb.updateOfferStatus(
      offerId,
      status,
      responseNote: note,
      draftsmanEmail: data['draftsmanEmail'] as String?,
      draftsmanPhone: data['draftsmanPhone'] as String?,
      draftsmanCity: data['draftsmanCity'] as String?,
      draftsmanTitle: data['draftsmanTitle'] as String?,
      draftsmanBio: data['draftsmanBio'] as String?,
      draftsmanLinkedin: data['draftsmanLinkedin'] as String?,
      draftsmanKariyerNet: data['draftsmanKariyerNet'] as String?,
      draftsmanCvBase64: data['cvBase64'] as String?,
      draftsmanCvFileName: data['cvFileName'] as String?,
    );
    _safeAddResponse(data);
    debugPrint('Offer response received for $offerId: $status with contact details');
  }

  Future<void> _handleNostrGetPortfolioFile(Map<String, dynamic> data, String requesterPubkey) async {
    final fileId = data['fileId'] as String?;
    if (fileId == null || _keys == null) return;
    final profile = await _localDb.getUserProfile();
    PortfolioFile? targetFile;
    for (final f in (profile?.portfolioFiles ?? [])) {
      if (f.id == fileId) {
        targetFile = f;
        break;
      }
    }
    if (targetFile != null) {
      Uint8List? bytes;
      if (targetFile.fileBase64 != null && targetFile.fileBase64!.isNotEmpty) {
        try {
          bytes = base64Decode(targetFile.fileBase64!);
        } catch (_) {}
      } else if (!kIsWeb && targetFile.filePath.isNotEmpty) {
        try {
          final fileObj = File(targetFile.filePath);
          if (await fileObj.exists()) {
            bytes = await fileObj.readAsBytes();
          }
        } catch (_) {}
      }

      if (bytes != null && bytes.length <= 15 * 1024 * 1024) {
        final payload = json.encode({
          'type': 'PORTFOLIO_FILE_DATA',
          'fileId': fileId,
          'fileName': targetFile.fileName,
          'extension': targetFile.fileExtension,
          'base64': base64Encode(bytes),
        });
        final encrypted = await Encryption.encrypt(
          plaintext: payload,
          recipientPubkey: requesterPubkey,
          senderSecretKey: _keys!.secret,
        );
        final event = Event.from(
          kind: 21000,
          content: encrypted,
          secretKey: _keys!.secret,
          tags: [
            ['p', requesterPubkey],
            ['t', 'file_response']
          ],
        );
        _publishEventToPool(event);
        debugPrint('Nostr encrypted file sent: ${targetFile.fileName} (${bytes.length} bytes)');
      }
    }
  }

  Future<void> _handleNostrPortfolioFileData(Map<String, dynamic> data) async {
    final fileId = data['fileId'] as String?;
    final fileName = data['fileName'] as String? ?? 'drawing';
    final base64Str = data['base64'] as String?;
    if (fileId != null && base64Str != null) {
      _downloadedFilesBase64[fileId] = base64Str;
      String? savePath;
      if (kIsWeb) {
        PWAHelper.downloadBase64File(base64Str, fileName);
        savePath = 'web_downloaded';
      } else {
        try {
          final bytes = base64Decode(base64Str);
          final appDocDir = await getApplicationDocumentsDirectory();
          final downloadsDir = Directory('${appDocDir.path}/p2p_downloads');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final cleanFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          savePath = '${downloadsDir.path}/${fileId}_$cleanFileName';
          final file = File(savePath);
          await file.writeAsBytes(bytes);
          debugPrint('Nostr portfolio file saved to $savePath (${bytes.length} bytes)');
        } catch (e) {
          debugPrint('Error saving Nostr portfolio file: $e');
        }
      }

      if (_pendingFileCompleters.containsKey(fileId)) {
        _pendingFileCompleters[fileId]?.complete(savePath);
        _pendingFileCompleters.remove(fileId);
      }
    }
  }

  void _checkRelayHealth() {
    for (final relayUrl in defaultRelays) {
      if (!_activeRelays.containsKey(relayUrl)) {
        _connectSingleRelay(relayUrl);
      }
    }
  }

  // ==========================================
  // 3. PUBLIC METHODS (BROADCAST, OFFER, FILES)
  // ==========================================

  /// Broadcasts Profile as Nostr Kind 0 metadata + LAN UDP
  Future<void> broadcastProfile(UserProfile profile) async {
    _currentUser = profile;
    if (_keys == null) return;

    // Master Admin Stealth Modu: Admin hesabı normal şirket gibi ağa yayınlanmaz
    final nameLower = profile.name.toLowerCase();
    final isStealthAdmin = profile.role == 'company' &&
        (nameLower.contains('ko|apps') || nameLower.contains('ko apps') || nameLower.contains('ko-apps'));
    if (isStealthAdmin) {
      debugPrint('Master Admin stealth modunda; genel profil yayını yapılmıyor.');
      return;
    }

    // 1. LAN UDP Broadcast
    await _sendLanPresence();

    // 2. Nostr Kind 0 Event
    final summary = profile.toPublicSummaryMap();
    summary['publicKey'] = _keys!.public;

    final branchTag = profile.branch.isNotEmpty
        ? profile.branch.toLowerCase().replaceAll(RegExp(r'\s+'), '_')
        : 'şirket';

    final event = Event.from(
      kind: 0,
      content: json.encode(summary),
      secretKey: _keys!.secret,
      tags: [
        ['t', 'ko_apps_teknikressam'],
        ['t', appNetworkTag],
        ['t', branchTag],
        ['t', profile.role == 'company' ? 'şirket' : 'teknik_ressam'],
        ['role', profile.role],
      ],
    );

    _publishEventToPool(event);

    // 3. Decentralized File Storage on Nostr Relays (Kind 1063 NIP-94)
    if (profile.role == 'draftsman' && profile.portfolioFiles.isNotEmpty) {
      unawaited(_publishPortfolioFilesToRelays(profile.portfolioFiles));
    }
  }

  Future<void> _publishPortfolioFilesToRelays(List<PortfolioFile> files) async {
    if (_keys == null) return;
    for (final file in files) {
      String? b64 = file.fileBase64;
      if ((b64 == null || b64.isEmpty) && !kIsWeb && file.filePath.isNotEmpty) {
        try {
          final fObj = File(file.filePath);
          if (await fObj.exists()) {
            final b = await fObj.readAsBytes();
            if (b.length <= 15 * 1024 * 1024) {
              b64 = base64Encode(b);
            }
          }
        } catch (_) {}
      }

      if (b64 == null || b64.isEmpty) continue;

      const chunkSize = 40 * 1024;
      final totalChunks = (b64.length / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize < b64.length) ? start + chunkSize : b64.length;
        final chunkData = b64.substring(start, end);

        final event = Event.from(
          kind: 1063,
          content: chunkData,
          secretKey: _keys!.secret,
          tags: [
            ['f', file.id],
            ['name', file.fileName],
            ['ext', file.fileExtension],
            ['size', file.fileSize.toString()],
            ['desc', file.description],
            ['chunk', i.toString(), totalChunks.toString()],
            ['p', _keys!.public],
            ['t', 'portfolio_file'],
          ],
        );
        _publishEventToPool(event);
      }
    }
  }

  /// Scans both LAN and Nostr for draftsmen
  Future<void> queryDraftsmen({String branch = 'all'}) async {
    if (_currentUser?.role == 'draftsman') return;

    // 1. LAN UDP Ping
    final pingPayload = json.encode({
      'type': 'QUERY_DRAFTSMEN',
      'companyId': _keys?.public ?? _currentUser?.id,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _sendLanBroadcast(pingPayload);

    // 2. Nostr REQ to pool for all known tag versions and moderation events
    final subDiscovery = 'sub_disc_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final reqMsg = json.encode([
      'REQ',
      subDiscovery,
      {
        'kinds': [0, 5],
        '#t': discoveryTags,
        'limit': 250,
      },
    ]);

    for (final ws in _activeRelays.values) {
      try {
        ws.sink.add(reqMsg);
      } catch (e) {
        debugPrint('Error querying relay: $e');
      }
    }
  }

  /// Sends end-to-end encrypted offer using NIP-44 & LAN direct TCP fallback
  Future<bool> sendOfferToDraftsman({
    required OfferModel offer,
    required String draftsmanPeerId,
    required String draftsmanPublicKey,
  }) async {
    try {
      await _localDb.saveOffer(offer);
      if (_keys == null) return false;

      // 1. If candidate is on LAN, try direct TCP transfer first (native only)
      final candidateMeta = _discoveredDraftsmen[draftsmanPeerId] ?? _discoveredDraftsmen[draftsmanPublicKey];
      final lanIp = candidateMeta?['lanIp'] as String?;
      if (!kIsWeb && lanIp != null) {
        try {
          debugPrint('Attempting direct LAN TCP offer transfer to $lanIp:$_lanTcpPort...');
          final socket = await Socket.connect(lanIp, _lanTcpPort, timeout: const Duration(seconds: 2));
          final packet = json.encode({
            'type': 'OFFER_DIRECT',
            'from': _keys!.public,
            'fromName': _currentUser!.name,
            'offer': offer.toMap(),
          });
          socket.write(packet);
          await socket.flush();
          await socket.close();
          debugPrint('Offer delivered directly via LAN TCP to $lanIp!');
          return true;
        } catch (e) {
          debugPrint('LAN TCP fallback to Nostr: $e');
        }
      }

      // 2. Nostr NIP-44 End-to-End Encrypted Event (Kind 21000)
      final plainPayload = json.encode({
        'type': 'OFFER_DIRECT',
        'from': _keys!.public,
        'fromName': _currentUser?.name ?? 'İşveren Firma',
        'offer': offer.toMap(),
      });

      final rawTargetKey = draftsmanPublicKey.isNotEmpty ? draftsmanPublicKey : draftsmanPeerId;
      final targetPubkey = _cleanHex64(rawTargetKey);

      if (targetPubkey.length != 64) {
        debugPrint('Invalid targetPubkey length: ${targetPubkey.length} ($targetPubkey)');
        return false;
      }

      final cipherText = await Encryption.encrypt(
        plaintext: plainPayload,
        senderSecretKey: _keys!.secret,
        recipientPubkey: targetPubkey,
      );

      final event = Event.from(
        kind: 21000,
        content: cipherText,
        secretKey: _keys!.secret,
        tags: [
          ['p', targetPubkey],
          ['t', 'ko_apps_offer'],
          ['offerId', offer.id],
        ],
      );

      _publishEventToPool(event);
      debugPrint('Offer published to Nostr pool with ID: ${event.id} to recipient: $targetPubkey');
      return true;
    } catch (e) {
      debugPrint('Error sending Nostr offer: $e');
      return false;
    }
  }

  /// Sends end-to-end encrypted offer response
  Future<void> sendOfferResponse({
    required String offerId,
    required String companyPeerId,
    required String status,
    String? note,
    String? draftsmanEmail,
    String? draftsmanPhone,
    String? draftsmanCity,
    String? draftsmanTitle,
    String? draftsmanBio,
    String? draftsmanLinkedin,
    String? draftsmanKariyerNet,
  }) async {
    await _localDb.updateOfferStatus(
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
      draftsmanCvBase64: status == 'accepted' ? _currentUser?.cvBase64 : null,
      draftsmanCvFileName: status == 'accepted' ? _currentUser?.cvFileName : null,
    );
    if (_keys == null) return;

    final responseMap = {
      'type': 'OFFER_RESPONSE',
      'offerId': offerId,
      'draftsmanId': _keys!.public,
      'draftsmanName': _currentUser?.name ?? 'Teknik Ressam',
      'status': status,
      'note': note ?? '',
      'draftsmanEmail': status == 'accepted' ? (draftsmanEmail ?? _currentUser?.email ?? '') : '',
      'draftsmanPhone': status == 'accepted' ? (draftsmanPhone ?? _currentUser?.phone ?? '') : '',
      'draftsmanCity': status == 'accepted' ? (draftsmanCity ?? _currentUser?.city ?? '') : '',
      'draftsmanTitle': status == 'accepted' ? (draftsmanTitle ?? _currentUser?.title ?? '') : '',
      'draftsmanBio': status == 'accepted' ? (draftsmanBio ?? _currentUser?.bio ?? '') : '',
      'draftsmanLinkedin': status == 'accepted' ? (draftsmanLinkedin ?? _currentUser?.linkedinUrl ?? '') : '',
      'draftsmanKariyerNet': status == 'accepted' ? (draftsmanKariyerNet ?? _currentUser?.kariyerNetUrl ?? '') : '',
      'cvBase64': status == 'accepted' ? (_currentUser?.cvBase64 ?? '') : '',
      'cvFileName': status == 'accepted' ? (_currentUser?.cvFileName ?? '') : '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. LAN UDP Broadcast
    await _sendLanBroadcast(json.encode(responseMap));

    // 2. Nostr NIP-44 Encrypted Event
    try {
      final cleanedCompany = _cleanHex64(companyPeerId);
      final targetPubkey = cleanedCompany.length == 64 ? cleanedCompany : _keys!.public;
      final cipher = await Encryption.encrypt(
        plaintext: json.encode(responseMap),
        senderSecretKey: _keys!.secret,
        recipientPubkey: targetPubkey,
      );

      final event = Event.from(
        kind: 21000,
        content: cipher,
        secretKey: _keys!.secret,
        tags: [
          ['p', targetPubkey],
          ['t', 'ko_apps_offer_response'],
          ['offerId', offerId],
        ],
      );

      _publishEventToPool(event);
      debugPrint('Offer response published to Nostr pool: $status to $targetPubkey');
    } catch (e) {
      debugPrint('Nostr response encryption error: $e');
    }
  }

  /// High-speed P2P and Nostr encrypted file transfer for drawings/portfolios
  Future<String?> downloadPortfolioFile({
    required String draftsmanPeerId,
    String? draftsmanPublicKey,
    required String fileId,
    required String fileName,
  }) async {
    // 1. Check if already downloaded
    final existingPath = await getDownloadedFilePath(fileId, fileName);
    if (existingPath != null) return existingPath;

    if (_downloadedFilesBase64.containsKey(fileId)) {
      if (kIsWeb) {
        PWAHelper.downloadBase64File(_downloadedFilesBase64[fileId]!, fileName);
        return 'web_downloaded';
      }
    }

    // 2. Query Nostr Relays for Kind 1063 File Chunks (Decentralized Storage)
    final completer = Completer<String?>();
    _pendingFileCompleters[fileId] = completer;

    final subId = 'fsub_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final reqMsg = json.encode([
      'REQ',
      subId,
      {
        'kinds': [1063],
        '#f': [fileId],
        'limit': 60,
      }
    ]);

    for (final ws in _activeRelays.values) {
      try {
        ws.sink.add(reqMsg);
      } catch (_) {}
    }

    // Wait up to 4 seconds for Nostr relay chunks
    final relayResult = await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );

    if (relayResult != null) {
      final closeMsg = json.encode(['CLOSE', subId]);
      for (final ws in _activeRelays.values) {
        try {
          ws.sink.add(closeMsg);
        } catch (_) {}
      }
      return relayResult;
    }

    final candidateMeta = _discoveredDraftsmen[draftsmanPeerId] ?? _discoveredDraftsmen[draftsmanPublicKey ?? ''];
    final lanIp = candidateMeta?['lanIp'] as String?;
    final rawKey = draftsmanPublicKey ?? candidateMeta?['publicKey'] as String? ?? candidateMeta?['id'] as String? ?? draftsmanPeerId;
    final pubKey = _cleanHex64(rawKey);

    // 3. Try fast LAN TCP if IP is known
    if (!kIsWeb && lanIp != null) {
      try {
        debugPrint('Requesting portfolio file $fileId from LAN $lanIp:$_lanTcpPort...');
        final socket = await Socket.connect(lanIp, _lanTcpPort, timeout: const Duration(seconds: 3));
        final req = utf8.encode(json.encode({
          'type': 'GET_PORTFOLIO_FILE',
          'fileId': fileId,
          'companyId': _keys?.public ?? _currentUser?.id ?? '',
        }));
        FrameProtocol.send(socket, req);
        await socket.flush();

        await for (final frame in FrameProtocol.readFrames(socket).timeout(const Duration(seconds: 15))) {
          final res = json.decode(utf8.decode(frame)) as Map<String, dynamic>;
          if (res['status'] == 'OK' && res['base64'] != null) {
            final bytes = base64Decode(res['base64'] as String);
            final appDocDir = await getApplicationDocumentsDirectory();
            final downloadsDir = Directory('${appDocDir.path}/p2p_downloads');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            final cleanFileName = res['fileName'] as String? ?? fileName;
            final savePath = '${downloadsDir.path}/${fileId}_$cleanFileName';
            final file = File(savePath);
            await file.writeAsBytes(bytes);
            debugPrint('LAN portfolio file saved to $savePath (${bytes.length} bytes)');
            await socket.close();
            return savePath;
          }
          break;
        }
        await socket.close();
      } catch (e) {
        debugPrint('LAN download failed or timed out ($e), attempting Nostr fallback...');
      }
    }

    // 4. Fallback to live Kind 21000 Nostr DM
    if (_keys != null && RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(pubKey)) {
      try {
        final dmCompleter = Completer<String?>();
        _pendingFileCompleters[fileId] = dmCompleter;

        final payload = json.encode({
          'type': 'GET_PORTFOLIO_FILE',
          'fileId': fileId,
          'fileName': fileName,
        });

        final encrypted = await Encryption.encrypt(
          plaintext: payload,
          recipientPubkey: pubKey,
          senderSecretKey: _keys!.secret,
        );

        final event = Event.from(
          kind: 21000,
          content: encrypted,
          secretKey: _keys!.secret,
          tags: [
            ['p', pubKey],
            ['t', 'file_request']
          ],
        );
        _publishEventToPool(event);
        debugPrint('Published Nostr file request for $fileId to $pubKey');

        return await dmCompleter.future.timeout(const Duration(seconds: 10), onTimeout: () {
          _pendingFileCompleters.remove(fileId);
          return null;
        });
      } catch (e) {
        debugPrint('Nostr live DM fallback error: $e');
        _pendingFileCompleters.remove(fileId);
      }
    }

    return null;
  }

  void resume() {
    debugPrint('NostrService resuming connections and health check...');
    _checkRelayHealth();
    if (_currentUser?.role == 'draftsman') {
      _sendLanPresence();
      if (_currentUser != null) {
        broadcastProfile(_currentUser!);
      }
    } else if (_currentUser?.role == 'company') {
      queryDraftsmen();
    }
  }

  Future<Map<String, dynamic>?> fetchProfileMetadata(String pubKey) async {
    final clean = _cleanHex64(pubKey);
    for (final relayUrl in defaultRelays) {
      try {
        final channel = WebSocketChannel.connect(Uri.parse(relayUrl));
        await channel.ready.timeout(const Duration(seconds: 4));
        final subId = 'sub_meta_${DateTime.now().millisecondsSinceEpoch % 10000}';
        final completer = Completer<Map<String, dynamic>?>();

        final sub = channel.stream.listen((rawMsg) {
          try {
            final parsed = json.decode(rawMsg.toString()) as List;
            if (parsed.isNotEmpty && parsed[0] == 'EVENT') {
              final ev = parsed[2] as Map<String, dynamic>;
              if (ev['pubkey'] == clean && ev['kind'] == 0) {
                final content = json.decode(ev['content'] as String) as Map<String, dynamic>;
                if (!completer.isCompleted) completer.complete(content);
              }
            } else if (parsed.isNotEmpty && parsed[0] == 'EOSE') {
              if (!completer.isCompleted) completer.complete(null);
            }
          } catch (_) {}
        });

        channel.sink.add(json.encode([
          'REQ',
          subId,
          {
            'kinds': [0],
            'authors': [clean],
            'limit': 1,
          }
        ]));

        final result = await completer.future.timeout(const Duration(seconds: 4), onTimeout: () => null);
        await sub.cancel();
        await channel.sink.close();
        if (result != null) return result;
      } catch (_) {}
    }
    return null;
  }

  Future<String?> getDownloadedFilePath(String fileId, String fileName) async {
    if (kIsWeb) return null;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final savePath = '${appDocDir.path}/p2p_downloads/${fileId}_$fileName';
      if (await File(savePath).exists()) {
        return savePath;
      }
    } catch (_) {}
    return null;
  }

  void _publishEventToPool(Event event) {
    final eventJson = json.encode(['EVENT', event.toMap()]);
    if (_activeRelays.isEmpty) {
      debugPrint('No active relays connected yet. Connecting and publishing event ${event.id}...');
      _connectToRelayPool().then((_) {
        for (final ws in _activeRelays.values) {
          try {
            ws.sink.add(eventJson);
          } catch (e) {
            debugPrint('Error publishing to relay: $e');
          }
        }
      });
      return;
    }
    for (final ws in _activeRelays.values) {
      try {
        ws.sink.add(eventJson);
      } catch (e) {
        debugPrint('Error publishing to relay: $e');
      }
    }
  }

  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _draftsmenDebounceTimer?.cancel();
    _draftsmenDebounceTimer = null;

    if (!kIsWeb) {
      try {
        _udpSocket?.close();
      } catch (_) {}
      _udpSocket = null;

      try {
        await _tcpServer?.close();
      } catch (_) {}
      _tcpServer = null;
    }

    for (final ws in _activeRelays.values) {
      try {
        await ws.sink.close();
      } catch (_) {}
    }
    _activeRelays.clear();

    _discoveredDraftsmen.clear();
    _pendingFileCompleters.clear();

    _safeAddConnectionStatus('Bağlantı Kesildi');
    _safeAddDraftsmen([]);
  }
}
