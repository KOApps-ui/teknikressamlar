import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_ressamlar/core/models/user_profile.dart';
import 'package:teknik_ressamlar/core/models/offer_model.dart';
import 'package:teknik_ressamlar/core/services/subscription_service.dart';

void main() {
  group('UserProfile and OfferModel LinkedIn & Kariyer.net', () {
    test('UserProfile persists linkedinUrl and kariyerNetUrl and includes them in public summary', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'user_1',
        name: 'Can Ressam',
        email: 'can@example.com',
        phone: '05551112233',
        role: 'draftsman',
        branch: 'Makine & Endüstriyel İmalat',
        title: 'Makine Ressamı',
        experienceYears: 4,
        bio: 'SolidWorks ve Inventor uzmanı',
        softwareSkills: ['SolidWorks', 'Catia', 'Inventor'],
        city: 'Bursa',
        portfolioFiles: [],
        publicKey: 'pub123',
        privateKey: 'priv123',
        authProvider: 'local',
        createdAt: now,
        updatedAt: now,
        linkedinUrl: 'https://linkedin.com/in/canressam',
        kariyerNetUrl: 'https://kariyer.net/ozgecmis/canressam',
      );

      final map = profile.toMap();
      expect(map['linkedinUrl'], equals('https://linkedin.com/in/canressam'));
      expect(map['kariyerNetUrl'], equals('https://kariyer.net/ozgecmis/canressam'));

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.linkedinUrl, equals('https://linkedin.com/in/canressam'));
      expect(fromMap.kariyerNetUrl, equals('https://kariyer.net/ozgecmis/canressam'));

      final publicSummary = profile.toPublicSummaryMap();
      expect(publicSummary['linkedinUrl'], equals('https://linkedin.com/in/canressam'));
      expect(publicSummary['kariyerNetUrl'], equals('https://kariyer.net/ozgecmis/canressam'));
      expect(publicSummary['cvBase64'], isNull);
      expect(publicSummary.containsKey('privateKey'), isFalse);
    });

    test('OfferModel includes draftsmanLinkedin and draftsmanKariyerNet in serialization and copyWith', () {
      final offer = OfferModel(
        id: 'offer_1',
        draftsmanId: 'tr_1',
        draftsmanName: 'Can Ressam',
        companyId: 'comp_1',
        companyName: 'Bursa Makine Sanayi',
        companyContact: 'info@bursamakine.com',
        projectTitle: 'Kalıp İmalat Çizimi',
        description: 'Tasarım paftaları',
        branch: 'Makine',
        budget: '50.000 TL',
        projectDuration: '1 Ay',
        deadline: '30 Gün',
        status: 'accepted',
        createdAt: DateTime.now(),
        draftsmanLinkedin: 'https://linkedin.com/in/canressam',
        draftsmanKariyerNet: 'https://kariyer.net/ozgecmis/canressam',
      );

      final map = offer.toMap();
      expect(map['draftsmanLinkedin'], equals('https://linkedin.com/in/canressam'));
      expect(map['draftsmanKariyerNet'], equals('https://kariyer.net/ozgecmis/canressam'));

      final fromMap = OfferModel.fromMap(map);
      expect(fromMap.draftsmanLinkedin, equals('https://linkedin.com/in/canressam'));
      expect(fromMap.draftsmanKariyerNet, equals('https://kariyer.net/ozgecmis/canressam'));

      final updated = fromMap.copyWith(status: 'completed');
      expect(updated.draftsmanLinkedin, equals('https://linkedin.com/in/canressam'));
      expect(updated.draftsmanKariyerNet, equals('https://kariyer.net/ozgecmis/canressam'));
      expect(updated.status, equals('completed'));
    });
  });

  group('CompanyLicense and Subscription Models', () {
    test('CompanyLicense calculates expiry and remainingOffersText properly', () {
      final activePack = CompanyLicense(
        planId: 'pack_5',
        planName: '5 Teklif Paketi',
        licenseKey: 'KO-PACK-TEST',
        activatedAt: DateTime.now(),
        remainingCredits: 5,
        isUnlimited: false,
      );

      expect(activePack.isExpired, isFalse);
      expect(activePack.remainingOffersText, equals('5 Teklif Kaldı'));
      expect(activePack.isExpiringSoon, isFalse);

      final lowCreditPack = CompanyLicense(
        planId: 'pack_5',
        planName: '5 Teklif Paketi',
        licenseKey: 'KO-PACK-TEST',
        activatedAt: DateTime.now(),
        remainingCredits: 1,
        isUnlimited: false,
      );
      expect(lowCreditPack.isExpiringSoon, isTrue);

      final expiringSubscription = CompanyLicense(
        planId: 'pro_monthly',
        planName: 'Pro Kurumsal',
        licenseKey: 'KO-PRO-TEST',
        activatedAt: DateTime.now().subtract(const Duration(days: 28)),
        expiresAt: DateTime.now().add(const Duration(days: 2)),
        isUnlimited: true,
      );
      expect(expiringSubscription.isExpiringSoon, isTrue);
      expect(expiringSubscription.remainingOffersText, equals('Sınırsız Teklif'));
    });

    test('OfferModel company logo, verification badge and VIP fields serialize correctly', () {
      final offer = OfferModel(
        id: 'offer_vip_1',
        draftsmanId: 'd_1',
        draftsmanName: 'Mehmet Ressam',
        companyId: 'c_1',
        companyName: 'Aselsan Tedarik A.Ş.',
        companyContact: 'info@aselsan.com',
        projectTitle: 'Savunma Sanayi Çizimleri',
        description: 'CNC ve CAD paftaları',
        branch: 'Savunma & Havacılık',
        budget: '150.000 TL',
        projectDuration: '3 Ay',
        deadline: '90 Gün',
        status: 'pending',
        createdAt: DateTime.now(),
        companyLogoBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        companyIsVerified: true,
        companyVerificationBadge: 'GİB / e-Devlet Onaylı Kurumsal Şirket',
        companyIsVip: true,
        companyTier: 'Yıllık Kurumsal VIP',
      );

      final map = offer.toMap();
      expect(map['companyLogoBase64'], isNotEmpty);
      expect(map['companyIsVerified'], isTrue);
      expect(map['companyVerificationBadge'], equals('GİB / e-Devlet Onaylı Kurumsal Şirket'));
      expect(map['companyIsVip'], isTrue);
      expect(map['companyTier'], equals('Yıllık Kurumsal VIP'));

      final fromMap = OfferModel.fromMap(map);
      expect(fromMap.companyLogoBase64, equals(offer.companyLogoBase64));
      expect(fromMap.companyIsVerified, isTrue);
      expect(fromMap.companyVerificationBadge, equals('GİB / e-Devlet Onaylı Kurumsal Şirket'));
      expect(fromMap.companyIsVip, isTrue);
      expect(fromMap.companyTier, equals('Yıllık Kurumsal VIP'));
    });

    test('OfferAttachment and OfferModel attachments serialize, deserialize and copy correctly', () {
      final attachment = OfferAttachment(
        id: 'att_1',
        fileName: 'statik_hesap_ve_cizimler.dwg',
        fileExtension: 'dwg',
        fileSize: 1024 * 512,
        fileBase64: 'base64dwgdata',
        localPath: '/storage/emulated/0/Download/statik.dwg',
      );

      final offer = OfferModel(
        id: 'offer_att_1',
        draftsmanId: 'd_1',
        draftsmanName: 'Ahmet Ressam',
        companyId: 'c_1',
        companyName: 'Mühendislik Ltd.',
        companyContact: 'muhendislik@example.com',
        projectTitle: 'Çelik Çatı Projesi',
        description: 'Statik hesap paftaları eklenmiştir.',
        branch: 'Çelik Yapı',
        budget: '40.000 TL',
        projectDuration: '1 Ay',
        deadline: '30 Gün',
        status: 'pending',
        createdAt: DateTime.now(),
        attachments: [attachment],
      );

      final map = offer.toMap();
      expect(map['attachments'], isA<List>());
      expect((map['attachments'] as List).length, equals(1));
      expect((map['attachments'] as List).first['fileName'], equals('statik_hesap_ve_cizimler.dwg'));
      expect((map['attachments'] as List).first['fileExtension'], equals('dwg'));
      expect((map['attachments'] as List).first['fileSize'], equals(1024 * 512));

      final deserialized = OfferModel.fromMap(map);
      expect(deserialized.attachments.length, equals(1));
      expect(deserialized.attachments.first.fileName, equals('statik_hesap_ve_cizimler.dwg'));
      expect(deserialized.attachments.first.fileExtension, equals('dwg'));
      expect(deserialized.attachments.first.fileSize, equals(1024 * 512));
      expect(deserialized.attachments.first.fileBase64, equals('base64dwgdata'));

      final copied = deserialized.copyWith(
        attachments: [
          ...deserialized.attachments,
          OfferAttachment(
            id: 'att_2',
            fileName: 'teknik_sartname.pdf',
            fileExtension: 'pdf',
            fileSize: 20480,
          ),
        ],
      );
      expect(copied.attachments.length, equals(2));
      expect(copied.attachments.last.fileName, equals('teknik_sartname.pdf'));
    });

    test('OfferModel can be revised and updated via copyWith preserving id and sender', () {
      final original = OfferModel(
        id: 'offer_rev_1',
        draftsmanId: 'd_1',
        draftsmanName: 'Aday Ressam',
        companyId: 'c_1',
        companyName: 'Bina Dizayn A.Ş.',
        companyContact: 'info@binadizayn.com',
        projectTitle: 'İlk Taslak Çizimi',
        description: 'İlk açıklama',
        branch: 'Mimari',
        budget: '25.000 TL',
        projectDuration: '1 Hafta',
        deadline: '7 Gün',
        status: 'rejected',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final revised = original.copyWith(
        projectTitle: 'Revize Taslak ve Uygulama Çizimi',
        description: 'Bütçe artırıldı ve paftalar eklendi.',
        budget: '35.000 TL',
        projectDuration: '2 Hafta',
        deadline: '14 Gün',
        status: 'pending',
      );

      expect(revised.id, equals(original.id));
      expect(revised.draftsmanId, equals(original.draftsmanId));
      expect(revised.projectTitle, equals('Revize Taslak ve Uygulama Çizimi'));
      expect(revised.budget, equals('35.000 TL'));
      expect(revised.status, equals('pending'));
    });
  });

  group('UserProfile CV Özgeçmiş serialization & actions', () {
    test('UserProfile persists CV fields, serializes toMap and fromMap', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'user_cv_1',
        name: 'Ahmet Tekniker',
        email: 'ahmet@example.com',
        phone: '05321234567',
        role: 'draftsman',
        branch: 'Çelik Yapı & Konstrüksiyon',
        title: 'Tekla Structures Çelik Modelleme Ressamı',
        experienceYears: 6,
        bio: 'Tekla ve çelik konstrüksiyon modelleme uzmanı',
        softwareSkills: const ['Tekla Structures', 'AutoCAD'],
        portfolioFiles: const [],
        city: 'Ankara',
        publicKey: 'pub_key_cv',
        privateKey: 'priv_key_cv',
        authProvider: 'local',
        createdAt: now,
        updatedAt: now,
        cvFileName: 'Ahmet_Tekniker_CV.pdf',
        cvFilePath: '/data/user/0/com.ko.teknikressam/app_flutter/cv_123.pdf',
        cvBase64: 'JVBERi0xLjQK...',
        cvFileSize: 1024 * 350,
        cvUploadDate: now,
      );

      final map = profile.toMap();
      expect(map['cvFileName'], equals('Ahmet_Tekniker_CV.pdf'));
      expect(map['cvFilePath'], equals('/data/user/0/com.ko.teknikressam/app_flutter/cv_123.pdf'));
      expect(map['cvBase64'], equals('JVBERi0xLjQK...'));
      expect(map['cvFileSize'], equals(1024 * 350));
      expect(map['cvUploadDate'], isNotNull);

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.cvFileName, equals('Ahmet_Tekniker_CV.pdf'));
      expect(fromMap.cvFilePath, equals('/data/user/0/com.ko.teknikressam/app_flutter/cv_123.pdf'));
      expect(fromMap.cvFileSize, equals(1024 * 350));
      expect(fromMap.cvBase64, equals('JVBERi0xLjQK...'));

      final summary = profile.toPublicSummaryMap();
      expect(summary['hasCv'], isTrue);
      expect(summary['cvFileName'], equals('Ahmet_Tekniker_CV.pdf'));
      expect(summary['cvFileSize'], equals(1024 * 350));

      final cleared = profile.copyWith(clearCv: true);
      expect(cleared.cvFileName, isNull);
      expect(cleared.cvFilePath, isNull);
      expect(cleared.cvBase64, isNull);
      expect(cleared.cvFileSize, isNull);
      expect(cleared.cvUploadDate, isNull);
      expect(cleared.toPublicSummaryMap()['hasCv'], isFalse);
    });
  });
}

