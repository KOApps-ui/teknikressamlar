import 'dart:io';
import 'package:flutter/material.dart';
import '../services/background_service.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';

/// Agresif pil tasarrufu olan cihazlarda (Xiaomi, Samsung, Huawei, Oppo vb.)
/// arka plandaki WebSocket / P2P bağlantılarının uyutulmasını engelleyen
/// ve kullanıcıya net yönergeler sunan Blueprint arayüz bileşeni.
class BatteryOptimizationDialog extends StatefulWidget {
  const BatteryOptimizationDialog({super.key});

  /// Dialogu doğrudan açar
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const BatteryOptimizationDialog(),
    );
  }

  /// Otomatik kontrol eder; eğer pil optimizasyonu aktifse ve kullanıcı engellememişse gösterir.
  static Future<void> checkAndShow(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      final isIgnoring = await BackgroundService.isIgnoringBatteryOptimizations();
      if (isIgnoring) return;

      final dismissed = await LocalDbService().isBatteryDialogDismissed();
      if (dismissed) return;

      if (context.mounted) {
        await show(context);
      }
    } catch (e) {
      debugPrint('[BatteryOptimizationDialog] Check error: $e');
    }
  }

  @override
  State<BatteryOptimizationDialog> createState() => _BatteryOptimizationDialogState();
}

class _BatteryOptimizationDialogState extends State<BatteryOptimizationDialog> {
  bool _isIgnoring = false;
  bool _isLoading = true;
  bool _dontAskAgain = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await BackgroundService.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _isIgnoring = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestOptimization() async {
    setState(() => _isLoading = true);
    await BackgroundService.requestIgnoreBatteryOptimization();
    // Android sistem intentinden dönüş için kısa bir bekleme
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkStatus();
  }

  Future<void> _onClose() async {
    if (_dontAskAgain) {
      await LocalDbService().setBatteryDialogDismissed(true);
    }
    if (mounted) {
      Navigator.of(context).pop(_isIgnoring);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.blueprintDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.amberSteel, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve İkon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.amberSteel.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.amberSteel),
                    ),
                    child: const Icon(
                      Icons.battery_alert_rounded,
                      color: AppTheme.amberSteel,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kesintisiz Bildirim & Arka Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pil Optimizasyonu ve Uyku Modu Ayarı',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.amberSteel,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Açıklama Metni
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.steelBorder),
                ),
                child: const Text(
                  'Xiaomi (MIUI/HyperOS), Samsung (One UI) ve Huawei gibi cihazlar; telefon kilitlendiğinde arka plandaki şifreli P2P bağlantılarını agresif biçimde uyutabilir.\n\nYeni iş tekliflerini ve anlık yanıtları ekran kapalıyken kaçırmamak için lütfen pil kısıtlamasını kaldırın.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Mevcut Durum Kartı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isIgnoring
                      ? AppTheme.statusSuccess.withValues(alpha: 0.15)
                      : AppTheme.statusDanger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isIgnoring ? AppTheme.statusSuccess : AppTheme.statusDanger,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isIgnoring ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: _isIgnoring ? AppTheme.statusSuccess : AppTheme.statusDanger,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isIgnoring
                            ? 'Pil Kısıtlaması Devre Dışı (Bildirimler Kesintisiz)'
                            : 'Pil Optimizasyonu Aktif (Teklifler Gecikebilir)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isIgnoring ? AppTheme.statusSuccess : AppTheme.statusDanger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // OEM Cihaz Yönergeleri
              const Text(
                'Üreticiye Özel Ayarlar:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cyanLine,
                ),
              ),
              const SizedBox(height: 8),

              _buildOemTile(
                brand: 'Xiaomi / Redmi / POCO (MIUI & HyperOS)',
                instructions:
                    '1. Ayarlar > Uygulamalar > KO|Apps > "Otomatik Başlatma"yı Açın.\n2. Pil Tasarrufu > "Kısıtlama Yok" (No restrictions) seçin.',
              ),
              const SizedBox(height: 6),

              _buildOemTile(
                brand: 'Samsung (One UI)',
                instructions:
                    'Ayarlar > Uygulamalar > KO|Apps > Pil > "Kısıtlanmamış" (Unrestricted) modunu işaretleyin.',
              ),
              const SizedBox(height: 6),

              _buildOemTile(
                brand: 'Huawei / Honor (EMUI & HarmonyOS)',
                instructions:
                    'Ayarlar > Pil > Uygulama Başlatma > KO|Apps > "Elle Yönet" (Arka planda çalışmaya izin ver).',
              ),
              const SizedBox(height: 16),

              // Ana Aksiyon Butonu
              if (!_isIgnoring) ...[
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.amberSteel,
                      foregroundColor: AppTheme.blueprintDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blueprintDark),
                          )
                        : const Icon(Icons.flash_on_rounded, size: 20),
                    label: const Text(
                      'PİL KISITLAMASINI DEVRE DIŞI BIRAK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                    ),
                    onPressed: _isLoading ? null : _requestOptimization,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Tekrar Gösterme & Kapat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _dontAskAgain,
                            activeColor: AppTheme.cyanLine,
                            checkColor: AppTheme.blueprintDark,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tekrar sorma',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _onClose,
                    child: Text(
                      _isIgnoring ? 'Tamam' : 'Şimdi Değil',
                      style: const TextStyle(color: AppTheme.cyanLine, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOemTile({required String brand, required String instructions}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smartphone, size: 14, color: AppTheme.cyanLine),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  brand,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            instructions,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Profil sayfalarında gösterilen kompakt pil optimizasyon ve arka plan yönetim kartı
class BatteryOptimizationCard extends StatefulWidget {
  const BatteryOptimizationCard({super.key});

  @override
  State<BatteryOptimizationCard> createState() => _BatteryOptimizationCardState();
}

class _BatteryOptimizationCardState extends State<BatteryOptimizationCard> with WidgetsBindingObserver {
  bool _isIgnoring = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final status = await BackgroundService.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _isIgnoring = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isIgnoring
              ? AppTheme.steelBorder.withValues(alpha: 0.5)
              : AppTheme.amberSteel.withValues(alpha: 0.7),
          width: _isIgnoring ? 1 : 1.4,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await BatteryOptimizationDialog.show(context);
          _checkStatus();
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isIgnoring
                    ? AppTheme.statusSuccess.withValues(alpha: 0.15)
                    : AppTheme.amberSteel.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isIgnoring ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                color: _isIgnoring ? AppTheme.statusSuccess : AppTheme.amberSteel,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Arka Plan & Pil İzni',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isIgnoring
                              ? AppTheme.statusSuccess.withValues(alpha: 0.2)
                              : AppTheme.amberSteel.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _isIgnoring ? AppTheme.statusSuccess : AppTheme.amberSteel,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _isLoading
                              ? 'KONTROL...'
                              : (_isIgnoring ? '✓ KESİNTİSİZ' : '⚠️ KISITLANABİLİR'),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _isIgnoring ? AppTheme.statusSuccess : AppTheme.amberSteel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isIgnoring
                        ? 'Telefon kilitliyken teklifler gecikmesiz iletilir.'
                        : 'Xiaomi / Samsung uyku modunu engellemek için dokunun.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isIgnoring ? AppTheme.textMuted : AppTheme.amberSteel,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.textSubtle),
          ],
        ),
      ),
    );
  }
}
