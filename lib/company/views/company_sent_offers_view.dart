import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/offer_model.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/p2p_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blueprint_header.dart';
import '../../core/widgets/blocked_users_dialog.dart';
import '../../core/utils/file_helper.dart';

class CompanySentOffersView extends StatefulWidget {
  const CompanySentOffersView({super.key});

  @override
  State<CompanySentOffersView> createState() => _CompanySentOffersViewState();
}

class _CompanySentOffersViewState extends State<CompanySentOffersView> with SingleTickerProviderStateMixin {
  final _localDb = LocalDbService();
  final _p2pService = P2PService();

  List<OfferModel> _sentOffers = [];
  bool _isLoading = true;

  late TabController _tabController;
  StreamSubscription? _incomingSub;
  StreamSubscription? _responseSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOffers();

    _incomingSub = _p2pService.incomingOfferStream.listen((_) => _loadOffers());
    _responseSub = _p2pService.offerResponseStream.listen((data) {
      _loadOffers();
      final status = data['status'] as String? ?? '';
      final isAccepted = status == 'accepted';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isAccepted ? AppTheme.statusSuccess : AppTheme.statusDanger,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Icon(
                  isAccepted ? Icons.celebration : Icons.info_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAccepted
                        ? '🎉 Bir teknik ressam iş teklifinizi KABUL ETTİ!'
                        : 'İş teklifiniz aday tarafından reddedildi.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _responseSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    final user = await _localDb.getUserProfile();

    if (user != null) {
      final list = await _localDb.getOffers(forCompanyId: user.id);
      final blocked = await _localDb.getBlockedUsers();
      final blockedIds = blocked.map((b) => b['id'] as String).toSet();
      final filtered = list.where((o) => !blockedIds.contains(o.draftsmanId)).toList();
      if (mounted) {
        setState(() {
          _sentOffers = filtered;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmClearAllOffers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.statusDanger, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.statusDanger),
            SizedBox(width: 8),
            Text('Teklifleri Temizle', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Gönderilen tüm teklif geçmişini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Evet, Tümünü Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _localDb.clearAllOffers();
      await _loadOffers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('Tüm teklif geçmişi temizlendi.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteOffer(OfferModel offer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.statusDanger, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.statusDanger),
            SizedBox(width: 8),
            Text('Teklifi Sil', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '"${offer.projectTitle}" başlıklı gönderilen teklifi silmek istediğinize emin misiniz?',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _localDb.deleteOffer(offer.id);
      await _loadOffers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('Teklif silindi.'),
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await _copyText('Telefon numarası', phone);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await _copyText('E-posta adresi', email);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await _copyText('Telefon numarası', phone);
    }
  }

  Future<void> _copyText(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.statusSuccess,
          content: Text('$label panoya kopyalandı: $text'),
        ),
      );
    }
  }


  Future<void> _showEditOfferDialog(OfferModel offer) async {
    final titleController = TextEditingController(text: offer.projectTitle);
    final descController = TextEditingController(text: offer.description);

    // Parse existing budget digits
    final rawDigits = offer.budget.replaceAll(RegExp(r'[^0-9\.]'), '').trim();
    final amountController = TextEditingController(text: rawDigits.isNotEmpty ? rawDigits : offer.budget);

    final formKey = GlobalKey<FormState>();
    final List<OfferAttachment> offerAttachments = List<OfferAttachment>.from(offer.attachments);

    const workTypes = [
      'Proje Bazlı (Freelance)',
      'Tam Zamanlı (Bordrolu / Ofis)',
      'Tam Zamanlı (Uzaktan / Remote)',
      'Yarı Zamanlı (Part-Time)',
      'Saatlik / Danışmanlık',
      'Dönemsel / Sözleşmeli',
    ];

    String selectedWorkType = workTypes.firstWhere(
      (wt) => offer.projectDuration.startsWith(wt.split(' ')[0]),
      orElse: () => 'Proje Bazlı (Freelance)',
    );

    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    bool isImmediateStart = offer.deadline.contains('Hemen');
    DateTime endDate = DateTime.now().add(const Duration(days: 30));
    String contractTerm = 'Süresiz (Belirsiz Süreli)';
    String partTimeDuration = '6 Ay Süreli';
    String hourlyDuration = 'Açık Uçlu / İhtiyaca Göre';
    DateTime? customEndDate;

    final dateFormat = DateFormat('dd.MM.yyyy');

    Map<String, String> getFeeMeta(String type) {
      switch (type) {
        case 'Proje Bazlı (Freelance)':
          return {
            'label': 'Toplam Proje Bedeli (Net ₺)',
            'suffix': '₺ / Proje',
            'hint': '35.000',
            'desc': 'Tüm çizim teslimi ve pafta revizyonları dahil toplam götürü bedel.',
          };
        case 'Tam Zamanlı (Bordrolu / Ofis)':
          return {
            'label': 'Aylık Net Maaş (₺)',
            'suffix': '₺ / Ay',
            'hint': '55.000',
            'desc': 'Ofis içi tam zamanlı çalışma için teklif edilen aylık net maaş.',
          };
        case 'Tam Zamanlı (Uzaktan / Remote)':
          return {
            'label': 'Aylık Net Maaş (₺)',
            'suffix': '₺ / Ay',
            'hint': '50.000',
            'desc': 'Uzaktan (home-office) tam zamanlı çalışma için teklif edilen aylık net maaş.',
          };
        case 'Yarı Zamanlı (Part-Time)':
          return {
            'label': 'Aylık Net Ücret (₺)',
            'suffix': '₺ / Ay',
            'hint': '25.000',
            'desc': 'Haftalık / aylık yarı zamanlı mesai karşılığı net hak ediş teklifi.',
          };
        case 'Saatlik / Danışmanlık':
          return {
            'label': 'Saatlik Net Ücret (₺)',
            'suffix': '₺ / Saat',
            'hint': '750',
            'desc': 'Çizim yapılan veya danışmanlık verilen saat başına net hakediş bedeli.',
          };
        case 'Dönemsel / Sözleşmeli':
          return {
            'label': 'Aylık Hak Ediş Bedeli (Net ₺)',
            'suffix': '₺ / Ay',
            'hint': '45.000',
            'desc': 'Belirtilen proje süresi boyunca aylık düzenli ödenecek tutar.',
          };
        default:
          return {
            'label': 'Bütçe / Ücret (₺)',
            'suffix': '₺',
            'hint': '30.000',
            'desc': 'Teklif edilen net ücret bedeli.',
          };
      }
    }

    String computeBudgetString() {
      final text = amountController.text.trim();
      final meta = getFeeMeta(selectedWorkType);
      final suffix = meta['suffix']!;
      if (text.isEmpty) return 'Belirtilmedi';
      if (text.contains('₺') || text.contains('/')) return text;
      return '$text $suffix';
    }

    String computeDeadlineString() {
      final startStr = isImmediateStart ? 'Hemen Başlama' : dateFormat.format(startDate);

      if (selectedWorkType == 'Proje Bazlı (Freelance)' || selectedWorkType == 'Dönemsel / Sözleşmeli') {
        final diffDays = endDate.difference(startDate).inDays;
        final daysStr = diffDays > 0 ? ' ($diffDays Gün)' : '';
        return 'Başlama: $startStr • Teslim: ${dateFormat.format(endDate)}$daysStr';
      } else if (selectedWorkType.startsWith('Tam Zamanlı')) {
        if (contractTerm == 'Özel Bitiş Tarihi Seç' && customEndDate != null) {
          return 'Başlama: $startStr • Bitiş: ${dateFormat.format(customEndDate!)}';
        }
        return 'Başlama: $startStr • Sözleşme: $contractTerm';
      } else if (selectedWorkType == 'Saatlik / Danışmanlık') {
        if (hourlyDuration == 'Özel Bitiş Tarihi Seç' && customEndDate != null) {
          return 'Başlama: $startStr • Bitiş: ${dateFormat.format(customEndDate!)}';
        }
        return 'Başlama: $startStr • Süreç: $hourlyDuration';
      } else if (selectedWorkType == 'Yarı Zamanlı (Part-Time)') {
        if (partTimeDuration == 'Özel Bitiş Tarihi Seç' && customEndDate != null) {
          return 'Başlama: $startStr • Bitiş: ${dateFormat.format(customEndDate!)}';
        }
        return 'Başlama: $startStr • Süreç: $partTimeDuration';
      }
      return 'Başlama: $startStr';
    }

    String computeDurationString() {
      if (selectedWorkType == 'Proje Bazlı (Freelance)' || selectedWorkType == 'Dönemsel / Sözleşmeli') {
        final diffDays = endDate.difference(startDate).inDays;
        if (diffDays > 0) {
          return '$selectedWorkType ($diffDays Gün)';
        }
      }
      return selectedWorkType;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.94,
          maxWidth: 760,
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.blueprintDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.cyanLine, width: 2)),
        ),
        child: StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final feeMeta = getFeeMeta(selectedWorkType);

            Future<void> pickStartDate() async {
              final picked = await showDatePicker(
                context: dialogCtx,
                initialDate: startDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppTheme.cyanLine,
                      onPrimary: AppTheme.blueprintDark,
                      surface: AppTheme.blueprintSurface,
                      onSurface: AppTheme.textLight,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setDialogState(() {
                  startDate = picked;
                  isImmediateStart = false;
                  if (endDate.isBefore(startDate)) {
                    endDate = startDate.add(const Duration(days: 14));
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: dialogCtx,
                initialDate: endDate.isAfter(startDate) ? endDate : startDate.add(const Duration(days: 14)),
                firstDate: startDate,
                lastDate: DateTime.now().add(const Duration(days: 1825)),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppTheme.cyanLine,
                      onPrimary: AppTheme.blueprintDark,
                      surface: AppTheme.blueprintSurface,
                      onSurface: AppTheme.textLight,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setDialogState(() {
                  endDate = picked;
                  customEndDate = picked;
                });
              }
            }

            Future<void> pickOfferFiles() async {
              try {
                final result = await FilePicker.pickFiles(type: FileType.any);
                if (result.isNotEmpty) {
                  for (final file in result) {
                    if (file.path != null) {
                      final f = File(file.path!);
                      if (await f.exists()) {
                        final bytes = await f.readAsBytes();
                        if (bytes.lengthInBytes > 30 * 1024 * 1024) {
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.statusWarning,
                                content: Text('${file.name} boyutu 30MB üzerinde, eklenemedi.'),
                              ),
                            );
                          }
                          continue;
                        }
                        final base64Str = base64Encode(bytes);
                        final ext = file.extension?.toLowerCase() ??
                            (file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '');
                        setDialogState(() {
                          offerAttachments.add(
                            OfferAttachment(
                              id: const Uuid().v4(),
                              fileName: file.name,
                              fileExtension: ext,
                              fileSize: bytes.lengthInBytes,
                              fileBase64: base64Str,
                              localPath: file.path,
                            ),
                          );
                        });
                      }
                    }
                  }
                }
              } catch (e) {
                debugPrint('Dosya seçme hatası: $e');
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.steelBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.cyanLine.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: AppTheme.cyanLine, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'İş Teklifini Düzenle',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                            Text(
                              'Alıcı: ${offer.draftsmanName}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSubtle),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. PROJE / İŞ BAŞLIĞI
                          const Text('PROJE VEYA POZİSYON BAŞLIĞI',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: titleController,
                            style: const TextStyle(color: AppTheme.textLight, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Örn: Çelik Konstrüksiyon Fabrika İmalat Paftaları',
                              prefixIcon: Icon(Icons.work_outline, size: 18, color: AppTheme.cyanLine),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Proje başlığı giriniz' : null,
                          ),
                          const SizedBox(height: 14),

                          // 2. ÇALIŞMA MODELİ
                          const Text('ÇALIŞMA & İŞ MODELİ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.steelBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedWorkType,
                                isExpanded: true,
                                dropdownColor: AppTheme.blueprintSurface,
                                style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                                items: workTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedWorkType = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. ÜCRET
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(feeMeta['label']!,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine, letterSpacing: 0.5)),
                              Text(feeMeta['suffix']!,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.amberSteel)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: amountController,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(color: AppTheme.amberSteel, fontSize: 15, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: feeMeta['hint'],
                              prefixIcon: const Icon(Icons.payments_outlined, size: 18, color: AppTheme.amberSteel),
                              suffixText: feeMeta['suffix'],
                              helperText: feeMeta['desc'],
                              helperMaxLines: 2,
                              helperStyle: const TextStyle(color: AppTheme.textSubtle, fontSize: 10),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Ücret belirtilmelidir' : null,
                          ),
                          const SizedBox(height: 14),

                          // 4. BAŞLAMA & BİTİŞ TAKVİMİ
                          const Text('BAŞLAMA & BİTİŞ TAKVİMİ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.steelBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.cyanLine),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('İşe / Projeye Başlama', style: TextStyle(fontSize: 10, color: AppTheme.textSubtle)),
                                      Text(
                                        isImmediateStart ? 'Hemen Başlama (Anında)' : dateFormat.format(startDate),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      isImmediateStart = !isImmediateStart;
                                      if (isImmediateStart) startDate = DateTime.now();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isImmediateStart ? AppTheme.cyanLine.withValues(alpha: 0.25) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isImmediateStart ? AppTheme.cyanLine : AppTheme.steelBorder),
                                    ),
                                    child: Text('⚡ Hemen',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isImmediateStart ? FontWeight.bold : FontWeight.normal,
                                            color: isImmediateStart ? AppTheme.cyanLine : AppTheme.textSubtle)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppTheme.cyanLine),
                                  tooltip: 'Başlama Tarihi Seç',
                                  onPressed: pickStartDate,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Bitiş / Süreç Kartı
                          if (selectedWorkType == 'Proje Bazlı (Freelance)' || selectedWorkType == 'Dönemsel / Sözleşmeli') ...[
                            InkWell(
                              onTap: pickEndDate,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.blueprintSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.steelBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event_available_rounded, size: 16, color: AppTheme.amberSteel),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedWorkType == 'Proje Bazlı (Freelance)'
                                                ? 'Teslim / Bitiş Tarihi (Deadline)'
                                                : 'Sözleşme Bitiş Tarihi',
                                            style: const TextStyle(fontSize: 10, color: AppTheme.textSubtle),
                                          ),
                                          Text(dateFormat.format(endDate),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.amberSteel.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '⏱️ ${endDate.difference(startDate).inDays > 0 ? '${endDate.difference(startDate).inDays} Gün' : 'Aynı Gün'}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.amberSteel),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSubtle),
                                  ],
                                ),
                              ),
                            ),
                          ] else if (selectedWorkType.startsWith('Tam Zamanlı')) ...[
                            DropdownButtonFormField<String>(
                              initialValue: contractTerm,
                              dropdownColor: AppTheme.blueprintSurface,
                              decoration: const InputDecoration(
                                labelText: 'Sözleşme Süresi',
                                prefixIcon: Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppTheme.cyanLine),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'Süresiz (Belirsiz Süreli)', child: Text('Süresiz (Belirsiz Süreli)')),
                                DropdownMenuItem(value: '2 Ay Deneme Süreli (Süresiz)', child: Text('2 Ay Deneme Süreli (Süresiz)')),
                                DropdownMenuItem(value: '6 Ay Belirli Süreli', child: Text('6 Ay Belirli Süreli')),
                                DropdownMenuItem(value: '1 Yıl Belirli Süreli', child: Text('1 Yıl Belirli Süreli')),
                              ],
                              onChanged: (v) {
                                if (v != null) setDialogState(() => contractTerm = v);
                              },
                            ),
                          ],
                          const SizedBox(height: 14),

