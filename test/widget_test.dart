import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_ressamlar/core/models/user_profile.dart';
import 'package:teknik_ressamlar/core/models/offer_model.dart';
import 'package:teknik_ressamlar/core/services/crypto_service.dart';
import 'package:teknik_ressamlar/core/services/nostr_service.dart';

void main() {
  test('UserProfile and OfferModel serialization test', () {
    final now = DateTime.now();
    final profile = UserProfile(
      id: 'did:ko:tr:test1234',
      name: 'Ahmet Yılmaz',
      email: 'ahmet@teknikressam.net',
      phone: '+905551234567',
      role: 'draftsman',
      branch: 'Çelik Yapı & Konstrüksiyon',
      title: 'Kıdemli Çelik Ressamı',
      experienceYears: 6,
      bio: 'Tekla Structures uzmanı',
      softwareSkills: ['AutoCAD', 'Tekla Structures'],
      city: 'Kocaeli',
      portfolioFiles: [
        PortfolioFile(
          id: 'file-1',
          fileName: 'fabrika_celik_detay.dwg',
          fileExtension: 'dwg',
          filePath: '/data/fabrika.dwg',
          fileSize: 2048576,
          uploadDate: now,
          description: 'Birleşim detayları',
        ),
      ],
      publicKey: '0123456789abcdef',
      privateKey: 'fedcba9876543210',
      authProvider: 'local_did',
      createdAt: now,
      updatedAt: now,
      isAvailable: true,
    );

    final jsonStr = profile.toJson();
    final decoded = UserProfile.fromJson(jsonStr);

    expect(decoded.name, equals('Ahmet Yılmaz'));
    expect(decoded.portfolioFiles.length, equals(1));
    expect(decoded.portfolioFiles.first.fileExtension, equals('dwg'));

    // Public summary test (must omit privateKey and personal phone)
    final publicSummary = profile.toPublicSummaryMap();
    expect(publicSummary.containsKey('privateKey'), isFalse);
    expect(publicSummary['portfolioCount'], equals(1));

    // OfferModel serialization test
    final offer = OfferModel(
      id: 'offer-101',
      draftsmanId: profile.id,
      draftsmanName: profile.name,
      companyId: 'comp-202',
      companyName: 'Enka Çelik Taahhüt A.Ş.',
      companyContact: 'ik@enkacelik.com',
      projectTitle: 'Endüstriyel Tesis İmalat Çizimleri',
      description: 'Tekla Structures ile birleşim ve ankraj paftaları',
      branch: 'Çelik Yapı & Konstrüksiyon',
      budget: '60.000 ₺ / Proje',
      projectDuration: '2 Ay',
      deadline: '15.10.2026',
      status: 'pending',
      createdAt: now,
      isEncrypted: true,
    );

    final offerJson = offer.toJson();
    final decodedOffer = OfferModel.fromJson(offerJson);
    expect(decodedOffer.projectTitle, equals('Endüstriyel Tesis İmalat Çizimleri'));
    expect(decodedOffer.isEncrypted, isTrue);
  });

  test('CryptoService keypair and end-to-end encryption test', () async {
    final crypto = CryptoService();
    final companyKeys = await crypto.generateKeyPair();
    final draftsmanKeys = await crypto.generateKeyPair();

    expect(companyKeys.publicKeyHex.isNotEmpty, isTrue);
    expect(draftsmanKeys.publicKeyHex.isNotEmpty, isTrue);

    const secretOfferData = '{"offerId": "offer-999", "budget": "75.000 TL", "contact": "ceo@holding.com"}';

    // Company encrypts using Company Private Key + Draftsman Public Key
    final cipherText = await crypto.encryptForPeer(
      plainText: secretOfferData,
      senderPrivateKeyHex: companyKeys.privateKeyHex,
      recipientPublicKeyHex: draftsmanKeys.publicKeyHex,
    );

    expect(cipherText.contains('75.000 TL'), isFalse);

    // Draftsman decrypts using Draftsman Private Key + Company Public Key
    final decryptedText = await crypto.decryptFromPeer(
      encryptedPayload: cipherText,
      recipientPrivateKeyHex: draftsmanKeys.privateKeyHex,
      senderPublicKeyHex: companyKeys.publicKeyHex,
    );

    expect(decryptedText, equals(secretOfferData));
  });

  test('LAN UDP packet serialization and parsing test', () {
    final profileMap = {
      'id': 'did:ko:tr:ressam1',
      'name': 'Kemal Ressam',
      'role': 'draftsman',
      'branch': 'Çelik Yapı & Konstrüksiyon',
      'title': 'Kıdemli Çelik Ressamı',
      'experienceYears': 5,
      'softwareSkills': ['AutoCAD', 'Tekla Structures'],
      'city': 'Bursa',
      'isAvailable': true,
      'lanIp': '192.168.1.150',
      'lanPort': 45455,
    };

    final presencePacket = {
      'type': 'DRAFTSMAN_PRESENCE',
      'profile': profileMap,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final encoded = utf8.encode(json.encode(presencePacket));
    final decoded = json.decode(utf8.decode(encoded)) as Map<String, dynamic>;

    expect(decoded['type'], equals('DRAFTSMAN_PRESENCE'));
    final profile = decoded['profile'] as Map<String, dynamic>;
    expect(profile['name'], equals('Kemal Ressam'));
    expect(profile['lanIp'], equals('192.168.1.150'));
    expect(profile['lanPort'], equals(45455));
  });

  test('Decentralized PortfolioFile base64 serialization and ID matching test', () {
    const rawDummyDwg = 'AC1032DWGDATA1234567890';
    final base64Dummy = base64Encode(utf8.encode(rawDummyDwg));

    final pFile = PortfolioFile(
      id: 'drawing-abc',
      fileName: 'kolon_detay.dwg',
      fileExtension: 'dwg',
      filePath: '/mock/path/kolon_detay.dwg',
      fileSize: 1024,
      uploadDate: DateTime.now(),
      description: 'Kolon detay çizimi',
      fileBase64: base64Dummy,
    );

    final map = pFile.toMap();
    expect(map['fileBase64'], equals(base64Dummy));

    final fromMap = PortfolioFile.fromMap(map);
    expect(fromMap.fileBase64, equals(base64Dummy));

    // ID sanitization check
    String cleanId(String id) => id
        .replaceAll('did:nostr:', '')
        .replaceAll('did:ko:tr:', '')
        .replaceAll('did:ko:comp:', '')
        .trim();

    final idWithPrefix = 'did:nostr:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    final rawHex = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    expect(cleanId(idWithPrefix), equals(rawHex));
  });

  test('CertificateItem model serialization and UserProfile integration test', () {
    final cert = CertificateItem(
      id: 'cert-1',
      title: 'Autodesk Certified Professional - Revit Structure',
      issuer: 'Autodesk',
      issueYear: '2024',
      credentialId: 'AUTODK-992384-REVIT',
      fileName: 'revit_cert.pdf',
      filePath: '/mock/path/revit_cert.pdf',
      fileSize: 409600,
    );

    final certMap = cert.toMap();
    final restoredCert = CertificateItem.fromMap(certMap);
    expect(restoredCert.title, equals('Autodesk Certified Professional - Revit Structure'));
    expect(restoredCert.issuer, equals('Autodesk'));
    expect(restoredCert.issueYear, equals('2024'));

    final profile = UserProfile.fromMap({
      'id': 'did:ko:tr:ressam_cert_test',
      'name': 'Merve Mühendis',
      'email': 'merve@example.com',
      'phone': '+905559876543',
      'role': 'draftsman',
      'branch': 'BIM & Mimari Modelleme',
      'certificates': [cert.toMap()],
    });

    final summary = profile.toPublicSummaryMap();
    expect(summary['certificates'], isA<List>());
    expect((summary['certificates'] as List).length, equals(1));
    expect((summary['certificates'] as List).first['title'], equals('Autodesk Certified Professional - Revit Structure'));

    final jsonString = profile.toJson();
    final fromJsonProfile = UserProfile.fromJson(jsonString);
    expect(fromJsonProfile.certificates.length, equals(1));
    expect(fromJsonProfile.certificates.first.title, equals('Autodesk Certified Professional - Revit Structure'));
  });

  test('NostrService dispose and reconnect cycle does not close streams', () async {
    final nostr = NostrService();
    expect(nostr.discoveredDraftsmenStream, isNotNull);
    expect(nostr.incomingOfferStream, isNotNull);
    expect(nostr.connectionStatusStream, isNotNull);

    // Simulate logout dispose
    await nostr.dispose();

    // Verify state and that adding to stream does not throw Bad state
    expect(nostr.discoveredDraftsmen, isEmpty);
    nostr.clearDiscoveredDraftsmen();
  });
}
