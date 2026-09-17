import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/p2p_service.dart';
import '../../core/services/edevlet_service.dart';
import '../../core/services/file_launcher_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blueprint_header.dart';
import '../../core/widgets/subscription_modal.dart';

class CompanyProfileView extends StatefulWidget {
  final VoidCallback? onProfileSaved;

  const CompanyProfileView({super.key, this.onProfileSaved});

  @override
  State<CompanyProfileView> createState() => _CompanyProfileViewState();
}

class _CompanyProfileViewState extends State<CompanyProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _localDb = LocalDbService();
  final _authService = AuthService();
  final _p2pService = P2PService();

  UserProfile? _companyProfile;
  CompanyLicense? _activeLicense;
  bool _isLoading = true;

  String _selectedBranch = 'Çelik Yapı & Konstrüksiyon';
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _websiteController = TextEditingController();

  String? _avatarPath;
  String? _avatarBase64;
  bool _isVerified = false;
  String? _verificationBadge;
  bool _isExtractingTaxPlate = false;
  String? _taxPlateFileName;
  String? _taxPlateFilePath;
  String? _taxPlateBarcode;
  bool _isBarcodeMaskedVisible = false;

  static const List<String> industryBranches = [
    'Çelik Yapı & Konstrüksiyon',
    'Betonarme & Statik',
    'Harita & Altyapı',
    'Mekanik & Tesisat & HVAC',
    'Elektrik & Otomasyon',
    'Mimari & Cephe Çizimi',
    'Makine & Endüstriyel İmalat',
    'Genel Mühendislik & Müşavirlik',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _taxNumberController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _localDb.getUserProfile();
    final license = await SubscriptionService().getActiveLicense();
    _activeLicense = license;

    if (profile != null) {
      _companyProfile = profile;
      _selectedBranch = industryBranches.contains(profile.branch)
          ? profile.branch
          : industryBranches.first;
      _nameController.text = profile.name;
      _contactPersonController.text = profile.title;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _cityController.text = profile.city;
      _bioController.text = profile.bio;
      _taxNumberController.text = profile.taxNumber ?? '';
      _taxPlateBarcode = profile.diplomaBarcode ?? profile.taxNumber;
      _websiteController.text = profile.companyWebsite ?? '';
      _avatarPath = profile.avatarPath;
      _avatarBase64 = profile.avatarBase64;
      final hasPaidLicense = license != null && !license.isExpired;
      _isVerified = hasPaidLicense;
      _verificationBadge = hasPaidLicense ? license.planName : null;
    } else {
      _nameController.clear();
      _contactPersonController.clear();
      _emailController.clear();
      _phoneController.clear();
      _cityController.clear();
      _bioController.clear();
      _taxNumberController.clear();
      _websiteController.clear();
      _avatarPath = null;
      _avatarBase64 = null;
      _isVerified = false;
      _verificationBadge = null;
      _taxPlateBarcode = null;
      _taxPlateFileName = null;
      _taxPlateFilePath = null;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<String> _compressAvatarBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 160);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('Company logo compression error: $e');
    }
    if (bytes.length <= 60 * 1024) {
      return base64Encode(bytes);
    }
    return '';
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isNotEmpty && result.first.path != null) {
        final originalFile = File(result.first.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final ext = result.first.extension ?? 'jpg';
        final targetPath = '${appDir.path}/company_logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await originalFile.copy(targetPath);

        final bytes = await originalFile.readAsBytes();
        final base64Img = await _compressAvatarBytes(bytes);

        setState(() {
          _avatarPath = targetPath;
          _avatarBase64 = base64Img;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.statusSuccess,
              content: Text('Şirket logosu başarıyla güncellendi.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Company logo pick error: $e');
    }
  }

  Future<void> _pickTaxPlatePdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) return;
      final picked = result.first;

      setState(() => _isExtractingTaxPlate = true);

      final originalFile = File(picked.path!);
      final bytes = await originalFile.readAsBytes();

      final appDir = await getApplicationDocumentsDirectory();
      final targetPath = '${appDir.path}/tax_plate_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await originalFile.copy(targetPath);

      final extraction = await EDevletService.extractFromPdfBytes(bytes);

      if (extraction.success && extraction.barcode != null && extraction.barcode!.isNotEmpty) {
        setState(() {
          if (extraction.taxNumber != null && extraction.taxNumber!.isNotEmpty) {
            _taxNumberController.text = extraction.taxNumber!;
          }
          _taxPlateBarcode = extraction.barcode!;
          _taxPlateFileName = picked.name;
          _taxPlateFilePath = targetPath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.statusSuccess,
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✓ Vergi Levhası ve Barkod No belgeden otomatik çıkarıldı: ${EDevletService.maskBarcode(extraction.barcode!)}',
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          _showManualTaxPlateDialog(
            pdfPath: targetPath,
            pdfName: picked.name,
            fileSize: bytes.length,
            reason: extraction.errorMessage,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Belge yükleme hatası: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtractingTaxPlate = false);
      }
    }
  }

  void _showManualTaxPlateDialog({
    required String pdfPath,
    required String pdfName,
    required int fileSize,
    String? reason,
  }) {
    final vknController = TextEditingController(text: _taxNumberController.text);
    final barcodeController = TextEditingController(text: _taxPlateBarcode ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: AppTheme.cyanLine),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vergi Levhası Bilgilerini Girin',
                style: TextStyle(fontSize: 15, color: AppTheme.textLight, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason ?? 'PDF dosyasından bilgiler otomatik okunamadı (Taranmış resim olabilir).',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vknController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              style: const TextStyle(color: AppTheme.textLight),
              decoration: const InputDecoration(
                labelText: 'Vergi Kimlik No (VKN)',
                hintText: '10 Haneli VKN',
                counterText: '',
                prefixIcon: Icon(Icons.pin, color: AppTheme.cyanLine, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: barcodeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5, color: AppTheme.textLight),
              decoration: const InputDecoration(
                labelText: 'Belge Barkod / Doğrulama No',
                hintText: 'Örn: B2886F454378A2...',
                prefixIcon: Icon(Icons.qr_code, color: AppTheme.cyanLine, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyanLine,
              foregroundColor: AppTheme.blueprintDark,
            ),
            child: const Text('Kaydet ve Onayla'),
            onPressed: () {
              final vkn = vknController.text.trim();
              final barcode = barcodeController.text.trim().toUpperCase();
              if (vkn.length != 10 && barcode.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.statusDanger,
                    content: Text('Lütfen geçerli 10 haneli VKN veya Barkod Numarası girin.'),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              setState(() {
                _taxNumberController.text = vkn;
                _taxPlateBarcode = barcode.isNotEmpty ? barcode : vkn;
                _taxPlateFileName = pdfName;
                _taxPlateFilePath = pdfPath;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.statusSuccess,
                  content: Text('✓ Vergi levhası kaydedildi: ${EDevletService.maskBarcode(_taxPlateBarcode!)}'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _removeTaxPlate() {
    setState(() {
      _taxNumberController.clear();
      _taxPlateBarcode = null;
      _taxPlateFileName = null;
      _taxPlateFilePath = null;
      _isBarcodeMaskedVisible = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.blueprintSurface,
        content: Text('Vergi levhası kaldırıldı.'),
      ),
    );
  }

  Future<void> _openTaxPlatePdf() async {
    if (_taxPlateFilePath != null && File(_taxPlateFilePath!).existsSync()) {
      await FileLauncherService.openFile(_taxPlateFilePath!);
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusDanger,
          content: Text('Vergi levhası PDF belgesi cihazda bulunamadı.'),
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusDanger,
          content: Text('Lütfen zorunlu alanları doldurunuz.'),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    if (_companyProfile == null) {
      final authRes = await _authService.signInWithLocalDID(
        name: _nameController.text.trim(),
        role: 'company',
        branch: _selectedBranch,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
      );

      if (authRes.isSuccess && authRes.profile != null) {
        _companyProfile = authRes.profile;
      }
    }

    if (_companyProfile != null) {
      final updated = _companyProfile!.copyWith(
        name: _nameController.text.trim(),
        role: 'company',
        branch: _selectedBranch,
        title: _contactPersonController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        bio: _bioController.text.trim(),
        avatarPath: _avatarPath,
        avatarBase64: _avatarBase64,
        isVerified: _isVerified,
        verificationBadge: _verificationBadge,
        taxNumber: _taxNumberController.text.trim(),
        diplomaBarcode: _taxPlateBarcode ?? _companyProfile?.diplomaBarcode,
        companyWebsite: _websiteController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await _localDb.saveUserProfile(updated);
      _companyProfile = updated;

      await _p2pService.start(userProfile: updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('✓ Şirket profiliniz kaydedildi ve P2P ağına bağlandı.'),
          ),
        );
        widget.onProfileSaved?.call();
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        title: const Text('Hesaptan Çıkış Yap', style: TextStyle(color: AppTheme.textLight)),
        content: const Text(
          'Şirket hesabınızdan çıkış yapmak istediğinize emin misiniz? Şirket bilgileriniz cihazda korunacak ancak oturum sonlandırılacaktır.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amberSteel,
              foregroundColor: AppTheme.blueprintDark,
            ),
            child: const Text('Çıkış Yap'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _p2pService.dispose();
      await _localDb.setLoggedIn(false);
      widget.onProfileSaved?.call();
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        title: const Text('Şirket Profilini ve Verileri Sil', style: TextStyle(color: AppTheme.statusDanger)),
        content: const Text(
          'DİKKAT: Şirket profiliniz, kimlik anahtarlarınız ve gönderilen tüm iş teklifleri bu cihazdan kalıcı olarak silinecektir.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kalıcı Olarak Sil'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _p2pService.dispose();
      await _localDb.deleteUserProfile();
      await _localDb.clearAllOffers();
      widget.onProfileSaved?.call();
    }
  }

  void _showSecretKeyDialog() {
    final privKey = _companyProfile?.privateKey ?? '';
    if (privKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kurtarma anahtarı henüz oluşturulmadı. Önce profili kaydedin.')),
      );
      return;
    }

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
            Icon(Icons.vpn_key_rounded, color: AppTheme.amberSteel),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Şirket Gizli Kurtarma Anahtarı',
                style: TextStyle(color: AppTheme.textLight, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Bu anahtar şirket hesabınızın sahipliğini kanıtlayan tek şifredir!\n\nUygulamayı silseniz veya cihaz değiştirseniz dahi, bu 64 haneli anahtarı yapıştırarak şirket profilinizi ve lisansınızı geri yükleyebilirsiniz.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.blueprintSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.5)),
              ),
              child: SelectableText(
                privKey,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.amberSteel),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amberSteel,
              foregroundColor: AppTheme.blueprintDark,
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Anahtarı Kopyala', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: privKey));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppTheme.statusSuccess,
                  content: Text('✓ Şirket kurtarma anahtarı panoya kopyalandı.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreAccountDialog() {
    final keyController = TextEditingController();
    bool isRestoring = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.blueprintDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.amberSteel, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore, color: AppTheme.amberSteel),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Şirket Hesabını Geri Yükle',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daha önce yedeklediğiniz 64 haneli Şirket Kurtarma Anahtarınızı (Private Key) aşağıya yapıştırın:',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyController,
                maxLines: 2,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.amberSteel),
                decoration: const InputDecoration(
                  hintText: '64 karakterli hex anahtar...',
                  labelText: 'Şirket Kurtarma Anahtarı',
                  prefixIcon: Icon(Icons.key, color: AppTheme.amberSteel),
                ),
              ),
              if (isRestoring) ...[
                const SizedBox(height: 14),
                const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.amberSteel)),
                      SizedBox(width: 8),
                      Text('Nostr ağından şirket profili aranıyor...', style: TextStyle(fontSize: 12, color: AppTheme.amberSteel)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amberSteel,
                foregroundColor: AppTheme.blueprintDark,
              ),
              onPressed: isRestoring
                  ? null
                  : () async {
                      final input = keyController.text.trim();
                      if (input.isEmpty) return;
                      setDialogState(() => isRestoring = true);

                      final res = await _authService.restoreWithPrivateKey(
                        privateKey: input,
                        role: 'company',
                      );

                      if (!ctx.mounted || !mounted) return;
                      Navigator.of(ctx).pop();

                      if (res.isSuccess && res.profile != null) {
                        final lic = await SubscriptionService().restoreLicenseFromNostr(res.profile!);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.statusSuccess,
                            content: Text(
                              lic != null
                                  ? '✓ Hoş geldiniz! ${res.profile!.name} şirketi ve lisansı geri yüklendi.'
                                  : '✓ Hoş geldiniz! ${res.profile!.name} şirketi geri yüklendi.',
                            ),
                          ),
                        );
                        await _loadProfile();
                        await _p2pService.start(userProfile: res.profile!);
                        widget.onProfileSaved?.call();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.statusDanger,
                            content: Text(res.errorMessage ?? 'Geri yükleme başarısız.'),
                          ),
                        );
                      }
                    },
              child: const Text('GERİ YÜKLE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Icon(icon, size: 16, color: AppTheme.amberSteel),
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

  Widget _buildCompactHeroHeader() {
    ImageProvider? imageProvider;
    if (_avatarPath != null && File(_avatarPath!).existsSync()) {
      imageProvider = FileImage(File(_avatarPath!));
    } else if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(_avatarBase64!));
      } catch (_) {}
    }

    final displayName = _nameController.text.trim().isEmpty ? 'Şirket Ünvanı' : _nameController.text.trim();
    final displayContact = _contactPersonController.text.trim().isEmpty ? 'Yetkili Belirtilmedi' : _contactPersonController.text.trim();
    final hasTaxPlate = (_taxPlateBarcode != null && _taxPlateBarcode!.isNotEmpty) || _taxNumberController.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.blueprintSurface,
            AppTheme.amberSteel.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.amberSteel, width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.blueprintDark,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(Icons.business, size: 30, color: AppTheme.amberSteel)
                      : null,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: InkWell(
                  onTap: _pickAvatar,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.amberSteel,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.blueprintDark, width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt, size: 13, color: AppTheme.blueprintDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                ),
                Text(
                  displayContact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.amberSteel),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.amberSteel.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 11, color: AppTheme.amberSteel),
                            const SizedBox(width: 3),
                            Text(
                              _verificationBadge ?? 'VIP Kurumsal',
                              style: const TextStyle(color: AppTheme.amberSteel, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    if (hasTaxPlate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cyanLine.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long, size: 11, color: AppTheme.cyanLine),
                            SizedBox(width: 3),
                            Text(
                              'Vergi Levhası Onaylı',
                              style: TextStyle(color: AppTheme.cyanLine, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.blueprintDark,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.steelBorder),
                      ),
                      child: Text(
                        _selectedBranch,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.vpn_key_outlined, size: 20, color: AppTheme.amberSteel),
                tooltip: 'Şirket DID Kurtarma Anahtarı',
                visualDensity: VisualDensity.compact,
                onPressed: _showSecretKeyDialog,
              ),
              IconButton(
                icon: const Icon(Icons.settings_backup_restore, size: 20, color: AppTheme.cyanLine),
                tooltip: 'Şirket Hesabını Geri Yükle',
                visualDensity: VisualDensity.compact,
                onPressed: _showRestoreAccountDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoCard() {
    return _buildSectionCard(
      title: 'Şirket & Faaliyet Bilgileri',
      icon: Icons.business_outlined,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Şirket Resmi Ünvanı',
              prefixIcon: Icon(Icons.business, color: AppTheme.amberSteel, size: 18),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Şirket adı zorunludur' : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedBranch,
            dropdownColor: AppTheme.blueprintSurface,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Faaliyet Alanı / Sektör',
              prefixIcon: Icon(Icons.category_outlined, color: AppTheme.amberSteel, size: 18),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: industryBranches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedBranch = v);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Şehir',
                    prefixIcon: Icon(Icons.location_city, color: AppTheme.amberSteel, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Şehir zorunludur' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _websiteController,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Web Sitesi',
                    hintText: 'www.sirket.com',
                    prefixIcon: Icon(Icons.language, color: AppTheme.amberSteel, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _bioController,
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Şirket Tanıtımı / Hakkımızda',
              hintText: 'Projeleriniz, tecrübeleriniz ve çalışma alanlarınız hakkında kısa bilgi...',
              prefixIcon: Icon(Icons.notes, color: AppTheme.amberSteel, size: 18),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return _buildSectionCard(
      title: 'Yetkili & İletişim Bilgileri',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          TextFormField(
            controller: _contactPersonController,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Yetkili İsim / Pozisyon',
              hintText: 'Örn: Mehmet Öz - Proje Müdürü',
              prefixIcon: Icon(Icons.person_pin, color: AppTheme.amberSteel, size: 18),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Yetkili bilgisi zorunludur' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'İletişim Telefonu',
                    hintText: '05XX XXX XX XX',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.amberSteel, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Telefon zorunludur' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Kurumsal E-Posta',
                    hintText: 'info@sirket.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.amberSteel, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (v) => v == null || !v.contains('@') ? 'Geçerli e-posta girin' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxPlateCard() {
    final hasTaxPlate = (_taxPlateBarcode != null && _taxPlateBarcode!.isNotEmpty) ||
        _taxNumberController.text.trim().isNotEmpty;
    final displayBarcode = (_taxPlateBarcode != null && _taxPlateBarcode!.isNotEmpty)
        ? _taxPlateBarcode!
        : _taxNumberController.text.trim();

    return _buildSectionCard(
      title: 'e-Devlet / GİB Barkodlu Vergi Levhası',
      icon: Icons.receipt_long_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: hasTaxPlate
              ? AppTheme.statusSuccess.withValues(alpha: 0.15)
              : AppTheme.steelBorder.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: hasTaxPlate ? AppTheme.statusSuccess.withValues(alpha: 0.6) : AppTheme.steelBorder,
          ),
        ),
        child: Text(
          hasTaxPlate ? '✓ BELGE EKLENDİ' : 'BELGE BEKLENİYOR',
          style: TextStyle(
            color: hasTaxPlate ? AppTheme.statusSuccess : AppTheme.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasTaxPlate) ...[
            const Text(
              'e-Devlet veya GİB portalından indirdiğiniz resmi Barkodlu Vergi Levhanızı (PDF) yükleyin. VKN ve Belge Barkod No otomatik ayıklanır, şifrelenir ve adaylara resmi onay rozeti olarak sunulur.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.35),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cyanLine,
                      foregroundColor: AppTheme.blueprintDark,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: _isExtractingTaxPlate
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blueprintDark),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(
                      _isExtractingTaxPlate ? 'Bilgiler Taranıyor...' : 'Barkodlu Vergi Levhası Seç (PDF)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: _isExtractingTaxPlate ? null : _pickTaxPlatePdf,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showManualTaxPlateDialog(
                    pdfPath: '',
                    pdfName: 'Vergi Levhası',
                    fileSize: 0,
                    reason: 'Vergi numaranızı ve barkodunuzu vergi levhanıza bakarak elle girebilirsiniz.',
                  ),
                  child: const Text('Elle Gir', style: TextStyle(fontSize: 11, color: AppTheme.cyanLine)),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.verified, size: 14, color: AppTheme.cyanLine),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _taxPlateFileName ?? 'GİB Barkodlu Vergi Levhası',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.cyanLine),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_taxNumberController.text.isNotEmpty)
                  Text(
                    'VKN: ${_taxNumberController.text}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.blueprintDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppTheme.cyanLine, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VERGİ LEVHASI BARKOD NO (GÜVENLİ MASKE):',
                          style: TextStyle(fontSize: 8.5, color: AppTheme.textMuted, letterSpacing: 0.5),
                        ),
                        Text(
                          _isBarcodeMaskedVisible
                              ? displayBarcode
                              : EDevletService.maskBarcode(displayBarcode),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontFamily: 'monospace',
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isBarcodeMaskedVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textMuted,
                      size: 18,
                    ),
                    tooltip: _isBarcodeMaskedVisible ? 'Barkodu Gizle' : 'Barkodu Göster',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _isBarcodeMaskedVisible = !_isBarcodeMaskedVisible),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanLine,
                    foregroundColor: AppTheme.blueprintDark,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.copy, size: 12),
                  label: const Text('Kopyala', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () => EDevletService.copyToClipboard(context, displayBarcode),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.cyanLine,
                    side: BorderSide(color: AppTheme.cyanLine.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.open_in_browser, size: 12),
                  label: const Text('GİB Doğrula', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () => EDevletService.openOfficialVerificationPortal(context, barcode: displayBarcode),
                ),
                if (_taxPlateFilePath != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textLight,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 12),
                    label: const Text('Aç', style: TextStyle(fontSize: 10.5)),
                    onPressed: _openTaxPlatePdf,
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.cyanLine,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.sync, size: 12),
                  label: const Text('Değiştir', style: TextStyle(fontSize: 10.5)),
                  onPressed: _pickTaxPlatePdf,
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.statusDanger,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 12),
                  label: const Text('Kaldır', style: TextStyle(fontSize: 10.5)),
                  onPressed: _removeTaxPlate,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final previewPlanName = _activeLicense?.planName ?? 'Yıllık Kurumsal Sınırsız';
    final previewOffersText = _activeLicense?.remainingOffersText ?? 'Sınırsız Teklif • 365 gün kaldı';

    return _buildSectionCard(
      title: 'Üyelik & Teklif Paketi Durumu',
      icon: Icons.workspace_premium_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.amberSteel.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock_outlined, size: 12, color: AppTheme.amberSteel),
            SizedBox(width: 4),
            Text(
              'ÇOK YAKINDA',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.amberSteel),
            ),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Arkadaki Gelecek Üyelik Kartı Tasarımı (Bulanıklaştırılmış / Blur)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
              child: Opacity(
                opacity: 0.6,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.amberSteel.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: AppTheme.amberSteel,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              previewPlanName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              previewOffersText,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.statusSuccess.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AKTİF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.statusSuccess,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Öndeki Bilgilendirme Katmanı (Şeffaf Blueprint Cam Kart)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.blueprintSurface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.amberSteel.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.rocket_launch_outlined, size: 18, color: AppTheme.amberSteel),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kurumsal Üyelik Sistemi Çok Yakında',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.amberSteel,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Lansmana özel günlük 1 ücretsiz iş teklifi hakkı tanımlıdır. Avantajlı paketler ve kurumsal üyelik çok yakında aktif edilecektir.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textLight,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: BlueprintHeader(title: 'Şirket Profili'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: BlueprintHeader(
        title: 'İşveren Şirket Profili',
        trailing: IconButton(
          icon: const Icon(Icons.workspace_premium, color: AppTheme.amberSteel),
          tooltip: 'Kurumsal Abonelik & Paketler',
          onPressed: () async {
            await SubscriptionModal.show(context);
            _loadProfile();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactHeroHeader(),
              _buildCompanyInfoCard(),
              _buildContactCard(),
              _buildTaxPlateCard(),
              _buildSubscriptionCard(),
              const SizedBox(height: 6),

              // Kaydet & P2P Yayınla Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.amberSteel,
                    foregroundColor: AppTheme.blueprintDark,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cloud_done_rounded, size: 18),
                  label: const Text(
                    'ŞİRKET PROFİLİNİ KAYDET VE YAYINLA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                  ),
                  onPressed: _saveProfile,
                ),
              ),
              const SizedBox(height: 10),

              // Alt aksiyonlar (Çıkış Yap & Hesabı Sil)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _signOut,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.amberSteel,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.logout, size: 15),
                    label: const Text('Oturumu Kapat', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton.icon(
                    onPressed: _deleteAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.statusDanger,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined, size: 15),
                    label: const Text('Şirket Hesabını Sil', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
