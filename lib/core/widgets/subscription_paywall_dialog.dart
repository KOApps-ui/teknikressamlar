import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

class SubscriptionPaywallDialog extends StatefulWidget {
  final UserProfile companyProfile;
  final VoidCallback onActivated;

  const SubscriptionPaywallDialog({
    super.key,
    required this.companyProfile,
    required this.onActivated,
  });

  static Future<bool?> show(BuildContext context, UserProfile profile, VoidCallback onActivated) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionPaywallDialog(
        companyProfile: profile,
        onActivated: onActivated,
      ),
    );
  }

  @override
  State<SubscriptionPaywallDialog> createState() => _SubscriptionPaywallDialogState();
}

class _SubscriptionPaywallDialogState extends State<SubscriptionPaywallDialog> {
  String _selectedPlan = 'pro_monthly';
  final _keyController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate(String planId, String key) async {
    setState(() => _isProcessing = true);
    final sub = SubscriptionService();
    await sub.activatePlan(
      planId: planId,
      licenseKey: key,
      profile: widget.companyProfile,
    );
    setState(() => _isProcessing = false);

    if (mounted) {
      widget.onActivated();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusSuccess,
          content: Text('🎉 Paketiniz başarıyla aktifleştirildi ve şifrelenerek yedeklendi!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 680,
      ),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.blueprintDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.amberSteel, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.steelBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppTheme.amberSteel, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günlük Teklif Limitine Ulaşıldı',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                      Text(
                        'Bugünkü 1 adet ücretsiz doğrudan teklif hakkınızı kullandınız. Yarın (00:00) otomatik yenilenecektir.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSubtle),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent info badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.amberSteel.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: AppTheme.amberSteel, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ÇOK YAKINDA AKTİF OLACAK',
                                style: TextStyle(
                                  color: AppTheme.amberSteel,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Şu an sistemimizde işverenler için günlük 1 adet ücretsiz doğrudan teklif hakkı sunulmaktadır. Ücretli kurumsal üyelik paketleri çok yakında aktif edilecektir.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Blurred packages section
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: IgnorePointer(
                            ignoring: true,
                            child: Column(
                              children: [
                                _buildPackageCard(
                                  id: 'pack_5',
                                  title: '5 Tekliflik Paket',
                                  price: '450 ₺',
                                  subtitle: 'Acil veya dönemsel 5 teknik ressama teklif hakkı.',
                                  badge: 'Başlangıç',
                                  icon: Icons.filter_5,
                                  color: AppTheme.cyanLine,
                                ),
                                const SizedBox(height: 12),
                                _buildPackageCard(
                                  id: 'pro_monthly',
                                  title: 'Pro Kurumsal Aylık (Sınırsız)',
                                  price: '1.250 ₺ / Ay',
                                  subtitle: '30 gün boyunca sınırsız P2P şifreli teklif gönderimi ve tam erişim.',
                                  badge: 'En Popüler',
                                  icon: Icons.stars_rounded,
                                  color: AppTheme.amberSteel,
                                  isRecommended: true,
                                ),
                                const SizedBox(height: 12),
                                _buildPackageCard(
                                  id: 'yearly_corporate',
                                  title: 'Yıllık Kurumsal Sınırsız',
                                  price: '9.900 ₺ / Yıl',
                                  subtitle: '365 gün sınırsız teklif + Doğrulanmış Firma Rozeti + Öncelikli İletişim.',
                                  badge: '%35 Avantajlı',
                                  icon: Icons.verified_user,
                                  color: AppTheme.statusSuccess,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            color: AppTheme.blueprintDark.withValues(alpha: 0.6),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.blueprintSurface.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.amberSteel),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_clock_rounded, color: AppTheme.amberSteel, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Üyelik Paketleri Çok Yakında Açılacak',
                                      style: TextStyle(
                                        color: AppTheme.amberSteel,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                  ),
                  const SizedBox(height: 20),

                  // Activation Section
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
                            Icon(Icons.vpn_key_outlined, size: 16, color: AppTheme.amberSteel),
                            SizedBox(width: 8),
                            Text(
                              'Lisans veya Promosyon Anahtarı ile Aktifleştir',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Size iletilen lisans anahtarını girin veya FAST / Banka havalesiyle anında başlatın.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _keyController,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.textLight),
                                decoration: const InputDecoration(
                                  hintText: 'Örn: KO-PRO-2026-XXXX',
                                  prefixIcon: Icon(Icons.key, size: 16, color: AppTheme.cyanLine),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cyanLine,
                                foregroundColor: AppTheme.blueprintDark,
                              ),
                              onPressed: _isProcessing
                                  ? null
                                  : () {
                                      final val = _keyController.text.trim().toUpperCase();
                                      final key = val.isNotEmpty ? val : 'KO-PRO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                                      _activate(_selectedPlan, key);
                                    },
                              child: const Text('Aktifleştir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bank Transfer / Instant Activation Option
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.blueprintSurface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, color: AppTheme.amberSteel, size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Banka & FAST ile Otomatik Aktivasyon',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight),
                              ),
                              Text(
                                'Şirket hesabınızdan FAST ödemesiyle saniyeler içinde açılır.',
                                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.amberSteel,
                            foregroundColor: AppTheme.blueprintDark,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () => _activate(_selectedPlan, 'FAST-TR-${DateTime.now().millisecondsSinceEpoch}'),
                          child: const Text('Hemen Başlat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard({
    required String id,
    required String title,
    required String price,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedPlan == id;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedPlan = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.blueprintSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppTheme.steelBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : AppTheme.textSubtle,
              size: 20,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
