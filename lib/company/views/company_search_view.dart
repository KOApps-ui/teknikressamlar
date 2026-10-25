import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/user_profile.dart';
import '../../core/models/offer_model.dart';
import '../../core/services/p2p_service.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/file_launcher_service.dart';
import '../../core/services/edevlet_service.dart';
import '../../core/utils/file_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blueprint_header.dart';
import '../../core/widgets/subscription_modal.dart';
import '../../core/widgets/subscription_paywall_dialog.dart';
import '../../core/widgets/blocked_users_dialog.dart';

class CompanySearchView extends StatefulWidget {
  const CompanySearchView({super.key});

  @override
  State<CompanySearchView> createState() => _CompanySearchViewState();
}

class _CompanySearchViewState extends State<CompanySearchView> {
  final _p2pService = P2PService();
  final _localDb = LocalDbService();
  final _uuid = const Uuid();

  UserProfile? _companyProfile;
  String _selectedBranch = 'Tümü';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Timer? _scanTimer;
  Set<String> _blockedUserIds = {};
  CompanyLicense? _companyLicense;

  static const List<String> branchFilters = [
    'Tümü',
    'Çelik Yapı & Konstrüksiyon',
    'Betonarme & Statik',
    'Harita & Altyapı',
    'Mekanik & Tesisat & HVAC',
    'Elektrik & Otomasyon',
    'Mimari & Cephe Çizimi',
    'Makine & Endüstriyel İmalat',
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyData() async {
    final profile = await _localDb.getUserProfile();
    final blocked = await _localDb.getBlockedUsers();
    final lic = await SubscriptionService().getLicense();
    if (!mounted) return;
    setState(() {
      _companyProfile = profile;
      _blockedUserIds = blocked.map((b) => b['id'] as String).toSet();
      _companyLicense = lic;
    });

    if (_companyProfile != null) {
      await _p2pService.start(userProfile: _companyProfile!);
      await _p2pService.listenBranch('all');
      await _p2pService.scanNetwork();
    }
  }

  Future<void> _confirmBlockCandidate(Map<String, dynamic> candidate) async {
    final name = candidate['name'] as String? ?? 'Bu Aday';
    final candidateId = candidate['id'] as String? ?? candidate['publicKey'] as String? ?? '';
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
            Icon(Icons.block, color: AppTheme.statusDanger),
            SizedBox(width: 8),
            Text('Adayı Engelle / Yoksay', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$name isimli adayı engellemek ve aday arama listenizden gizlemek istediğinize emin misiniz? Dilediğiniz zaman engellenenler menüsünden kaldırabilirsiniz.',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Engelle & Gizle'),
          ),
        ],
      ),
    );

    if (confirm == true && candidateId.isNotEmpty) {
      await _localDb.blockUser(
        userId: candidateId,
        name: name,
        role: 'draftsman',
        note: candidate['branch'] as String? ?? '',
      );
      final blocked = await _localDb.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUserIds = blocked.map((b) => b['id'] as String).toSet();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('$name engellendi ve listeden kaldırıldı.'),
          ),
        );
      }
    }
  }

  void _onBranchSelected(String branch) {
    setState(() {
      _selectedBranch = branch;
    });
    _p2pService.listenBranch(branch == 'Tümü' ? 'all' : branch);
  }

  Future<void> _showOfferDialog(Map<String, dynamic> candidate) async {
    if (_companyProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusDanger,
          content: Text('Teklif göndermek için önce şirket profilinizi kaydedin.'),
        ),
      );
      return;
    }

    final subCheck = await SubscriptionService().canSendOffer();
    if (!subCheck.allowed) {
      if (mounted) {
        final activated = await SubscriptionPaywallDialog.show(
          context,
          _companyProfile!,
          () => setState(() {}),
        );
        if (activated != true) return;
      }
    }

    if (!mounted) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController(text: '35.000');
    final formKey = GlobalKey<FormState>();
    final List<OfferAttachment> offerAttachments = [];

    const workTypes = [
      'Proje Bazlı (Freelance)',
      'Tam Zamanlı (Bordrolu / Ofis)',
      'Tam Zamanlı (Uzaktan / Remote)',
      'Yarı Zamanlı (Part-Time)',
      'Saatlik / Danışmanlık',
      'Dönemsel / Sözleşmeli',
    ];

    String selectedWorkType = 'Proje Bazlı (Freelance)';
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    bool isImmediateStart = false;
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
            'defaultAmount': '35.000',
            'desc': 'Tüm çizim teslimi ve pafta revizyonları dahil toplam götürü bedel.',
          };
        case 'Tam Zamanlı (Bordrolu / Ofis)':
          return {
            'label': 'Aylık Net Maaş (₺)',
            'suffix': '₺ / Ay',
            'hint': '55.000',
            'defaultAmount': '55.000',
            'desc': 'Ofis içi tam zamanlı çalışma için teklif edilen aylık net maaş.',
          };
        case 'Tam Zamanlı (Uzaktan / Remote)':
          return {
            'label': 'Aylık Net Maaş (₺)',
            'suffix': '₺ / Ay',
            'hint': '50.000',
            'defaultAmount': '50.000',
            'desc': 'Uzaktan (home-office) tam zamanlı çalışma için teklif edilen aylık net maaş.',
          };
        case 'Yarı Zamanlı (Part-Time)':
          return {
            'label': 'Aylık Net Ücret (₺)',
            'suffix': '₺ / Ay',
            'hint': '25.000',
            'defaultAmount': '25.000',
            'desc': 'Haftalık / aylık yarı zamanlı mesai karşılığı net hak ediş teklifi.',
          };
        case 'Saatlik / Danışmanlık':
          return {
            'label': 'Saatlik Net Ücret (₺)',
            'suffix': '₺ / Saat',
            'hint': '750',
            'defaultAmount': '750',
            'desc': 'Çizim yapılan veya danışmanlık verilen saat başına net hakediş bedeli.',
          };
        case 'Dönemsel / Sözleşmeli':
          return {
            'label': 'Aylık Hak Ediş Bedeli (Net ₺)',
            'suffix': '₺ / Ay',
            'hint': '45.000',
            'defaultAmount': '45.000',
            'desc': 'Belirtilen proje süresi boyunca aylık düzenli ödenecek tutar.',
          };
        default:
          return {
            'label': 'Bütçe / Ücret (₺)',
            'suffix': '₺',
            'hint': '30.000',
            'defaultAmount': '30.000',
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
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
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
                final result = await FilePicker.pickFiles(
                  type: FileType.any,
                );
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
                              id: _uuid.v4(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.send_rounded, color: AppTheme.cyanLine, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${candidate['name']} İle Şifreli P2P Teklifi',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                            Text(
                              '${candidate['title'] ?? ''} • ${candidate['branch'] ?? ''}',
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.blueprintSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.steelBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: AppTheme.cyanLine),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Uçtan uca X25519 şifreli teklif. Yalnızca adayın cihazı açabilir.',
                                style: TextStyle(color: AppTheme.textSubtle, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 1. Proje / Pozisyon Başlığı
                      TextFormField(
                        controller: titleController,
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Proje / Pozisyon Başlığı *',
                          hintText: 'Örn: Çerkezköy Fabrika Çelik Detay İmalat Çizimi',
                          prefixIcon: Icon(Icons.title_rounded, size: 18, color: AppTheme.cyanLine),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Başlık gereklidir' : null,
                      ),
                      const SizedBox(height: 10),

                      // 2. Kapsam ve Açıklama
                      TextFormField(
                        controller: descController,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Proje Kapsamı ve Beklentiler *',
                          hintText: 'Tekla Structures ile birleşim detayları, metraj ve imalat paftaları...',
                          prefixIcon: Icon(Icons.description_outlined, size: 18, color: AppTheme.cyanLine),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Kapsam gereklidir' : null,
                      ),
                      const SizedBox(height: 14),

                      // 3. ÇALIŞMA TİPİ SEÇİMİ
                      const Text(
                        'ÇALIŞMA TİPİ & MODELİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cyanLine,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('work_type_$selectedWorkType'),
                        initialValue: selectedWorkType,
                        dropdownColor: AppTheme.blueprintSurface,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.work_outline_rounded, size: 18, color: AppTheme.cyanLine),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                        items: workTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type, style: const TextStyle(color: AppTheme.textLight)),
                          );
                        }).toList(),
                        onChanged: (newVal) {
                          if (newVal == null) return;
                          setDialogState(() {
                            selectedWorkType = newVal;
                            final newMeta = getFeeMeta(newVal);
                            amountController.text = newMeta['defaultAmount']!;
                            if (newVal == 'Dönemsel / Sözleşmeli') {
                              endDate = startDate.add(const Duration(days: 90));
                            } else if (newVal == 'Proje Bazlı (Freelance)') {
                              endDate = startDate.add(const Duration(days: 30));
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      // 4. ÇALIŞMA TİPİNE GÖRE DİNAMİK ÜCRET ALANI
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            feeMeta['label']!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.amberSteel,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.amberSteel.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              feeMeta['suffix']!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.amberSteel,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(
                          color: AppTheme.amberSteel,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: feeMeta['hint'],
                          prefixIcon: const Icon(Icons.payments_outlined, size: 18, color: AppTheme.amberSteel),
                          suffixText: feeMeta['suffix'],
                          suffixStyle: const TextStyle(color: AppTheme.textSubtle, fontSize: 12),
                          helperText: feeMeta['desc'],
                          helperMaxLines: 2,
                          helperStyle: const TextStyle(color: AppTheme.textSubtle, fontSize: 10),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Ücret tutarı belirtilmelidir' : null,
                      ),
                      const SizedBox(height: 14),

                      // 5. BAŞLAMA TARİHİ VE BİTİŞ TARİHLERİ
                      const Text(
                        'BAŞLAMA & BİTİŞ TAKVİMİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cyanLine,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Başlama Tarihi Kartı
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
                                  const Text(
                                    'İşe / Projeye Başlama',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textSubtle),
                                  ),
                                  Text(
                                    isImmediateStart ? 'Hemen Başlama (Anında)' : dateFormat.format(startDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  isImmediateStart = !isImmediateStart;
                                  if (isImmediateStart) {
                                    startDate = DateTime.now();
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isImmediateStart
                                      ? AppTheme.cyanLine.withValues(alpha: 0.25)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isImmediateStart ? AppTheme.cyanLine : AppTheme.steelBorder,
                                  ),
                                ),
                                child: Text(
                                  '⚡ Hemen',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isImmediateStart ? FontWeight.bold : FontWeight.normal,
                                    color: isImmediateStart ? AppTheme.cyanLine : AppTheme.textSubtle,
                                  ),
                                ),
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

                      // Bitiş / Süreç Kartı (Çalışma tipine göre)
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
                                      Text(
                                        dateFormat.format(endDate),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textLight,
                                        ),
                                      ),
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
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.amberSteel,
                                    ),
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
                          key: ValueKey('contract_term_$contractTerm'),
                          initialValue: contractTerm,
                          dropdownColor: AppTheme.blueprintSurface,
                          decoration: const InputDecoration(
                            labelText: 'Sözleşme & Çalışma Süresi',
                            prefixIcon: Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppTheme.cyanLine),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                          items: const [
                            DropdownMenuItem(
                              value: 'Süresiz (Belirsiz Süreli)',
                              child: Text('Süresiz (Belirsiz Süreli)'),
                            ),
                            DropdownMenuItem(
                              value: '2 Ay Deneme Süreli (Süresiz)',
                              child: Text('2 Ay Deneme Süreli (Süresiz)'),
                            ),
                            DropdownMenuItem(
                              value: '6 Ay Belirli Süreli',
                              child: Text('6 Ay Belirli Süreli'),
                            ),
                            DropdownMenuItem(
                              value: '1 Yıl Belirli Süreli',
                              child: Text('1 Yıl Belirli Süreli'),
                            ),
                            DropdownMenuItem(
                              value: 'Özel Bitiş Tarihi Seç',
                              child: Text('Özel Bitiş Tarihi Seç...'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setDialogState(() {
                              contractTerm = val;
                            });
                            if (val == 'Özel Bitiş Tarihi Seç') {
                              pickEndDate();
                            }
                          },
                        ),
                        if (contractTerm == 'Özel Bitiş Tarihi Seç' && customEndDate != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: pickEndDate,
                            child: Text(
                              '📅 Seçilen Bitiş: ${dateFormat.format(customEndDate!)} (Değiştir)',
                              style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine),
                            ),
                          ),
                        ],
                      ] else if (selectedWorkType == 'Saatlik / Danışmanlık') ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey('hourly_duration_$hourlyDuration'),
                          initialValue: hourlyDuration,
                          dropdownColor: AppTheme.blueprintSurface,
                          decoration: const InputDecoration(
                            labelText: 'Danışmanlık Süreci & Süresi',
                            prefixIcon: Icon(Icons.timer_outlined, size: 18, color: AppTheme.cyanLine),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                          items: const [
                            DropdownMenuItem(
                              value: 'Açık Uçlu / İhtiyaca Göre',
                              child: Text('Açık Uçlu / İhtiyaca Göre'),
                            ),
                            DropdownMenuItem(
                              value: '1 Ay Danışmanlık',
                              child: Text('1 Ay Danışmanlık'),
                            ),
                            DropdownMenuItem(
                              value: '3 Ay Danışmanlık',
                              child: Text('3 Ay Danışmanlık'),
                            ),
                            DropdownMenuItem(
                              value: '6 Ay Danışmanlık',
                              child: Text('6 Ay Danışmanlık'),
                            ),
                            DropdownMenuItem(
                              value: 'Özel Bitiş Tarihi Seç',
                              child: Text('Özel Bitiş Tarihi Seç...'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setDialogState(() {
                              hourlyDuration = val;
                            });
                            if (val == 'Özel Bitiş Tarihi Seç') {
                              pickEndDate();
                            }
                          },
                        ),
                        if (hourlyDuration == 'Özel Bitiş Tarihi Seç' && customEndDate != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: pickEndDate,
                            child: Text(
                              '📅 Seçilen Bitiş: ${dateFormat.format(customEndDate!)} (Değiştir)',
                              style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine),
                            ),
                          ),
                        ],
                      ] else if (selectedWorkType == 'Yarı Zamanlı (Part-Time)') ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey('part_time_$partTimeDuration'),
                          initialValue: partTimeDuration,
                          dropdownColor: AppTheme.blueprintSurface,
                          decoration: const InputDecoration(
                            labelText: 'Yarı Zamanlı Çalışma Süresi',
                            prefixIcon: Icon(Icons.timelapse_rounded, size: 18, color: AppTheme.cyanLine),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                          items: const [
                            DropdownMenuItem(
                              value: '3 Ay Süreli',
                              child: Text('3 Ay Süreli'),
                            ),
                            DropdownMenuItem(
                              value: '6 Ay Süreli',
                              child: Text('6 Ay Süreli'),
                            ),
                            DropdownMenuItem(
                              value: '1 Yıl Süreli',
                              child: Text('1 Yıl Süreli'),
                            ),
                            DropdownMenuItem(
                              value: 'Süresiz',
                              child: Text('Süresiz'),
                            ),
                            DropdownMenuItem(
                              value: 'Özel Bitiş Tarihi Seç',
                              child: Text('Özel Bitiş Tarihi Seç...'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setDialogState(() {
                              partTimeDuration = val;
                            });
                            if (val == 'Özel Bitiş Tarihi Seç') {
                              pickEndDate();
                            }
                          },
                        ),
                        if (partTimeDuration == 'Özel Bitiş Tarihi Seç' && customEndDate != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: pickEndDate,
                            child: Text(
                              '📅 Seçilen Bitiş: ${dateFormat.format(customEndDate!)} (Değiştir)',
                              style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),

                      // PROJE DOSYALARI & ÇİZİMLER (İSTEĞE BAĞLI)
                      const Text(
                        'PROJE DOSYALARI & ŞARTNAME (İSTEĞE BAĞLI)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cyanLine,
                          letterSpacing: 0.5,
                        ),
                      ),
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
                                                  Text(
                                                    sizeStr,
                                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                                  ),
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

                      // 6. CANLI TEKLİF ÖZETİ KARTI
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
                                Text(
                                  'Adayın Ekranında Görünecek Teklif Özeti',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cyanLine,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• Model: ', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                                Expanded(
                                  child: Text(
                                    computeDurationString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Text('• Ücret: ', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                                Text(
                                  computeBudgetString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.amberSteel,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• Takvim: ', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                                Expanded(
                                  child: Text(
                                    computeDeadlineString(),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine),
                                  ),
                                ),
                              ],
                            ),
                            if (offerAttachments.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Text('• Ekler: ', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                                  Text(
                                    '${offerAttachments.length} adet dosya/şartname eklendi',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine),
                                  ),
                                ],
                              ),
                            ],
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
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.steelBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyanLine,
                        foregroundColor: AppTheme.blueprintDark,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('ŞİFRELE & GÖNDER', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final candidatePeerId = candidate['id'] as String;
                        final candidatePubKey = candidate['publicKey'] as String;

                        final formattedBudget = computeBudgetString();
                        final formattedDuration = computeDurationString();
                        final formattedDeadline = computeDeadlineString();

                        final hasPaidLicense = _companyLicense != null && !_companyLicense!.isExpired;
                        final isPro = hasPaidLicense && _companyLicense!.planId == 'pro_monthly';
                        final isVip = hasPaidLicense && (_companyLicense!.planId == 'yearly_corporate' || _companyLicense!.isUnlimited);
                        final isVerified = isPro || isVip;

                        final offer = OfferModel(
                          id: _uuid.v4(),
                          draftsmanId: candidatePeerId,
                          draftsmanName: candidate['name'] as String? ?? 'Teknik Ressam',
                          companyId: _companyProfile!.id,
                          companyName: _companyProfile!.name,
                          companyContact: '${_companyProfile!.email} / ${_companyProfile!.phone}',
                          companyEmail: _companyProfile!.email,
                          companyPhone: _companyProfile!.phone,
                          companyCity: _companyProfile!.city,
                          companyBio: _companyProfile!.bio,
                          companyWebsite: _companyProfile!.companyWebsite,
                          companyTaxNumber: _companyProfile!.taxNumber,
                          companyIsVerified: isVerified,
                          companyVerificationBadge: isVerified ? _companyLicense?.planName : null,
                          companyLogoBase64: _companyProfile!.avatarBase64,
                          companyIsVip: isVip,
                          companyTier: hasPaidLicense ? _companyLicense!.planName : 'Standart',
                          draftsmanTitle: candidate['title'] as String?,
                          draftsmanCity: candidate['city'] as String?,
                          projectTitle: titleController.text.trim(),
                          description: descController.text.trim(),
                          branch: candidate['branch'] as String? ?? _selectedBranch,
                          budget: formattedBudget,
                          projectDuration: formattedDuration,
                          deadline: formattedDeadline,
                          status: 'pending',
                          createdAt: DateTime.now(),
                          isEncrypted: true,
                          attachments: List.from(offerAttachments),
                        );

                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);

                        final success = await _p2pService.sendOfferToDraftsman(
                          offer: offer,
                          draftsmanPeerId: candidatePeerId,
                          draftsmanPublicKey: candidatePubKey,
                        );

                        if (success) {
                          await SubscriptionService().recordOfferSent();
                          _loadCompanyData();
                        }

                        nav.pop();

                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: success ? AppTheme.statusSuccess : AppTheme.statusDanger,
                            content: Text(
                              success
                                  ? 'Teklif başarıyla şifrelendi ve P2P kanalıyla adaya iletildi!'
                                  : 'Teklif gönderilirken hata oluştu.',
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

  Widget _buildCandidateSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.cyanLine),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const Divider(height: 14, thickness: 0.6),
          child,
        ],
      ),
    );
  }

  void _showAcceptedOfferDetailsDialog(OfferModel offer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.statusSuccess, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.statusSuccess, size: 22),
            SizedBox(width: 8),
            Text('Kabul Edilen Teklif', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(offer.projectTitle, style: const TextStyle(color: AppTheme.cyanLine, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Bütçe: ${offer.budget}', style: const TextStyle(color: AppTheme.textLight, fontSize: 12)),
            Text('Süre: ${offer.projectDuration}', style: const TextStyle(color: AppTheme.textLight, fontSize: 12)),
            if (offer.responseNote != null && offer.responseNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.steelBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ressamın Notu:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(offer.responseNote!, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  void _showPendingOfferDialog(OfferModel offer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.amberSteel, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top, color: AppTheme.amberSteel, size: 22),
            SizedBox(width: 8),
            Text('Teklif Yanıtı Bekleniyor', style: TextStyle(color: AppTheme.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(offer.projectTitle, style: const TextStyle(color: AppTheme.cyanLine, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
              'Teklifiniz teknik ressamın gelen kutusuna P2P ağı üzerinden iletildi. Ressam teklifi kabul ettiği anda telefon, e-posta, CV indirme ve LinkedIn profili açılacaktır.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCandidateDetail(Map<String, dynamic> candidate) async {
    final skills = List<String>.from(candidate['softwareSkills'] as List? ?? []);
    final portfolioMeta = (candidate['portfolioMeta'] as List? ?? []);
    final certificates = (candidate['certificates'] as List? ?? []);
    final isVerified = candidate['isVerified'] == true || candidate['diplomaBarcode'] != null;
    final badgeText = candidate['verificationBadge'] as String? ?? 'e-Devlet Onaylı Diploma';
    final hasCv = candidate['hasCv'] == true || (candidate['cvFileName'] != null && (candidate['cvFileName'] as String).isNotEmpty);
    final cvFileName = candidate['cvFileName'] as String? ?? 'Özgeçmiş (CV)';
    final cvFileSize = candidate['cvFileSize'] as int?;
    final cvBase64 = candidate['cvBase64'] as String?;

    final draftsmanId = candidate['id'] as String? ?? candidate['publicKey'] as String? ?? '';
    final draftsmanPubkey = candidate['publicKey'] as String? ?? '';

    // Check offer relationship between this company and this draftsman
    final companyId = _companyProfile?.id ?? '';
    final companyOffers = await _localDb.getOffers(forCompanyId: companyId);
    OfferModel? activeOffer;
    for (final o in companyOffers) {
      final matches = (draftsmanId.isNotEmpty && (o.draftsmanId == draftsmanId || o.draftsmanId.contains(draftsmanId) || draftsmanId.contains(o.draftsmanId))) ||
          (draftsmanPubkey.isNotEmpty && (o.draftsmanId == draftsmanPubkey || o.draftsmanId.contains(draftsmanPubkey)));
      if (matches) {
        activeOffer = o;
        break;
      }
    }
    final isOfferAccepted = activeOffer != null && (activeOffer.status == 'accepted' || activeOffer.status == 'completed');
    final isOfferPending = activeOffer != null && activeOffer.status == 'pending';
    final draftsmanPhone = activeOffer?.draftsmanPhone;
    final draftsmanEmail = activeOffer?.draftsmanEmail;

    ImageProvider? avatarImg;
    final avatarB64 = candidate['avatarBase64'] as String?;
    if (avatarB64 != null && avatarB64.isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(avatarB64));
      } catch (_) {}
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: AppTheme.blueprintDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppTheme.cyanLine, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cyanLine.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- KOMPAKT HERO VİTRİN KARTI ---
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.blueprintSurface,
                            AppTheme.cyanLine.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.cyanLine, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.cyanLine.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.blueprintDark,
                              backgroundImage: avatarImg,
                              child: avatarImg == null
                                  ? const Icon(Icons.person, color: AppTheme.cyanLine, size: 28)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate['name'] as String? ?? 'Teknik Ressam',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                ),
                                Text(
                                  candidate['title'] as String? ?? 'Teknik Ressam',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${candidate['branch']} • ${candidate['city']} • ${candidate['experienceYears']} Yıl Deneyim',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (isVerified)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.statusSuccess.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified, size: 10, color: AppTheme.statusSuccess),
                                            SizedBox(width: 3),
                                            Text('e-Devlet Onaylı', style: TextStyle(color: AppTheme.statusSuccess, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    if (hasCv)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.amberSteel.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.description, size: 10, color: AppTheme.amberSteel),
                                            SizedBox(width: 3),
                                            Text('CV Yüklü', style: TextStyle(color: AppTheme.amberSteel, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    // Offer status badge
                                    if (isOfferAccepted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.statusSuccess.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.6)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_open, size: 10, color: AppTheme.statusSuccess),
                                            SizedBox(width: 3),
                                            Text('Teklif Kabul Edildi', style: TextStyle(color: AppTheme.statusSuccess, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      )
                                    else if (isOfferPending)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.amberSteel.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.6)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.hourglass_empty, size: 10, color: AppTheme.amberSteel),
                                            SizedBox(width: 3),
                                            Text('Yanıt Bekleniyor', style: TextStyle(color: AppTheme.amberSteel, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cyanLine.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.4)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.visibility_outlined, size: 10, color: AppTheme.cyanLine),
                                            SizedBox(width: 3),
                                            Text('Vitrin Profili', style: TextStyle(color: AppTheme.cyanLine, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 1. UZMANLIK & HAKKINDA KARTI ---
                    _buildCandidateSectionCard(
                      title: 'Uzmanlık & Teknik Özet',
                      icon: Icons.engineering_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((candidate['bio'] as String? ?? '').trim().isNotEmpty) ...[
                            Text(
                              candidate['bio'] as String,
                              style: const TextStyle(color: AppTheme.textLight, fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                          ] else ...[
                            Text(
                              'Aday ${candidate['branch']} alanında ${candidate['experienceYears']} yıllık tecrübeye sahip teknik ressamdır.',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.blueprintDark,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.6)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Branş', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                      Text(candidate['branch'] as String? ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.blueprintDark,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.6)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Şehir / Konum', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                      Text(candidate['city'] as String? ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textLight), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.blueprintDark,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.6)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tecrübe', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                    Text('${candidate['experienceYears']} Yıl', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.amberSteel)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // --- 2. CAD & BIM YETKİNLİKLERİ ---
                    if (skills.isNotEmpty)
                      _buildCandidateSectionCard(
                        title: 'CAD & BIM Yetkinlikleri (${skills.length})',
                        icon: Icons.code,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: skills.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.blueprintDark,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textLight),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // --- 3. RESMİ DOĞRULAMA & ÖZGEÇMİŞ (CV) KARTI (GATED/KORUMALI) ---
                    _buildCandidateSectionCard(
                      title: 'Resmi Doğrulama & Özgeçmiş (CV)',
                      icon: Icons.verified_user_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // e-Devlet Mezuniyet Belgesi Bölümü
                          if (candidate['diplomaBarcode'] != null && (candidate['diplomaBarcode'] as String).isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.blueprintDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified, color: AppTheme.statusSuccess, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          badgeText,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.statusSuccess.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
                                        ),
                                        child: const Text('DOĞRULANDI', style: TextStyle(color: AppTheme.statusSuccess, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (isOfferAccepted) ...[
                                    // Teklif kabul edildiyse: Tam barkod ve sorgulama açık!
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.blueprintSurface,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.steelBorder),
                                            ),
                                            child: Text(
                                              'Barkod: ${candidate['diplomaBarcode']}',
                                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanLine),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.cyanLine,
                                            foregroundColor: AppTheme.blueprintDark,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => EDevletService.copyToClipboard(ctx, candidate['diplomaBarcode'] as String),
                                          child: const Text('Kopyala', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 4),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.cyanLine,
                                            side: const BorderSide(color: AppTheme.cyanLine),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => EDevletService.openOfficialVerificationPortal(ctx, barcode: candidate['diplomaBarcode'] as String),
                                          child: const Text('e-Devlet', style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    // Teklif henüz kabul edilmediyse: Maskeli görünüm ve kilit uyarısı
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.blueprintSurface,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
                                            ),
                                            child: Text(
                                              'Barkod: ${EDevletService.maskBarcode(candidate['diplomaBarcode'] as String)}',
                                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.cyanLine),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.blueprintSurface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_outline, size: 12, color: AppTheme.textMuted),
                                              SizedBox(width: 4),
                                              Text('Teyit Teklifte Açılır', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Özgeçmiş (CV) Bölümü
                          if (hasCv) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.blueprintDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppTheme.amberSteel.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.description, color: AppTheme.amberSteel, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cvFileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cvFileSize != null ? FileHelper.formatFileSize(cvFileSize) : 'Adayın Özgeçmiş Belgesi',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isOfferAccepted && cvBase64 != null && cvBase64.isNotEmpty) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.amberSteel,
                                        foregroundColor: AppTheme.blueprintDark,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.visibility, size: 13),
                                      label: const Text('CV Aç', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        try {
                                          final tempDir = await getTemporaryDirectory();
                                          final ext = cvFileName.contains('.') ? cvFileName.split('.').last : 'pdf';
                                          final tempFile = File('${tempDir.path}/candidate_cv_${DateTime.now().millisecondsSinceEpoch}.$ext');
                                          await tempFile.writeAsBytes(base64Decode(cvBase64));
                                          await FileLauncherService.openFile(tempFile.path);
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(backgroundColor: AppTheme.statusDanger, content: Text('CV açılamadı: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.blueprintSurface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_outline, size: 11, color: AppTheme.amberSteel),
                                          SizedBox(width: 4),
                                          Text('Teklif Kabulünde Açılır', style: TextStyle(fontSize: 10, color: AppTheme.amberSteel)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // --- 4. İLETİŞİM & SOSYAL BAĞLANTILAR (KORUMALI VİTRİN) ---
                    _buildCandidateSectionCard(
                      title: 'İletişim & Sosyal Profiller',
                      icon: Icons.contact_mail_outlined,
                      child: isOfferAccepted
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.statusSuccess.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.lock_open, color: AppTheme.statusSuccess, size: 14),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '✓ Teklif kabul edildi! Ressamın iletişim bilgileri açıldı.',
                                          style: TextStyle(color: AppTheme.statusSuccess, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (candidate['linkedinUrl'] != null && (candidate['linkedinUrl'] as String).isNotEmpty) ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF0077B5),
                                            side: const BorderSide(color: Color(0xFF0077B5)),
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.link, size: 14),
                                          label: const Text('LinkedIn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            final raw = candidate['linkedinUrl'] as String;
                                            final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
                                            if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (candidate['kariyerNetUrl'] != null && (candidate['kariyerNetUrl'] as String).isNotEmpty) ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF832161),
                                            side: const BorderSide(color: Color(0xFF832161)),
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.business_center, size: 14),
                                          label: const Text('Kariyer.net', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            final raw = candidate['kariyerNetUrl'] as String;
                                            final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
                                            if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if ((draftsmanPhone != null && draftsmanPhone.isNotEmpty) || (draftsmanEmail != null && draftsmanEmail.isNotEmpty)) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (draftsmanPhone != null && draftsmanPhone.isNotEmpty) ...[
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.cyanLine,
                                              side: const BorderSide(color: AppTheme.cyanLine),
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.phone, size: 14),
                                            label: Text(draftsmanPhone, style: const TextStyle(fontSize: 11)),
                                            onPressed: () {
                                              final uri = Uri.parse('tel:$draftsmanPhone');
                                              launchUrl(uri);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (draftsmanEmail != null && draftsmanEmail.isNotEmpty) ...[
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.cyanLine,
                                              side: const BorderSide(color: AppTheme.cyanLine),
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.email, size: 14),
                                            label: Text(draftsmanEmail, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                            onPressed: () {
                                              final uri = Uri.parse('mailto:$draftsmanEmail');
                                              launchUrl(uri);
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.blueprintDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.amberSteel.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.shield_outlined, color: AppTheme.amberSteel, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Gizlilik & İletişim Koruması',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.amberSteel),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Ressamın LinkedIn, Kariyer.net, telefon ve e-posta bağlantıları, iş teklifiniz ressam tarafından kabul edildiğinde otomatik açılır.',
                                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    // --- MESLEKİ SERTİFİKALAR (P2P META) ---
                    if (certificates.isNotEmpty)
                      _buildCandidateSectionCard(
                        title: 'Mesleki Sertifikalar & Uzmanlıklar (${certificates.length})',
                        icon: Icons.workspace_premium,
                        child: Column(
                          children: certificates.map((cert) {
                            final c = Map<String, dynamic>.from(cert as Map);
                            final title = c['title'] as String? ?? 'Sertifika';
                            final issuer = c['issuer'] as String? ?? '';
                            final year = c['issueYear'] as String? ?? '';
                            final credId = c['credentialId'] as String?;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.blueprintDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.amberSteel.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.military_tech, color: AppTheme.amberSteel, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$issuer${year.isNotEmpty ? ' • $year' : ''}',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.cyanLine),
                                        ),
                                        if (credId != null && credId.isNotEmpty)
                                          Text(
                                            'Sertifika No: $credId',
                                            style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontFamily: 'monospace'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // --- 5. PORTFÖY ÇİZİMLERİ (P2P META) ---
                    _buildCandidateSectionCard(
                      title: 'Portföy Çizimleri (${portfolioMeta.length})',
                      icon: Icons.folder_open,
                      child: portfolioMeta.isEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              child: const Text(
                                'Adayın henüz yüklü çizim portföyü bulunmuyor.',
                                style: TextStyle(color: AppTheme.textSubtle, fontSize: 11),
                              ),
                            )
                          : Column(
                              children: portfolioMeta.map((pm) {
                                final m = Map<String, dynamic>.from(pm as Map);
                                return CandidatePortfolioFileTile(
                                  fileMeta: m,
                                  draftsmanPeerId: candidate['id'] as String? ?? candidate['publicKey'] as String? ?? '',
                                  draftsmanPublicKey: candidate['publicKey'] as String? ?? candidate['id'] as String? ?? '',
                                  p2pService: _p2pService,
                                );
                              }).toList(),
                            ),
                    ),

                    const SizedBox(height: 12),

                    // --- BUTONLAR ---
                    if (isOfferAccepted) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.statusSuccess,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('KABUL EDİLEN TEKLİF DETAYLARI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showAcceptedOfferDetailsDialog(activeOffer!);
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cyanLine,
                            side: const BorderSide(color: AppTheme.cyanLine),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.send, size: 14),
                          label: const Text('Yeni Bir İş Teklifi Daha Gönder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showOfferDialog(candidate);
                          },
                        ),
                      ),
                    ] else if (isOfferPending) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.amberSteel,
                            foregroundColor: AppTheme.blueprintDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.hourglass_top, size: 18),
                          label: const Text('TEKLİF YANITI BEKLENİYOR...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showPendingOfferDialog(activeOffer!);
                          },
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cyanLine,
                            foregroundColor: AppTheme.blueprintDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text('İŞ TEKLİFİ GÖNDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showOfferDialog(candidate);
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.statusDanger,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.block, size: 14),
                        label: const Text('Bu Adayı Engelle / Yoksay', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _confirmBlockCandidate(candidate);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlueprintHeader(
        title: 'Aday Teknik Ressamlar (P2P)',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<String>(
              stream: _p2pService.connectionStatusStream,
              initialData: _p2pService.connectionStatus,
              builder: (context, snapshot) {
                final isConnected = _p2pService.isConnected;
                final status = isConnected ? _p2pService.connectionStatus : (snapshot.data ?? 'Bağlanılıyor...');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppTheme.statusSuccess.withValues(alpha: 0.15)
                        : AppTheme.amberSteel.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isConnected ? AppTheme.statusSuccess : AppTheme.amberSteel,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.sync,
                        size: 14,
                        color: isConnected ? AppTheme.statusSuccess : AppTheme.amberSteel,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          color: isConnected ? AppTheme.statusSuccess : AppTheme.amberSteel,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.cyanLine),
              tooltip: 'Ağı Tara & Yenile',
              onPressed: () {
                _p2pService.scanNetwork();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ağ taranıyor...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.shield_outlined, color: AppTheme.cyanLine),
              tooltip: 'Engellenen Adaylar',
              onPressed: () => BlockedUsersDialog.showModal(
                context,
                isCompany: true,
                onUnblocked: () => _loadCompanyData(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.statusDanger),
              tooltip: 'Ağdaki Listeyi Sıfırla (Temizle)',
              onPressed: () async {
                await _p2pService.clearDeletedCandidates();
                _p2pService.clearDiscoveredDraftsmen();
                await _p2pService.scanNetwork();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.statusSuccess,
                      content: Text('Aday listesi ve engellemeler temizlendi, ağ taranıyor.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.workspace_premium, color: AppTheme.amberSteel),
              tooltip: 'Kurumsal Abonelik',
              onPressed: () => SubscriptionModal.show(context),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_companyLicense != null && _companyLicense!.isExpiringSoon)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.amberSteel.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.amberSteel),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.amberSteel, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Teklif hakkınız veya paket süreniz dolmak üzere! (${_companyLicense!.remainingOffersText})',
                      style: const TextStyle(color: AppTheme.textLight, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => SubscriptionPaywallDialog.show(
                      context,
                      _companyProfile!,
                      () => _loadCompanyData(),
                    ),
                    child: const Text('YENİLE', style: TextStyle(color: AppTheme.amberSteel, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.blueprintSurface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'İsim, CAD yazılımı veya şehir ara...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.cyanLine),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.textSubtle),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: branchFilters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final b = branchFilters[i];
                      final isSelected = _selectedBranch == b;
                      return ChoiceChip(
                        label: Text(b),
                        selected: isSelected,
                        selectedColor: AppTheme.cyanLine,
                        backgroundColor: AppTheme.blueprintDark,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppTheme.blueprintDark : AppTheme.textMuted,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppTheme.cyanLine : AppTheme.steelBorder,
                        ),
                        onSelected: (_) => _onBranchSelected(b),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _p2pService.discoveredDraftsmenStream,
              initialData: _p2pService.discoveredDraftsmen,
              builder: (context, snapshot) {
                final allDraftsmen = snapshot.data ?? _p2pService.discoveredDraftsmen;

                final filtered = allDraftsmen.where((c) {
                  final candidateId = c['id'] as String? ?? c['publicKey'] as String? ?? '';
                  final pubKey = c['publicKey'] as String? ?? '';
                  if (_blockedUserIds.contains(candidateId) || _blockedUserIds.contains(pubKey)) {
                    return false;
                  }

                  final name = (c['name'] as String? ?? '').trim();
                  final lowerName = name.toLowerCase();
                  if (name.isEmpty || lowerName == 'null' || lowerName == 'dummy') {
                    return false;
                  }
                  final branch = (c['branch'] as String? ?? '').trim();
                  if (branch.isEmpty || branch.toLowerCase() == 'null') {
                    return false;
                  }

                  final branchMatch = _selectedBranch == 'Tümü' || c['branch'] == _selectedBranch;
                  if (!branchMatch) return false;

                  if (_searchQuery.isEmpty) return true;
                  final city = (c['city'] as String? ?? '').toLowerCase();
                  final skills = (c['softwareSkills'] as List? ?? [])
                      .map((e) => e.toString().toLowerCase())
                      .join(' ');
                  return lowerName.contains(_searchQuery) || city.contains(_searchQuery) || skills.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  final isConn = _p2pService.isConnected;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isConn ? AppTheme.statusSuccess : AppTheme.amberSteel).withValues(alpha: 0.1),
                              border: Border.all(
                                color: (isConn ? AppTheme.statusSuccess : AppTheme.amberSteel).withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isConn ? Icons.hub_rounded : Icons.cloud_sync_outlined,
                              size: 48,
                              color: isConn ? AppTheme.statusSuccess : AppTheme.amberSteel,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isConn
                                ? 'ŞİRKET AĞA BAĞLI • ÇEVRİMİÇİ'
                                : 'AĞA BAĞLANILIYOR...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isConn ? AppTheme.statusSuccess : AppTheme.amberSteel,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _p2pService.connectedRelayUrls.map((url) {
                              final shortName = url.replaceAll('wss://', '');
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.blueprintDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, color: AppTheme.statusSuccess, size: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      shortName,
                                      style: const TextStyle(color: AppTheme.textLight, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cyanLine,
                              foregroundColor: AppTheme.blueprintDark,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Ağı Şimdi Tara & Yenile', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await _p2pService.clearDeletedCandidates();
                              await _p2pService.scanNetwork();
                              messenger.showSnackBar(
                                const SnackBar(
                                  duration: Duration(seconds: 1),
                                  content: Text('Nostr röleleri ve yerel ağ yeniden tarandı.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final candidate = filtered[i];
                    return _buildCandidateCard(candidate);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> candidate) {
    final skills = List<String>.from(candidate['softwareSkills'] as List? ?? []);
    final portfolioCount = candidate['portfolioCount'] as int? ?? 0;
    final isVerified = candidate['isVerified'] == true || candidate['diplomaBarcode'] != null;
    final badgeText = candidate['verificationBadge'] as String? ?? 'e-Devlet Onaylı Diploma';

    ImageProvider? avatarImg;
    final avatarB64 = candidate['avatarBase64'] as String?;
    if (avatarB64 != null && avatarB64.isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(avatarB64));
      } catch (_) {}
    }

    final certs = candidate['certificates'] as List? ?? [];
    final certCount = certs.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.blueprintCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVerified ? AppTheme.cyanLine.withValues(alpha: 0.5) : AppTheme.steelBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.cyanLine.withValues(alpha: 0.15),
                backgroundImage: avatarImg,
                child: avatarImg == null
                    ? const Icon(Icons.engineering_outlined, color: AppTheme.cyanLine, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            candidate['name'] as String? ?? 'İsimsiz Ressam',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppTheme.cyanLine, size: 16),
                        ],
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.statusSuccess,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      candidate['title'] as String? ?? 'Teknik Ressam',
                      style: const TextStyle(fontSize: 13, color: AppTheme.cyanLine, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${candidate['branch']} • ${candidate['city']} • ${candidate['experienceYears']} Yıl Tecrübe',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    if (isVerified || candidate['hasCv'] == true || candidate['cvFileName'] != null || certCount > 0) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.cyanLine.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 10, color: AppTheme.cyanLine),
                                  const SizedBox(width: 3),
                                  Text(
                                    badgeText,
                                    style: const TextStyle(color: AppTheme.cyanLine, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          if (candidate['hasCv'] == true || candidate['cvFileName'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.amberSteel.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.description, size: 10, color: AppTheme.amberSteel),
                                  SizedBox(width: 3),
                                  Text(
                                    'CV',
                                    style: TextStyle(color: AppTheme.amberSteel, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          if (certCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.workspace_premium_outlined, size: 10, color: Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$certCount Sertifika',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (skills.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: skills.take(4).map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.steelBorder),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              if (portfolioCount > 0) ...[
                const Icon(Icons.attachment, size: 14, color: AppTheme.amberSteel),
                const SizedBox(width: 4),
                Text(
                  '$portfolioCount Çizim Dosyası',
                  style: const TextStyle(fontSize: 12, color: AppTheme.amberSteel),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.statusDanger, size: 18),
                tooltip: 'Adayı Listeden Kaldır',
                onPressed: () async {
                  final peerId = candidate['id'] as String? ?? candidate['publicKey'] as String? ?? '';
                  if (peerId.isNotEmpty) {
                    final isAdmin = _companyProfile != null &&
                        (_companyProfile!.name.trim().toLowerCase().contains('ko|apps') ||
                            _companyProfile!.name.trim().toLowerCase().contains('ko apps'));
                    if (isAdmin) {
                      await _p2pService.broadcastModerationDelete(peerId);
                    } else {
                      await _p2pService.deleteCandidate(peerId);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.statusSuccess,
                          content: Text('${candidate['name']} kalıcı olarak listeden silindi.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: 4),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: AppTheme.steelBorder),
                ),
                onPressed: () => _showCandidateDetail(candidate),
                child: const Text('İncele', style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyanLine,
                  foregroundColor: AppTheme.blueprintDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Teklif Ver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showOfferDialog(candidate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CandidatePortfolioFileTile extends StatefulWidget {
  final Map<String, dynamic> fileMeta;
  final String draftsmanPeerId;
  final String? draftsmanPublicKey;
  final P2PService p2pService;

  const CandidatePortfolioFileTile({
    super.key,
    required this.fileMeta,
    required this.draftsmanPeerId,
    this.draftsmanPublicKey,
    required this.p2pService,
  });

  @override
  State<CandidatePortfolioFileTile> createState() => _CandidatePortfolioFileTileState();
}

class _CandidatePortfolioFileTileState extends State<CandidatePortfolioFileTile> {
  bool _isDownloading = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _checkLocalFile();
  }

  Future<void> _checkLocalFile() async {
    final fileId = widget.fileMeta['id'] as String? ?? '';
    final fileName = widget.fileMeta['fileName'] as String? ?? '';
    var path = await widget.p2pService.getDownloadedFilePath(fileId, fileName);

    // Auto unpack if base64 is already embedded
    if (path == null && widget.fileMeta['base64'] != null) {
      try {
        final bytes = base64Decode(widget.fileMeta['base64'] as String);
        final appDocDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${appDocDir.path}/p2p_downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final savePath = '${downloadsDir.path}/${fileId}_$fileName';
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        path = savePath;
      } catch (e) {
        debugPrint('Auto unpack base64 drawing error: $e');
      }
    }

    if (mounted && path != null) {
      setState(() => _localPath = path);
    }
  }

  Future<void> _handleFileAction() async {
    if (_localPath != null && File(_localPath!).existsSync()) {
      final ok = await FileLauncherService.openFile(_localPath!);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Dosya açılamadı veya cihazda uygun CAD/PDF görüntüleyici bulunamadı.'),
          ),
        );
      }
      return;
    }

    final fileId = widget.fileMeta['id'] as String? ?? '';
    final fileName = widget.fileMeta['fileName'] as String? ?? 'cizim';

    // Direct Instant Unpack if file was embedded in Nostr profile metadata
    final base64Content = widget.fileMeta['base64'] as String?;
    if (base64Content != null && base64Content.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Content);
        final appDocDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${appDocDir.path}/p2p_downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final savePath = '${downloadsDir.path}/${fileId}_$fileName';
        final file = File(savePath);
        await file.writeAsBytes(bytes);

        if (mounted) {
          setState(() => _localPath = savePath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.statusSuccess,
              content: Text('$fileName açılıyor...'),
            ),
          );
          await FileLauncherService.openFile(savePath);
        }
        return;
      } catch (e) {
        debugPrint('Direct base64 decode error: $e');
      }
    }

    setState(() => _isDownloading = true);

    try {
      final downloadedPath = await widget.p2pService.downloadPortfolioFile(
        draftsmanPeerId: widget.draftsmanPeerId,
        draftsmanPublicKey: widget.draftsmanPublicKey,
        fileId: fileId,
        fileName: fileName,
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _localPath = downloadedPath;
        });

        if (downloadedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.statusSuccess,
              content: Text('$fileName başarıyla aktarıldı. Açılıyor...'),
            ),
          );
          await FileLauncherService.openFile(downloadedPath);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.statusDanger,
              content: Text('Dosya indirilemedi. Aday çevrimdışı olabilir veya transfer zaman aşımına uğradı.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Transfer hatası: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.fileMeta['fileName'] as String? ?? 'Çizim Dosyası';
    final ext = (widget.fileMeta['extension'] as String? ?? 'DWG').toLowerCase();
    final size = widget.fileMeta['size'] as int? ?? 0;
    final sizeStr = size > 0 ? FileHelper.formatFileSize(size) : '';
    final isDownloaded = _localPath != null;
    final formattedName = FileHelper.formatFileName(fileName, maxLength: 26);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDownloaded ? AppTheme.statusSuccess.withValues(alpha: 0.6) : AppTheme.steelBorder,
        ),
      ),
      child: Row(
        children: [
          FileHelper.buildFileIconBadge(ext, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: fileName,
                  child: Text(
                    formattedName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                if (sizeStr.isNotEmpty)
                  Text(
                    '$sizeStr ${isDownloaded ? '• Cihaza İndirildi' : '• P2P Hazır'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDownloaded ? AppTheme.statusSuccess : AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_isDownloading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanLine),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDownloaded ? AppTheme.statusSuccess : AppTheme.cyanLine,
                foregroundColor: AppTheme.blueprintDark,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(isDownloaded ? Icons.open_in_new : Icons.download, size: 14),
              label: Text(
                isDownloaded ? 'AÇ' : 'İNDİR & AÇ',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: _handleFileAction,
            ),
        ],
      ),
    );
  }
}