                          // 5. PROJE KAPSAMI & ŞARTNAME
                          const Text('PROJE KAPSAMI VE BEKLENTİLER',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: descController,
                            maxLines: 4,
                            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Çizim detayları, program gereksinimleri, standartlar ve beklentileriniz...',
                              contentPadding: EdgeInsets.all(12),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Proje açıklaması giriniz' : null,
                          ),
                          const SizedBox(height: 14),

                          // 6. PROJE DOSYALARI & EKLER
                          const Text('PROJE DOSYALARI & ŞARTNAME (İSTEĞE BAĞLI)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.steelBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.attach_file_rounded, size: 16, color: AppTheme.cyanLine),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'DWG, DXF, STEP, SLDPRT, RVT, IFC, PDF veya arşiv dosyası ekleyin.',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: pickOfferFiles,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppTheme.cyanLine),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.add, size: 14, color: AppTheme.cyanLine),
                                      label: const Text('Dosya Ekle', style: TextStyle(fontSize: 11, color: AppTheme.cyanLine)),
                                    ),
                                  ],
                                ),
                                if (offerAttachments.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: offerAttachments.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                                    itemBuilder: (ctx, idx) {
                                      final att = offerAttachments[idx];
                                      final fileColor = FileHelper.getFileColor(att.fileExtension);
                                      final fileIcon = FileHelper.getFileIcon(att.fileExtension);
                                      final sizeStr = FileHelper.formatFileSize(att.fileSize);
                                      final ext = att.fileExtension.toUpperCase();

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: AppTheme.blueprintDark,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: fileColor.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: fileColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: fileColor.withValues(alpha: 0.5)),
                                              ),
                                              child: Icon(fileIcon, size: 16, color: fileColor),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    att.fileName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: fileColor.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(3),
                                                        ),
                                                        child: Text(
                                                          ext.isEmpty ? 'DOSYA' : ext,
                                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fileColor),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(sizeStr, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close, size: 18, color: AppTheme.statusDanger),
                                              tooltip: 'Dosyayı Çıkar',
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () {
                                                setDialogState(() {
                                                  offerAttachments.removeAt(idx);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // CANLI ÖZET
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.remove_red_eye_outlined, size: 14, color: AppTheme.cyanLine),
                                    SizedBox(width: 6),
                                    Text('Güncellenen Teklif Özeti',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('• Model: ${computeDurationString()}', style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                                Text('• Ücret: ${computeBudgetString()}', style: const TextStyle(fontSize: 11, color: AppTheme.amberSteel, fontWeight: FontWeight.bold)),
                                Text('• Takvim: ${computeDeadlineString()}', style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine)),
                                if (offerAttachments.isNotEmpty)
                                  Text('• Ekler: ${offerAttachments.length} adet dosya eklendi', style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: AppTheme.blueprintSurface,
                    border: Border(top: BorderSide(color: AppTheme.steelBorder)),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textSubtle)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cyanLine,
                            foregroundColor: AppTheme.blueprintDark,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text(
                            'DEĞİŞİKLİKLERİ KAYDET VE İLET',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final updatedOffer = offer.copyWith(
                              projectTitle: titleController.text.trim(),
                              description: descController.text.trim(),
                              budget: computeBudgetString(),
                              projectDuration: computeDurationString(),
                              deadline: computeDeadlineString(),
                              attachments: List.from(offerAttachments),
                              status: 'pending',
                              createdAt: DateTime.now(),
                            );

                            final nav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(context);

                            await _localDb.saveOffer(updatedOffer);
                            final success = await _p2pService.sendOfferToDraftsman(
                              offer: updatedOffer,
                              draftsmanPeerId: offer.draftsmanId,
                              draftsmanPublicKey: offer.draftsmanId,
                            );

                            await _loadOffers();
                            nav.pop();

                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: success ? AppTheme.statusSuccess : AppTheme.statusWarning,
                                content: Text(
                                  success
                                      ? '✓ İş teklifi başarıyla güncellendi ve adaya iletildi!'
                                      : '✓ Teklif yerel olarak güncellendi (Aday çevrimdışı olunca Nostr kuyruğuna alındı).',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showOfferDetail(OfferModel offer) {
    final draftsmanPhone = offer.draftsmanPhone ?? '';
    final draftsmanEmail = offer.draftsmanEmail ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      offer.projectTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    ),
                  ),
                  _buildStatusBadge(offer.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Aday: ${offer.draftsmanName} • ${offer.branch}',
                style: const TextStyle(fontSize: 13, color: AppTheme.cyanLine, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),

              // Bütçe ve Çalışma Süresi Kartı
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.steelBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Teklif Edilen Bütçe',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                          const SizedBox(height: 2),
                          Text(offer.budget,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.amberSteel)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 35, color: AppTheme.steelBorder),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Çalışma / Süre',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                          const SizedBox(height: 2),
                          Text(offer.projectDuration,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cyanLine)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Proje Kapsamı
              const Text('Proje Detayları ve Kapsam',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.cyanLine)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  offer.description,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.cyanLine),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Takvim & Teslimat: ${offer.deadline}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (offer.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.attachment_rounded, size: 16, color: AppTheme.cyanLine),
                    const SizedBox(width: 6),
                    Text(
                      'Eklenen Proje Dosyaları (${offer.attachments.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cyanLine),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: offer.attachments.map((att) {
                    final fileColor = FileHelper.getFileColor(att.fileExtension);
                    final fileIcon = FileHelper.getFileIcon(att.fileExtension);
                    final sizeStr = FileHelper.formatFileSize(att.fileSize);
                    final ext = att.fileExtension.toUpperCase();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.blueprintSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: fileColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: fileColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: fileColor.withValues(alpha: 0.5)),
                            ),
                            child: Icon(fileIcon, size: 16, color: fileColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  att.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: fileColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        ext.isEmpty ? 'DOSYA' : ext,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fileColor),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sizeStr,
                                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),

              // --- TEKLİF KABUL EDİLDİĞİNDE ADAYIN İLETİŞİM BİLGİLERİ KARTI ---
              if (offer.status == 'accepted') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.statusSuccess, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.statusSuccess.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: AppTheme.statusSuccess, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'TEKLİF KABUL EDİLDİ • İLETİŞİM BİLGİLERİ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.statusSuccess,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Aday Bilgileri
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.cyanLine),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${offer.draftsmanName} ${offer.draftsmanTitle != null ? '(${offer.draftsmanTitle})' : ''}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                          ),
                        ],
                      ),
                      if (offer.draftsmanCity != null && offer.draftsmanCity!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.cyanLine),
                            const SizedBox(width: 8),
                            Text(
                              offer.draftsmanCity!,
                              style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Aday Telefon Bilgisi & Aksiyonlar
                      if (draftsmanPhone.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.blueprintDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.steelBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_rounded, size: 18, color: AppTheme.statusSuccess),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  draftsmanPhone,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.statusSuccess,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.call, size: 13),
                                label: const Text('Ara', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _makePhoneCall(draftsmanPhone),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppTheme.statusSuccess),
                                tooltip: 'WhatsApp ile Yaz',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _openWhatsApp(draftsmanPhone),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: AppTheme.cyanLine),
                                tooltip: 'Numarayı Kopyala',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _copyText('Telefon', draftsmanPhone),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Aday E-posta Bilgisi & Aksiyonlar
                      if (draftsmanEmail.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.blueprintDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.steelBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mail_outline_rounded, size: 18, color: AppTheme.cyanLine),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  draftsmanEmail,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.cyanLine,
                                  foregroundColor: AppTheme.blueprintDark,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.send_rounded, size: 13),
                                label: const Text('E-Posta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _sendEmail(draftsmanEmail),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: AppTheme.cyanLine),
                                tooltip: 'E-postayı Kopyala',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _copyText('E-posta', draftsmanEmail),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Aday LinkedIn & Kariyer.net Profil Linkleri
                      if (offer.draftsmanLinkedin != null && offer.draftsmanLinkedin!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final uri = Uri.tryParse(offer.draftsmanLinkedin!.trim());
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              await _copyText('LinkedIn Linki', offer.draftsmanLinkedin!);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link, size: 18, color: AppTheme.cyanLine),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'LinkedIn: ${offer.draftsmanLinkedin!}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.open_in_new, size: 14, color: AppTheme.cyanLine),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (offer.draftsmanKariyerNet != null && offer.draftsmanKariyerNet!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final uri = Uri.tryParse(offer.draftsmanKariyerNet!.trim());
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              await _copyText('Kariyer.net Linki', offer.draftsmanKariyerNet!);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.blueprintDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.work_outline, size: 18, color: AppTheme.amberSteel),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Kariyer.net: ${offer.draftsmanKariyerNet!}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.amberSteel),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.open_in_new, size: 14, color: AppTheme.amberSteel),
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (draftsmanPhone.isEmpty && draftsmanEmail.isEmpty) ...[
                        const Text(
                          'Aday teklifi kabul etti. Profil iletişim bilgileri aktarılıyor...',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],

                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 13, color: AppTheme.textSubtle),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Aday bu iletişim bilgilerini teklifi kabul ederek uçtan uca şifreli kanalla şirketinize aktarmıştır.',
                              style: TextStyle(fontSize: 10, color: AppTheme.textSubtle),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (offer.status == 'pending') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_empty_rounded, size: 18, color: AppTheme.amberSteel),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Teklif henüz beklemede. Aday teklifinizi kabul ettiği anda telefon, WhatsApp ve e-posta bilgileri doğrudan bu alanda açılacaktır.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Aday Yanıt Notu
              if (offer.responseNote != null && offer.responseNote!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: offer.status == 'accepted' ? AppTheme.statusSuccess.withValues(alpha: 0.5) : AppTheme.steelBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adayın Yanıt Notu:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(offer.responseNote!, style: const TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (offer.status == 'pending' || offer.status == 'rejected') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.amberSteel,
                      foregroundColor: AppTheme.blueprintDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.blueprintDark),
                    label: const Text(
                      'TEKLİFİ DÜZENLE & YENİDEN İLET',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showEditOfferDialog(offer);
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              const Divider(),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Uçtan uca X25519 şifreli P2P teklif.',
                    style: TextStyle(color: AppTheme.textSubtle, fontSize: 11),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textSubtle),
                    label: const Text('Teklifi Sil', style: TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteOffer(offer);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlueprintHeader(
        title: 'Gönderilen Teklifler',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.block, color: AppTheme.textSubtle, size: 20),
              tooltip: 'Engellenen Adaylar',
              onPressed: () => BlockedUsersDialog.show(context, 'company', _loadOffers),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textSubtle),
              tooltip: 'Teklifleri Sıfırla / Temizle',
              onPressed: _confirmClearAllOffers,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: AppTheme.blueprintSurface,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.cyanLine,
                    labelColor: AppTheme.cyanLine,
                    unselectedLabelColor: AppTheme.textSubtle,
                    tabs: const [
                      Tab(text: 'Tümü'),
                      Tab(text: 'Bekleyenler'),
                      Tab(text: 'Kabul Edilen'),
                      Tab(text: 'Reddedilen'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOffersList(_sentOffers),
                      _buildOffersList(_sentOffers.where((o) => o.status == 'pending').toList()),
                      _buildOffersList(_sentOffers.where((o) => o.status == 'accepted').toList()),
                      _buildOffersList(_sentOffers.where((o) => o.status == 'rejected').toList()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOffersList(List<OfferModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.outbox_outlined, size: 54, color: AppTheme.textSubtle),
              const SizedBox(height: 14),
              const Text(
                'Gönderilen Teklif Bulunmuyor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight),
              ),
              const SizedBox(height: 6),
              const Text(
                'P2P ağındaki adayları keşfedip şifreli iş teklifi gönderdiğinizde durumları burada listelenecektir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final offer = list[i];
        final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.blueprintCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.steelBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showOfferDetail(offer),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          offer.draftsmanName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.cyanLine),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(offer.status),
                      if (offer.status == 'pending' || offer.status == 'rejected') ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showEditOfferDialog(offer),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.amberSteel.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.amberSteel),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _confirmDeleteOffer(offer),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 16, color: AppTheme.textSubtle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.projectTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (offer.status == 'accepted') ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.statusSuccess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.phone_in_talk_rounded, size: 14, color: AppTheme.statusSuccess),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Aday İletişim Bilgileri Açık (Görüntülemek için dokunun)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusSuccess),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.statusSuccess),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monetization_on_outlined, size: 14, color: AppTheme.amberSteel),
                          const SizedBox(width: 4),
                          Text(
                            offer.budget,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.amberSteel),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: AppTheme.textSubtle),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(offer.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color textColor;
    String label;

    switch (status) {
      case 'accepted':
        bg = AppTheme.statusSuccess.withValues(alpha: 0.2);
        textColor = AppTheme.statusSuccess;
        label = 'KABUL EDİLDİ';
        break;
      case 'rejected':
        bg = AppTheme.statusDanger.withValues(alpha: 0.2);
        textColor = AppTheme.statusDanger;
        label = 'REDDEDİLDİ';
        break;
      case 'pending':
      default:
        bg = AppTheme.amberSteel.withValues(alpha: 0.2);
        textColor = AppTheme.amberSteel;
        label = 'BEKLİYOR';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
