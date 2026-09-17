import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/local_db_service.dart';
import '../services/subscription_service.dart';

class SubscriptionModal extends StatefulWidget {
  const SubscriptionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SubscriptionModal(),
    );
  }

  @override
  State<SubscriptionModal> createState() => _SubscriptionModalState();
}

class _SubscriptionModalState extends State<SubscriptionModal> {
  final _localDb = LocalDbService();
  final _subService = SubscriptionService();

  UserProfile? _profile;
  CompanyLicense? _activeLicense;
  int _freeOffersSent = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final profile = await _localDb.getUserProfile();
    final license = await _subService.getActiveLicense();
    final freeCount = await _localDb.getTodayOffersSentCount();
    if (mounted) {
      setState(() {
        _profile = profile;
        _activeLicense = license;
        _freeOffersSent = freeCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _activatePackage(String planId, String licenseKey) async {
    final license = await _subService.activatePlan(
      planId: planId,
      licenseKey: licenseKey,
      profile: _profile,
    );
    await _loadState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.statusSuccess,
          content: Text('🎉 ${license.planName} başarıyla aktif edildi! Doğrulanmış rozetiniz tanımlandı.'),
        ),
      );
    }
  }

  Future<void> _cancelSubscription() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.statusDanger),
        ),
        title: const Text('Aboneliği Sıfırla', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
        content: const Text(
          'Mevcut ücretli aboneliğinizi sonlandırıp Standart (Ücretsiz) plana dönmek istediğinize emin misiniz?',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sıfırla & Standarta Dön'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _subService.cancelOrResetSubscription(profile: _profile);
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.blueprintCard,
            content: Text('Abonelik sıfırlandı, Standart plana dönüldü.'),
          ),
        );
      }
    }
  }

  void _showPaymentOptions({
    required String planId,
    required String planName,
    required String price,
  }) {
    // Generate a unique payment reference for this company & session
    final randomSuffix = (10000 + Random().nextInt(90000)).toString();
    final paymentRef = 'KO-${planId.substring(0, min(4, planId.length)).toUpperCase()}-$randomSuffix';
    final promoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pCtx) {
        return StatefulBuilder(
          builder: (bottomCtx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
                maxWidth: 680,
              ),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppTheme.blueprintDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppTheme.cyanLine, width: 2)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.steelBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      children: [
                        const Icon(Icons.verified_user, color: AppTheme.cyanLine, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                planName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                              ),
                              Text(
                                'Ödeme & Aktivasyon Seçenekleri • $price',
                                style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSubtle),
                          onPressed: () => Navigator.of(pCtx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // SECTION 1: %0 Kesintili FAST / Havale (TAVSİYE EDİLEN)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.blueprintSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusSuccess.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.statusSuccess),
                                ),
                                child: const Text(
                                  '%0 KESİNTİ • ÖNERİLEN',
                                  style: TextStyle(color: AppTheme.statusSuccess, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.bolt, color: AppTheme.statusSuccess, size: 18),
                              const Text('7/24 Anında FAST', style: TextStyle(color: AppTheme.statusSuccess, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Banka FAST / Havale ile Ödeme',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Doğrudan banka hesabına 7/24 FAST transferi ile sıfır komisyon. Açıklamaya referans kodunu yazınız.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 12),

                          // Referans Kodu Kutusu
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.amberSteel),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.tag, color: AppTheme.amberSteel, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Açıklamaya Yazılacak Sipariş Kodu:', style: TextStyle(fontSize: 10, color: AppTheme.textSubtle)),
                                      Text(paymentRef, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.amberSteel, letterSpacing: 1.2)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppTheme.amberSteel, size: 20),
                                  tooltip: 'Kodu Kopyala',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: paymentRef));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Sipariş referans kodu panoya kopyalandı!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // IBAN Kutusu
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.steelBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance, color: AppTheme.cyanLine, size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${SubscriptionService.fastBankName} • ${SubscriptionService.fastAccountName}', style: TextStyle(fontSize: 10, color: AppTheme.textSubtle)),
                                      Text(SubscriptionService.fastIban, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cyanLine)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppTheme.cyanLine, size: 20),
                                  tooltip: 'IBAN Kopyala',
                                  onPressed: () {
                                    Clipboard.setData(const ClipboardData(text: SubscriptionService.fastIban));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('IBAN panoya kopyalandı!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.statusSuccess,
                                foregroundColor: AppTheme.blueprintDark,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: const Text('ÖDEMEYİ YAPTIM & ANINDA AKTİFLEŞTİR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () async {
                                Navigator.of(pCtx).pop();
                                await _activatePackage(planId, paymentRef);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 2: Promosyon & Lisans Anahtarı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.blueprintSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.steelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.key_rounded, color: AppTheme.cyanLine, size: 18),
                              SizedBox(width: 8),
                              Text('Lisans Anahtarı / Promosyon Kodu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('Elindeki aktivasyon anahtarını girerek paketi doğrudan başlatabilirsin.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: promoController,
                            style: const TextStyle(color: AppTheme.textLight, letterSpacing: 1.2),
                            decoration: InputDecoration(
                              hintText: 'Örn: KO-PRO-2026',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixIcon: TextButton(
                                onPressed: () {
                                  promoController.text = 'KO-PRO-2026';
                                },
                                child: const Text('Dene: PRO-2026', style: TextStyle(fontSize: 11, color: AppTheme.amberSteel)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.cyanLine,
                                side: const BorderSide(color: AppTheme.cyanLine),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.lock_open, size: 18),
                              label: const Text('KODU DOĞRULA VE AKTİF ET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () async {
                                final input = promoController.text.trim();
                                if (input.isEmpty) return;
                                final targetPlan = _subService.validatePromoOrLicenseKey(input);
                                if (targetPlan != null) {
                                  Navigator.of(pCtx).pop();
                                  await _activatePackage(targetPlan, input);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: AppTheme.statusDanger,
                                      content: Text('Geçersiz lisans kodu veya promosyon anahtarı.'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // SECTION 3: Kredi Kartı / 3D Secure
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.blueprintSurface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card, color: AppTheme.textMuted, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kredi / Banka Kartı ile Online Ödeme', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                                Text('PayTR / Shopier / 3D Secure altyapısıyla güvenli kart ödemesi.', style: TextStyle(fontSize: 10, color: AppTheme.textSubtle)),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textLight,
                              side: const BorderSide(color: AppTheme.steelBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () async {
                              Navigator.of(pCtx).pop();
                              await _activatePackage(planId, 'CARD-$paymentRef');
                            },
                            child: const Text('Kartla Öde', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveLicense = _activeLicense != null && !_activeLicense!.isExpired;
    final isProActive = hasActiveLicense && _activeLicense!.planId == 'pro_monthly';
    final isPack5Active = hasActiveLicense && _activeLicense!.planId == 'pack_5';
    final isYearlyActive = hasActiveLicense && _activeLicense!.planId == 'yearly_corporate';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
        maxWidth: 720,
      ),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.blueprintDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.cyanLine, width: 2)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.steelBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.verified, color: AppTheme.amberSteel, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Şirket Kurumsal & Abonelik Çözümleri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Teknik ressamlar için sistem %100 ücretsizdir. Şirketler doğrulanmış rozet ve doğrudan şifreli P2P teklif avantajlarından yararlanabilir.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. FREE TIER CARD (GÜNLÜK 1 TEKLİF)
                        _buildPlanCard(
                          title: 'Başlangıç (Standart)',
                          price: '0 ₺ • Günlük 1 Teklif',
                          features: [
                            'P2P ağındaki tüm aktif teknik ressamları görüntüleme',
                            _freeOffersSent >= 1
                                ? 'Bugünkü 1/1 Ücretsiz Teklif Hakkı Kullanıldı (Yarın Yenilenir)'
                                : 'Bugünkü 1/1 Ücretsiz Teklif Hakkı (Kullanıma Hazır)',
                            'Temel branş ve şehir filtreleme & portföy inceleme',
                            'Doğrudan P2P şifreli mesajlaşma ve teklifleşme',
                          ],
                          isActive: !hasActiveLicense,
                          currentDetails: !hasActiveLicense
                              ? (_freeOffersSent >= 1
                                  ? 'Bugünkü 1 adet ücretsiz teklif hakkınızı kullandınız. Yarın (00:00) otomatik olarak yeni hakkınız tanımlanacaktır.'
                                  : 'Bugün 1 adet ücretsiz doğrudan teklif hakkınız bulunmaktadır.')
                              : null,
                          buttonColor: AppTheme.steelBorder,
                          buttonText: !hasActiveLicense ? 'Mevcut Planınız (Aktif)' : 'Standart Plana Dön',
                          onButtonPressed: hasActiveLicense ? _cancelSubscription : null,
                        ),
                        const SizedBox(height: 14),

                        // 2. PRO MONTHLY (EN POPÜLER - BLURRED / YAKINDA)
                        _buildBlurredPlanCard(
                          child: _buildPlanCard(
                            title: 'Kurumsal Pro & Doğrulanmış Rozet',
                            price: '890 ₺ / Ay',
                            isFeatured: true,
                            badgeText: 'EN POPÜLER',
                            features: [
                              'Doğrulanmış Mavi Şirket Rozeti (Adaylarda en yüksek güven)',
                              '30 Gün boyunca sınırsız doğrudan P2P şifreli teklif gönderimi',
                              'Aday portföy çizimlerine (DWG/DXF/PDF) sınırsız doğrudan erişim',
                              'Yeni ressam katıldığında öncelikli sinyal bildirimi',
                            ],
                            isActive: isProActive,
                            currentDetails: isProActive
                                ? 'Aktif Paket • ${_activeLicense!.remainingDays} Gün Kaldı • Sınırsız Teklif'
                                : null,
                            buttonColor: AppTheme.amberSteel,
                            buttonText: isProActive ? 'Aktif Abonelik' : 'Kurumsal Proyu Aktif Et',
                            onButtonPressed: isProActive
                                ? () => _showPaymentOptions(
                                      planId: 'pro_monthly',
                                      planName: 'Kurumsal Pro & Doğrulanmış Rozet',
                                      price: '890 ₺ / Ay',
                                    )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. 5-OFFER PACK (BLURRED / YAKINDA)
                        _buildBlurredPlanCard(
                          child: _buildPlanCard(
                            title: '5 Tekliflik Paket',
                            price: '450 ₺ (Tek Seferlik)',
                            badgeText: 'DÖNEMSEL İHTİYAÇLAR',
                            features: [
                              '5 Adet doğrudan şifreli P2P teklif kredisi',
                              'Süre kısıtlaması yok (tükenene kadar bakiye saklanır)',
                              'Aday çizim ve portföy paftalarını inceleme',
                            ],
                            isActive: isPack5Active,
                            currentDetails: isPack5Active
                                ? 'Aktif Paket • ${_activeLicense!.remainingCredits} Teklif Kredisi Kaldı'
                                : null,
                            buttonColor: AppTheme.cyanLine,
                            buttonText: isPack5Active ? 'Kredi Ekle / Yenile' : '5 Teklif Paketi Al',
                            onButtonPressed: isPack5Active
                                ? () => _showPaymentOptions(
                                      planId: 'pack_5',
                                      planName: '5 Tekliflik Paket',
                                      price: '450 ₺',
                                    )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. YEARLY CORPORATE (BLURRED / YAKINDA)
                        _buildBlurredPlanCard(
                          child: _buildPlanCard(
                            title: 'Yıllık Kurumsal VIP',
                            price: '7.900 ₺ / Yıl',
                            badgeText: '%35 AVANTAJLI',
                            features: [
                              '365 Gün boyunca sınırsız teklif gönderimi',
                              'VIP Altın Şirket Rozeti & En üst sırada listelenme',
                              '7/24 Kesintisiz P2P ağ ve dosya transfer önceliği',
                            ],
                            isActive: isYearlyActive,
                            currentDetails: isYearlyActive
                                ? 'Aktif Paket • ${_activeLicense!.remainingDays} Gün Kaldı • Sınırsız Teklif'
                                : null,
                            buttonColor: AppTheme.cyanLine,
                            buttonText: isYearlyActive ? 'Yıllık Paketi Yenile' : 'Yıllık Kurumsal VIP Al',
                            onButtonPressed: isYearlyActive
                                ? () => _showPaymentOptions(
                                      planId: 'yearly_corporate',
                                      planName: 'Yıllık Kurumsal VIP',
                                      price: '7.900 ₺ / Yıl',
                                    )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Center(
                          child: Text(
                            'Sıfır Sunucu (Zero-Server) Kriptografik Mimari: Lisansınız hem yerel cihazınızda saklanır hem de kendi Nostr özel anahtarınızla şifrelenerek rölelere yedeklenir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSubtle, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required bool isActive,
    required Color buttonColor,
    required String buttonText,
    VoidCallback? onButtonPressed,
    bool isFeatured = false,
    String? badgeText,
    String? currentDetails,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFeatured ? AppTheme.blueprintSurface : AppTheme.blueprintCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFeatured ? AppTheme.amberSteel : AppTheme.steelBorder,
          width: isFeatured ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with Expanded title to completely eliminate any badge overflow!
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isFeatured ? AppTheme.amberSteel : AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.cyanLine,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.statusSuccess.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.statusSuccess),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: AppTheme.statusSuccess),
                      SizedBox(width: 4),
                      Text(
                        'KULLANILIYOR',
                        style: TextStyle(
                          color: AppTheme.statusSuccess,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.amberSteel.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.amberSteel),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: AppTheme.amberSteel,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          if (currentDetails != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.blueprintDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.cyanLine),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      currentDetails,
                      style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.cyanLine),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: AppTheme.blueprintDark,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onButtonPressed,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredPlanCard({
    required Widget child,
    String badgeText = 'ÇOK YAKINDA AKTİF OLACAK',
    String subtitle = 'Şu an şirketler için günlük 1 ücretsiz doğrudan teklif hakkı aktiftir.',
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: IgnorePointer(
              ignoring: true,
              child: child,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: AppTheme.blueprintDark.withValues(alpha: 0.65),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintSurface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.amberSteel, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.amberSteel.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.amberSteel.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_clock_rounded, color: AppTheme.amberSteel, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badgeText,
                              style: const TextStyle(
                                color: AppTheme.amberSteel,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
