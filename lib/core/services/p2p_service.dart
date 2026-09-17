import 'dart:async';
import '../models/user_profile.dart';
import '../models/offer_model.dart';
import 'nostr_service.dart';

/// P2P Service interface powered by Decentralized Nostr Protocol & LAN Direct Mesh.
/// Provides zero-server, end-to-end encrypted communication and sub-1ms local transfer.
class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final _nostr = NostrService();

  Stream<List<Map<String, dynamic>>> get discoveredDraftsmenStream => _nostr.discoveredDraftsmenStream;
  List<Map<String, dynamic>> get discoveredDraftsmen => _nostr.discoveredDraftsmen;
  Stream<OfferModel> get incomingOfferStream => _nostr.incomingOfferStream;
  Stream<Map<String, dynamic>> get offerResponseStream => _nostr.offerResponseStream;
  Stream<String> get connectionStatusStream => _nostr.connectionStatusStream;
  bool get isConnected => _nostr.isConnected;
  int get activeRelaysCount => _nostr.activeRelaysCount;
  List<String> get connectedRelayUrls => _nostr.connectedRelayUrls;
  String get connectionStatus => _nostr.connectionStatus;

  Future<void> start({required UserProfile userProfile}) => _nostr.start(userProfile: userProfile);
  Future<void> scanNetwork() => _nostr.queryDraftsmen();
  Future<void> listenBranch(String branch) => _nostr.queryDraftsmen(branch: branch);
  void clearDiscoveredDraftsmen() => _nostr.clearDiscoveredDraftsmen();
  Future<void> deleteCandidate(String candidateId) => _nostr.deleteCandidate(candidateId);
  Future<void> clearDeletedCandidates() => _nostr.clearDeletedCandidates();

  Future<bool> sendOfferToDraftsman({
    required OfferModel offer,
    required String draftsmanPeerId,
    required String draftsmanPublicKey,
  }) => _nostr.sendOfferToDraftsman(
    offer: offer,
    draftsmanPeerId: draftsmanPeerId,
    draftsmanPublicKey: draftsmanPublicKey,
  );

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
  }) => _nostr.sendOfferResponse(
    offerId: offerId,
    companyPeerId: companyPeerId,
    status: status,
    note: note,
    draftsmanEmail: draftsmanEmail,
    draftsmanPhone: draftsmanPhone,
    draftsmanCity: draftsmanCity,
    draftsmanTitle: draftsmanTitle,
    draftsmanBio: draftsmanBio,
    draftsmanLinkedin: draftsmanLinkedin,
    draftsmanKariyerNet: draftsmanKariyerNet,
  );

  Future<String?> downloadPortfolioFile({
    required String draftsmanPeerId,
    String? draftsmanPublicKey,
    required String fileId,
    required String fileName,
  }) => _nostr.downloadPortfolioFile(
    draftsmanPeerId: draftsmanPeerId,
    draftsmanPublicKey: draftsmanPublicKey,
    fileId: fileId,
    fileName: fileName,
  );

  Future<String?> getDownloadedFilePath(String fileId, String fileName) =>
      _nostr.getDownloadedFilePath(fileId, fileName);

  void resume() => _nostr.resume();

  Future<void> dispose() => _nostr.dispose();
}
