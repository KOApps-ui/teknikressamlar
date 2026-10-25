import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/p2p_service.dart';
import '../../core/services/file_launcher_service.dart';
import '../../core/services/edevlet_service.dart';
import '../../core/utils/file_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blueprint_header.dart';
import '../../core/widgets/battery_optimization_dialog.dart';
import '../../core/widgets/account_removal_dialog.dart';
import '../../core/widgets/app_update_dialog.dart';
import '../../core/constants/app_version.dart';
import '../../core/services/recovery_key_backup_service.dart';
import '../../core/services/background_service.dart';
import '../../main.dart';

class DraftsmanProfileView extends StatefulWidget {
  final VoidCallback? onProfileSaved;

  const DraftsmanProfileView({super.key, this.onProfileSaved});

  @override
  State<DraftsmanProfileView> createState() => _DraftsmanProfileViewState();
}

class _DraftsmanProfileViewState extends State<DraftsmanProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _localDb = LocalDbService();
  final _authService = AuthService();
  final _p2pService = P2PService();
  final _uuid = const Uuid();

  UserProfile? _currentProfile;
  bool _isLoading = true;

  String? _selectedBranch;
  String? _selectedTitle;
  bool _isCustomTitle = false;
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _kariyerNetController = TextEditingController();
  int _experienceYears = 3;
  final List<String> _selectedSkills = [];
  final List<String> _customSkills = [];
  final List<PortfolioFile> _portfolioFiles = [];
  final List<CertificateItem> _certificates = [];
  String? _avatarPath;
  String? _avatarBase64;
  final _diplomaBarcodeController = TextEditingController();
  bool _isVerified = false;
  String? _verificationBadge;
  bool _isExtractingDiploma = false;
  String? _diplomaFileName;
  String? _diplomaFilePath;

  // Dedicated CV Fields
  String? _cvFileName;
  String? _cvFilePath;
  String? _cvBase64;
  int? _cvFileSize;
  DateTime? _cvUploadDate;

  static const List<String> availableBranches = [
    'Çelik Yapı & Konstrüksiyon',
    'Betonarme & Statik',
    'Harita & Altyapı',
    'Mekanik & Tesisat & HVAC',
    'Elektrik & Otomasyon',
    'Mimari & Cephe Çizimi',
    'Makine & Endüstriyel İmalat',
  ];

  static const Map<String, List<String>> branchTitles = {
    'Çelik Yapı & Konstrüksiyon': [
      'Çelik Yapı & Konstrüksiyon Teknik Ressamı',
      'Tekla Structures Çelik Modelleme Ressamı',
      'Endüstriyel Çelik İmalat & Montaj Ressamı',
      'Borulama & Çelik Şase Çizim Ressamı',
      'Ağır Çelik Detaylandırma Teknikeri',
      'Çelik Konstrüksiyon Başressamı',
    ],
    'Betonarme & Statik': [
      'Betonarme & Statik Proje Ressamı',
      'Kalıp & Donatı Detay Teknik Ressamı',
      'Statik Proje & Metraj Teknikeri',
      'Allplan / Revit Betonarme BIM Modelleme Ressamı',
      'Altyapı & Sanat Yapıları Statik Ressamı',
      'Prefabrik Betonarme Çizim Teknikeri',
    ],
    'Mimari & Cephe Çizimi': [
      'Mimari Uygulama & Ruhsat Projesi Ressamı',
      'Cephe & Alüminyum Giydirme Sistemleri Ressamı',
      'Revit / ArchiCAD Mimari BIM Modelleme Ressamı',
      'İç Mimari & İnce Yapı Detay Ressamı',
      '3D Mimari Görselleştirme & Çizim Teknikeri',
    ],
    'Makine & Endüstriyel İmalat': [
      'Makine Tasarım & İmalat Teknik Ressamı',
      'SolidWorks / Inventor 3D Tasarım Uzmanı',
      'Sac Metal & Lazer Kesim Açınım Ressamı',
      'Talaşlı İmalat & Kalıp Çizim Ressamı',
      'Mekatronik & Endüstriyel Tesis Yerleşim Ressamı',
      'Aparato & Fikstür Tasarım Ressamı',
    ],
    'Mekanik & Tesisat & HVAC': [
      'Mekanik Tesisat & Sıhhi Tesisat Ressamı',
      'Havalandırma (HVAC) & İklimlendirme Çizim Uzmanı',
      'Yangın Tesisatı & Sprinkler Proje Ressamı',
      'Doğalgaz & Kazan Dairesi Proje Ressamı',
      'Mekanik Koordinasyon & Çakışma (Clash/BIM) Ressamı',
    ],
    'Elektrik & Otomasyon': [
      'Elektrik Kuvvetli Akım & Aydınlatma Ressamı',
      'Zayıf Akım, Yangın & CCTV Sistemleri Ressamı',
      'Pano Tasarım & EPLAN Tek Hat Proje Ressamı',
      'Otomasyon & PLC Sinyal Proje Ressamı',
      'Trafo, OG/AG Dağıtım Şebeke Çizim Teknikeri',
    ],
    'Harita & Altyapı': [
      'Harita & Kamulaştırma Teknik Ressamı',
      'Civil 3D Yol & Altyapı Proje Ressamı',
      'Plankote & Sayısallaştırma Teknikeri',
      'CBS (GIS) & İmar Planlama Çizim Uzmanı',
      'İçme Suyu & Kanalizasyon Şebeke Ressamı',
    ],
  };

  static const List<String> generalTitles = [
    'BIM Koordinatörü & Baş Teknik Ressam',
    'Genel CAD/CAM Teknik Ressamı',
    '3D Modelleme & Teknik Görselleştirme Uzmanı',
    'Proje Koordinasyon Teknik Ressamı',
  ];

  static const List<String> availableSkills = [
    'AutoCAD',
    'Tekla Structures',
    'Revit (BIM)',
    'SolidWorks',
    'Civil 3D',
    'Allplan',
    'Navisworks',
    'Autodesk Inventor',
    'Rhino / Grasshopper',
    'STA4CAD / ideCAD',
    'MicroStation',
  ];

  List<String> _getAvailableTitlesForBranch() {
    if (_selectedBranch != null && branchTitles.containsKey(_selectedBranch)) {
      return [...branchTitles[_selectedBranch!]!, ...generalTitles];
    }
    final set = <String>{};
    for (final list in branchTitles.values) {
      set.addAll(list);
    }
    set.addAll(generalTitles);
    return set.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _linkedinController.dispose();
    _kariyerNetController.dispose();
    _diplomaBarcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _localDb.getUserProfile();
    if (profile != null) {
      _currentProfile = profile;
      _selectedBranch = availableBranches.contains(profile.branch) ? profile.branch : null;
      _nameController.text = profile.name;
      _titleController.text = profile.title;
      if (profile.title.isNotEmpty) {
        final available = _getAvailableTitlesForBranch();
        if (available.contains(profile.title)) {
          _selectedTitle = profile.title;
          _isCustomTitle = false;
        } else {
          _selectedTitle = 'custom';
          _isCustomTitle = true;
        }
      }
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _cityController.text = profile.city;
      _bioController.text = profile.bio;
      _linkedinController.text = profile.linkedinUrl ?? '';
      _kariyerNetController.text = profile.kariyerNetUrl ?? '';
      _experienceYears = profile.experienceYears;
      _selectedSkills.clear();
      _selectedSkills.addAll(profile.softwareSkills);

      _customSkills.clear();
      for (final s in profile.softwareSkills) {
        if (!availableSkills.contains(s)) {
          _customSkills.add(s);
        }
      }

      // Populate fileBase64 if missing for files <= 350KB
      bool updatedAnyFile = false;
      final updatedFiles = <PortfolioFile>[];
      for (final f in profile.portfolioFiles) {
        if (f.fileBase64 == null && f.fileSize <= 350 * 1024 && f.filePath.isNotEmpty) {
          try {
            final file = File(f.filePath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              updatedFiles.add(PortfolioFile(
                id: f.id,
                fileName: f.fileName,
                fileExtension: f.fileExtension,
                filePath: f.filePath,
                fileSize: f.fileSize,
                uploadDate: f.uploadDate,
                description: f.description,
                fileBase64: base64Encode(bytes),
              ));
              updatedAnyFile = true;
              continue;
            }
          } catch (_) {}
        }
        updatedFiles.add(f);
      }

      if (updatedAnyFile) {
        _currentProfile = profile.copyWith(portfolioFiles: updatedFiles);
        await _localDb.saveUserProfile(_currentProfile!);
      }

      _portfolioFiles.clear();
      _portfolioFiles.addAll(_currentProfile!.portfolioFiles);
      _avatarPath = profile.avatarPath;
      String? loadedAvatarB64 = profile.avatarBase64;
      if (loadedAvatarB64 != null && loadedAvatarB64.length > 80 * 1024) {
        try {
          final rawBytes = base64Decode(loadedAvatarB64);
          loadedAvatarB64 = await _compressAvatarBytes(rawBytes);
          _currentProfile = _currentProfile!.copyWith(avatarBase64: loadedAvatarB64);
          await _localDb.saveUserProfile(_currentProfile!);
        } catch (_) {}
      }
      _avatarBase64 = loadedAvatarB64;
      _diplomaBarcodeController.text = profile.diplomaBarcode ?? '';
      _isVerified = profile.isVerified;
      _verificationBadge = profile.verificationBadge;
      try {
        final dFile = profile.portfolioFiles.firstWhere(
          (f) =>
              f.fileExtension == 'pdf' &&
              (f.fileName.toLowerCase().contains('mezuniyet') ||
                  f.fileName.toLowerCase().contains('diploma') ||
                  f.description.toLowerCase().contains('e-devlet')),
        );
        _diplomaFileName = dFile.fileName;
        _diplomaFilePath = dFile.filePath;
      } catch (_) {}

      // CV loading
      _cvFileName = profile.cvFileName;
      _cvFilePath = profile.cvFilePath;
      _cvBase64 = profile.cvBase64;
      _cvFileSize = profile.cvFileSize;
      _cvUploadDate = profile.cvUploadDate;

      // Certificates loading
      _certificates.clear();
      _certificates.addAll(profile.certificates);
    } else {
      _selectedBranch = null;
      _selectedTitle = null;
      _isCustomTitle = false;
      _selectedSkills.clear();
      _nameController.clear();
      _titleController.clear();
      _emailController.clear();
      _phoneController.clear();
      _cityController.clear();
      _bioController.clear();
      _diplomaBarcodeController.clear();
      _portfolioFiles.clear();
      _certificates.clear();
      _avatarPath = null;
      _avatarBase64 = null;
      _isVerified = false;
      _verificationBadge = null;
      _diplomaFileName = null;
      _diplomaFilePath = null;
      _cvFileName = null;
      _cvFilePath = null;
      _cvBase64 = null;
      _cvFileSize = null;
      _cvUploadDate = null;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
      debugPrint('Avatar compression error: $e');
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
        final targetPath = '${appDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
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
              content: Text('Profil fotoğrafı seçildi.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Avatar pick error: $e');
    }
  }

  Future<void> _pickAndAddFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      int addedCount = 0;
      String lastFileName = '';

      for (final picked in result) {
        if (picked.path == null) continue;
        final originalFile = File(picked.path!);
        if (!originalFile.existsSync()) continue;

        final fileName = picked.name;
        final fileExtension = picked.extension ?? (fileName.contains('.') ? fileName.split('.').last : '');
        final targetPath = '${appDir.path}/portfolio_${DateTime.now().millisecondsSinceEpoch}_$fileName';

        await originalFile.copy(targetPath);
        final fileSize = await originalFile.length();

        String? fileBase64;
        if (fileSize <= 350 * 1024) {
          final bytes = await originalFile.readAsBytes();
          fileBase64 = base64Encode(bytes);
        }

        final newFile = PortfolioFile(
          id: _uuid.v4(),
          fileName: fileName,
          fileExtension: fileExtension.toLowerCase(),
          filePath: targetPath,
          fileSize: fileSize,
          uploadDate: DateTime.now(),
          description: 'Portföy Dosyası (${fileExtension.toUpperCase()})',
          fileBase64: fileBase64,
        );

        _portfolioFiles.add(newFile);
        addedCount++;
        lastFileName = fileName;
      }

      if (addedCount > 0) {
        setState(() {});
        if (mounted) {
          final msg = addedCount == 1
              ? '${FileHelper.formatFileName(lastFileName)} portföyünüze eklendi.'
              : '$addedCount dosya portföyünüze başarıyla eklendi.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.statusSuccess,
              content: Text(msg),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Dosya ekleme hatası: $e'),
          ),
        );
      }
    }
  }

  void _removeFile(String fileId) {
    setState(() {
      _portfolioFiles.removeWhere((f) => f.id == fileId);
    });
  }

  Future<void> _openPortfolioFile(PortfolioFile file) async {
    try {
      if (file.filePath.isNotEmpty && File(file.filePath).existsSync()) {
        await FileLauncherService.openFile(file.filePath);
        return;
      }
      if (file.fileBase64 != null && file.fileBase64!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/preview_${file.fileName}');
        await tempFile.writeAsBytes(base64Decode(file.fileBase64!));
        await FileLauncherService.openFile(tempFile.path);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Dosya cihazda bulunamadı.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.statusDanger, content: Text('Dosya açılamadı: $e')),
        );
      }
    }
  }

  // Dedicated CV Methods
  Future<void> _pickCvFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (result.isEmpty || result.first.path == null) return;
      final picked = result.first;
      final originalFile = File(picked.path!);
      if (!await originalFile.exists()) return;

      final appDir = await getApplicationDocumentsDirectory();
      final targetPath = '${appDir.path}/cv_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      await originalFile.copy(targetPath);
      final fileSize = await originalFile.length();

      String? cvB64;
      if (fileSize <= 1024 * 1024) {
        final bytes = await originalFile.readAsBytes();
        cvB64 = base64Encode(bytes);
      }

      setState(() {
        _cvFileName = picked.name;
        _cvFilePath = targetPath;
        _cvFileSize = fileSize;
        _cvBase64 = cvB64;
        _cvUploadDate = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('✓ CV belgesi seçildi: ${picked.name}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('CV yükleme hatası: $e'),
          ),
        );
      }
    }
  }

  Future<void> _openCvFile() async {
    try {
      if (_cvFilePath != null && File(_cvFilePath!).existsSync()) {
        await FileLauncherService.openFile(_cvFilePath!);
        return;
      }
      if (_cvBase64 != null && _cvBase64!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final ext = _cvFileName?.contains('.') == true ? _cvFileName!.split('.').last : 'pdf';
        final tempFile = File('${tempDir.path}/cv_preview_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await tempFile.writeAsBytes(base64Decode(_cvBase64!));
        await FileLauncherService.openFile(tempFile.path);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('CV belgesi cihazda bulunamadı.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('CV açma hatası: $e'),
          ),
        );
      }
    }
  }

  void _removeCv() {
    setState(() {
      _cvFileName = null;
      _cvFilePath = null;
      _cvFileSize = null;
      _cvBase64 = null;
      _cvUploadDate = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.blueprintSurface,
        content: Text('CV belgesi kaldırıldı.'),
      ),
    );
  }

  Future<void> _pickDiplomaPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) return;
      final picked = result.first;

      setState(() => _isExtractingDiploma = true);

      final originalFile = File(picked.path!);
      final bytes = await originalFile.readAsBytes();

      final appDir = await getApplicationDocumentsDirectory();
      final targetPath = '${appDir.path}/diploma_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await originalFile.copy(targetPath);

      final extraction = await EDevletService.extractFromPdfBytes(bytes);

      if (extraction.success && extraction.barcode != null && extraction.barcode!.isNotEmpty) {
        setState(() {
          _diplomaBarcodeController.text = extraction.barcode!;
          _isVerified = true;
          _verificationBadge = extraction.institution ?? 'e-Devlet Onaylı Mezuniyet Belgesi';
          _diplomaFileName = picked.name;
          _diplomaFilePath = targetPath;
        });

        final exists = _portfolioFiles.any((f) => f.filePath == targetPath || f.fileName == picked.name);
        if (!exists) {
          final newFile = PortfolioFile(
            id: _uuid.v4(),
            fileName: picked.name,
            fileExtension: 'pdf',
            filePath: targetPath,
            fileSize: bytes.length,
            uploadDate: DateTime.now(),
            description: '${extraction.institution ?? "e-Devlet"} Barkodlu Mezuniyet Belgesi (PDF)',
          );
          setState(() {
            _portfolioFiles.add(newFile);
          });
        }

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
                      '✓ Barkod No belgeden otomatik çıkarıldı: ${EDevletService.maskBarcode(extraction.barcode!)}',
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          _showManualBarcodeInputDialog(
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
        setState(() => _isExtractingDiploma = false);
      }
    }
  }

  void _showManualBarcodeInputDialog({
    required String pdfPath,
    required String pdfName,
    required int fileSize,
    String? reason,
  }) {
    final manualController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: AppTheme.cyanLine),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Barkod Numarasını Girin',
                style: TextStyle(fontSize: 16, color: AppTheme.textLight, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason ?? 'PDF dosyasından barkod otomatik okunamadı (Taranmış resim olabilir).',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lütfen belgenin altındaki e-Devlet barkod numarasını girin:',
              style: TextStyle(fontSize: 12, color: AppTheme.textLight),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: manualController,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5, color: AppTheme.textLight),
              decoration: const InputDecoration(
                hintText: 'Örn: B2886F454378A2...',
                prefixIcon: Icon(Icons.pin, color: AppTheme.cyanLine, size: 18),
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
              final code = manualController.text.trim().toUpperCase();
              if (code.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.statusDanger,
                    content: Text('Lütfen geçerli bir barkod numarası girin (en az 6 karakter).'),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              setState(() {
                _diplomaBarcodeController.text = code;
                _isVerified = true;
                _verificationBadge = 'e-Devlet Onaylı Mezuniyet Belgesi';
                _diplomaFileName = pdfName;
                _diplomaFilePath = pdfPath;

                final exists = _portfolioFiles.any((f) => f.filePath == pdfPath || f.fileName == pdfName);
                if (!exists) {
                  _portfolioFiles.add(
                    PortfolioFile(
                      id: _uuid.v4(),
                      fileName: pdfName,
                      fileExtension: 'pdf',
                      filePath: pdfPath,
                      fileSize: fileSize,
                      uploadDate: DateTime.now(),
                      description: 'e-Devlet Barkodlu Mezuniyet Belgesi (PDF)',
                    ),
                  );
                }
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.statusSuccess,
                  content: Text('✓ Belge barkodu kaydedildi: ${EDevletService.maskBarcode(code)}'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _removeDiploma() {
    setState(() {
      _diplomaBarcodeController.clear();
      _isVerified = false;
      _verificationBadge = null;
      _diplomaFileName = null;
      _diplomaFilePath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.blueprintSurface,
        content: Text('Mezuniyet belgesi ve barkod doğrulaması kaldırıldı.'),
      ),
    );
  }

  Future<void> _openDiplomaPdf() async {
    if (_diplomaFilePath != null && File(_diplomaFilePath!).existsSync()) {
      await FileLauncherService.openFile(_diplomaFilePath!);
      return;
    }
    try {
      final dFile = _portfolioFiles.firstWhere(
        (f) =>
            f.fileExtension == 'pdf' &&
            (f.fileName.toLowerCase().contains('mezuniyet') || f.description.toLowerCase().contains('e-devlet')),
      );
      await FileLauncherService.openFile(dFile.filePath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('PDF belgesi cihazda bulunamadı.'),
          ),
        );
      }
    }
  }

  void _showSecretKeyDialog() {
    final privKey = _currentProfile?.privateKey ?? '';
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
                'Gizli Kurtarma Anahtarı',
                style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Bu anahtar hesabınızın sahibini kanıtlayan tek şifredir!\n\nUygulamayı silseniz dahi, bu anahtarı yapıştırarak tüm profilinizi anında geri yükleyebilirsiniz.',
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
            label: const Text('Kopyala', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: privKey));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppTheme.statusSuccess,
                  content: Text('✓ Gizli kurtarma anahtarı panoya kopyalandı.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRestoreAccountDialog() async {
    final backups = await RecoveryKeyBackupService().listBackups();
    if (!mounted) return;
    final keyController = TextEditingController();
    bool isRestoring = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.blueprintDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.cyanLine, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore, color: AppTheme.cyanLine),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hesabı Geri Yükle',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (backups.isNotEmpty) ...[
                    const Row(
                      children: [
                        Icon(Icons.phone_android, size: 14, color: AppTheme.cyanLine),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Bu cihazdaki yedekli hesaplar — tek dokunuşla açılır',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cyanLine),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...backups.map(_buildBackupTile),
                    const SizedBox(height: 4),
                    const Divider(color: AppTheme.steelBorder),
                    const SizedBox(height: 8),
                    const Text(
                      'veya kurtarma anahtarınızı kullanın:',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    const Text(
                      'Bu cihazda yedekli hesap bulunamadı. Daha önce yedeklediğiniz 64 haneli kurtarma anahtarınızı yapıştırın:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: keyController,
                    maxLines: 2,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.cyanLine),
                    decoration: const InputDecoration(
                      hintText: '64 karakterli hex anahtar...',
                      prefixIcon: Icon(Icons.key, color: AppTheme.cyanLine),
                    ),
                  ),
                  if (isRestoring) ...[
                    const SizedBox(height: 14),
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanLine)),
                          SizedBox(width: 8),
                          Text('Hesap aranıyor...', style: TextStyle(fontSize: 12, color: AppTheme.cyanLine)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyanLine,
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
                        role: 'draftsman',
                      );

                      if (!ctx.mounted || !mounted) return;
                      Navigator.of(ctx).pop();

                      if (res.isSuccess && res.profile != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.statusSuccess,
                            content: Text('✓ Hoş geldiniz! ${res.profile!.name} hesabı geri yüklendi.'),
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

  Widget _buildBackupTile(AccountBackup backup) {
    final p = backup.profile;
    final d = backup.savedAt;
    final date =
        '${d.day}.${d.month}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () async {
        final restored = await RecoveryKeyBackupService().restoreToLocal(backup);
        if (!mounted) return;
        Navigator.of(context).pop();
        if (restored == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('✓ ${restored.name} hesabı cihazdan geri yüklendi (${backup.offers.length} teklif).'),
          ),
        );
        await _loadProfile();
        if (_currentProfile != null) {
          await _p2pService.start(userProfile: _currentProfile!);
        }
        widget.onProfileSaved?.call();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.blueprintSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cyanLine.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 18, color: AppTheme.cyanLine),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.branch} • $date • ${backup.offers.length} teklif',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.download_rounded, size: 18, color: AppTheme.cyanLine),
          ],
        ),
      ),
    );
  }

  void _showAddCustomSkillDialog() {
    final skillController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Özel Yetenek / Yazılım Ekle', style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
        content: TextField(
          controller: skillController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textLight),
          decoration: const InputDecoration(hintText: 'Örn: Catia, SDS/2, Rhino Grasshopper...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyanLine,
              foregroundColor: AppTheme.blueprintDark,
            ),
            onPressed: () {
              final val = skillController.text.trim();
              if (val.isNotEmpty && !_selectedSkills.contains(val)) {
                setState(() {
                  _selectedSkills.add(val);
                  _customSkills.add(val);
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusDanger,
          content: Text('Lütfen eksik alanları (Meslek Branşı, Ünvan, Ad Soyad) doldurunuz.'),
        ),
      );
      return;
    }

    if (_selectedBranch == null || _selectedBranch!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusDanger,
          content: Text('Lütfen bir Meslek Branşı seçiniz!'),
        ),
      );
      return;
    }

    final finalTitle = _isCustomTitle
        ? _titleController.text.trim()
        : (_selectedTitle?.trim() ?? _titleController.text.trim());

    if (finalTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusDanger,
          content: Text('Lütfen bir Uzmanlık ve Ünvan seçiniz!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_currentProfile == null) {
      final authRes = await _authService.signInWithLocalDID(
        name: _nameController.text.trim(),
        role: 'draftsman',
        branch: _selectedBranch!,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
      );

      if (authRes.isSuccess && authRes.profile != null) {
        _currentProfile = authRes.profile;
      }
    }

    if (_currentProfile != null) {
      final updatedProfile = _currentProfile!.copyWith(
        name: _nameController.text.trim(),
        role: 'draftsman',
        branch: _selectedBranch!,
        title: finalTitle,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        bio: _bioController.text.trim(),
        experienceYears: _experienceYears,
        softwareSkills: _selectedSkills,
        portfolioFiles: _portfolioFiles,
        certificates: _certificates,
        avatarPath: _avatarPath,
        avatarBase64: _avatarBase64,
        isVerified: _isVerified,
        verificationBadge: _verificationBadge,
        diplomaBarcode: _diplomaBarcodeController.text.trim(),
        linkedinUrl: _linkedinController.text.trim(),
        kariyerNetUrl: _kariyerNetController.text.trim(),
        cvFileName: _cvFileName,
        cvFilePath: _cvFilePath,
        cvBase64: _cvBase64,
        cvFileSize: _cvFileSize,
        cvUploadDate: _cvUploadDate,
        clearCv: _cvFileName == null,
        updatedAt: DateTime.now(),
      );

      await _localDb.saveUserProfile(updatedProfile);
      await _localDb.setLoggedIn(true);
      _currentProfile = updatedProfile;
      await RecoveryKeyBackupService().backupProfile(updatedProfile);

      await _p2pService.start(userProfile: updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('Profiliniz cihazda kaydedildi ve P2P ağına duyuruldu.'),
          ),
        );
        widget.onProfileSaved?.call();
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        title: const Text('Hesaptan Çıkış Yap', style: TextStyle(color: AppTheme.textLight)),
        content: const Text(
          'Çıkış yapmak istediğinize emin misiniz? Verileriniz cihazda kalacaktır.',
        ),
        actions: [
          TextButton(child: const Text('İptal'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amberSteel, foregroundColor: AppTheme.blueprintDark),
            child: const Text('Çıkış Yap'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await BackgroundService.stop();
      await _p2pService.dispose();
      await _localDb.setLoggedIn(false);
      widget.onProfileSaved?.call();
    }
  }

  Future<void> _deleteAccount() async {
    final res = await AccountRemovalDialog.confirm(
      context: context,
      title: 'Teknik Ressam Profilini ve Verileri Sil',
      message:
          'Teknik ressam profiliniz, portföyünüz ve gelen tüm teklifleriniz bu cihazdan kalıcı olarak silinecektir.',
      profile: _currentProfile,
      confirmLabel: 'KALICI OLARAK SİL',
    );

    if (res.decision == RemovalDecision.restoreBackup && res.backup != null) {
      await RecoveryKeyBackupService().restoreToLocal(res.backup!);
      if (mounted) widget.onProfileSaved?.call();
      return;
    }

    if (res.decision == RemovalDecision.confirmDelete && mounted) {
      try {
        await _localDb.deleteUserProfile();
        await _localDb.clearAllOffers();
        unawaited(BackgroundService.stop());
        unawaited(_p2pService.dispose());
      } catch (e) {
        debugPrint('Account deletion error: $e');
      }

      if (mounted) {
        TeknikRessamlarApp.resetToModeSelector(context);
      }
    }
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

  void _showAccountSecurityDialog() {
    final hasProfile = _currentProfile != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cyanLine, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.cyanLine),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hesap Güvenliği & Kurtarma',
                style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.35)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, size: 14, color: AppTheme.amberSteel),
                        SizedBox(width: 6),
                        Text(
                          'Kurtarma Anahtarı Nedir?',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.amberSteel),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '64 hanelik gizli anahtarınız yalnızca bu cihazda üretilir, hiçbir sunucuya gönderilmez. Profilinizi ve DID kimliğinizi bu anahtar temsil eder.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '⚠️ Anahtarı not alıp saklayın. Kaydederseniz hesabınızı geri yükleyebilirsiniz; kaybederseniz kurtarılamaz.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textLight, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (!hasProfile) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cyanLine.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.history, size: 16, color: AppTheme.cyanLine),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Daha önce hesap açtıysanız “Eski Hesabı Geri Yükle” ile cihazdaki yedeğinizi tek dokunuşla açabilirsiniz.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textLight, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.amberSteel,
                    side: const BorderSide(color: AppTheme.amberSteel),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.vpn_key_outlined, size: 15),
                  label: const Text('Kurtarma Anahtarını Gör', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: hasProfile
                      ? () {
                          Navigator.of(ctx).pop();
                          _showSecretKeyDialog();
                        }
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanLine,
                    foregroundColor: AppTheme.blueprintDark,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.settings_backup_restore, size: 15),
                  label: const Text('Eski Hesabı Geri Yükle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showRestoreAccountDialog();
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Kapat', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
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

    final displayName = _nameController.text.trim().isEmpty ? 'Teknik Ressam' : _nameController.text.trim();
    final displayTitle = _isCustomTitle
        ? (_titleController.text.trim().isEmpty ? 'Özel Ünvan' : _titleController.text.trim())
        : (_selectedTitle ?? _selectedBranch ?? 'Profilinizi Yapılandırın');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cyanLine, width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.blueprintDark,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(Icons.person, size: 30, color: AppTheme.cyanLine)
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
                      color: AppTheme.cyanLine,
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
                  displayTitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.cyanLine),
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
                          color: AppTheme.statusSuccess.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 11, color: AppTheme.statusSuccess),
                            SizedBox(width: 3),
                            Text('e-Devlet Onaylı', style: TextStyle(color: AppTheme.statusSuccess, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (_cvFileName != null)
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
                            Icon(Icons.description, size: 11, color: AppTheme.amberSteel),
                            SizedBox(width: 3),
                            Text('CV Yüklü', style: TextStyle(color: AppTheme.amberSteel, fontSize: 10, fontWeight: FontWeight.bold)),
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
                        '$_experienceYears Yıl Deneyim',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Güvenlik — "CV Yüklü" rozetiyle AYNI stil:
                // ikon yeşil, yazı kırmızı, kartın sağ kenarında değil
                // rozet bloğunun ALTINA yerleşir.
                InkWell(
                  onTap: _showAccountSecurityDialog,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.statusDanger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppTheme.statusDanger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 11,
                          color: AppTheme.statusSuccess,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Güvenlik',
                          style: TextStyle(
                            color: AppTheme.statusDanger,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCvCard() {
    final hasCv = _cvFileName != null && _cvFileName!.isNotEmpty;

    return _buildSectionCard(
      title: 'Özgeçmiş (CV)',
      icon: Icons.description_outlined,
      trailing: hasCv
          ? TextButton.icon(
              onPressed: _pickCvFile,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.sync, size: 13, color: AppTheme.cyanLine),
              label: const Text('Değiştir', style: TextStyle(fontSize: 11, color: AppTheme.cyanLine)),
            )
          : null,
      child: hasCv
          ? Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.blueprintDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (_cvFileName!.toLowerCase().endsWith('pdf') ? AppTheme.statusDanger : AppTheme.cyanLine)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_cvFileName!.toLowerCase().endsWith('pdf') ? AppTheme.statusDanger : AppTheme.cyanLine)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      _cvFileName!.toLowerCase().endsWith('pdf') ? Icons.picture_as_pdf : Icons.description,
                      color: _cvFileName!.toLowerCase().endsWith('pdf') ? AppTheme.statusDanger : AppTheme.cyanLine,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cvFileName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${FileHelper.formatFileSize(_cvFileSize ?? 0)} • ${_cvUploadDate != null ? "${_cvUploadDate!.day}.${_cvUploadDate!.month}.${_cvUploadDate!.year}" : "Yüklendi"}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cyanLine,
                      foregroundColor: AppTheme.blueprintDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('Görüntüle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: _openCvFile,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.statusDanger),
                    tooltip: 'CV Kaldır',
                    visualDensity: VisualDensity.compact,
                    onPressed: _removeCv,
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: _pickCvFile,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.cyanLine.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cyanLine.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.upload_file_outlined, color: AppTheme.cyanLine, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Özgeçmiş (CV) Yükle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight)),
                          SizedBox(height: 2),
                          Text(
                            'PDF veya Word formatında CV ekleyin. Şirketler profilinizden inceleyebilir.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.cyanLine, size: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCompactEDevletCard() {
    final hasBarcode = _diplomaBarcodeController.text.trim().isNotEmpty;
    final displayBarcode = _diplomaBarcodeController.text.trim();

    return _buildSectionCard(
      title: 'e-Devlet Mezuniyet Doğrulama',
      icon: Icons.verified_user_outlined,
      trailing: _isExtractingDiploma
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanLine),
            )
          : null,
      child: hasBarcode
          ? Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.blueprintDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
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
                          _diplomaFileName ?? _verificationBadge ?? 'e-Devlet Onaylı Mezuniyet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.statusDanger),
                        tooltip: 'Doğrulamayı Kaldır',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _removeDiploma,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.blueprintSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.steelBorder),
                          ),
                          child: Text(
                            'Barkod: ${EDevletService.maskBarcode(displayBarcode)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cyanLine,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_diplomaFilePath != null)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cyanLine,
                            foregroundColor: AppTheme.blueprintDark,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _openDiplomaPdf,
                          child: const Text('PDF Aç', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cyanLine,
                          side: const BorderSide(color: AppTheme.cyanLine),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => EDevletService.openOfficialVerificationPortal(context, barcode: displayBarcode),
                        child: const Text('e-Devlet', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: _isExtractingDiploma ? null : _pickDiplomaPdf,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppTheme.cyanLine, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('e-Devlet Mezuniyet Belgesi Yükle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight)),
                          SizedBox(height: 2),
                          Text('PDF barkodu otomatik okunur ve profiliniz doğrulanır.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.cyanLine, size: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCompactProfessionCard() {
    return _buildSectionCard(
      title: 'Meslek Branşı & Uzmanlık',
      icon: Icons.architecture,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('branch_$_selectedBranch'),
                  initialValue: _selectedBranch,
                  isExpanded: true,
                  dropdownColor: AppTheme.blueprintSurface,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Meslek Branşı',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  hint: const Text('Branş seçiniz...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  items: availableBranches.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Branş seçin' : null,
                  onChanged: (val) {
                    setState(() {
                      _selectedBranch = val;
                      if (!_isCustomTitle) {
                        _selectedTitle = null;
                        _titleController.clear();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('exp_$_experienceYears'),
                  initialValue: _experienceYears,
                  dropdownColor: AppTheme.blueprintSurface,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Deneyim',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: List.generate(31, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text(index == 0 ? 'Yeni Mezun' : '$index Yıl'),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _experienceYears = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('title_${_selectedBranch}_$_selectedTitle'),
            initialValue: (_selectedTitle != null &&
                    (_getAvailableTitlesForBranch().contains(_selectedTitle) || _selectedTitle == 'custom'))
                ? _selectedTitle
                : null,
            isExpanded: true,
            dropdownColor: AppTheme.blueprintSurface,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Uzmanlık Ünvanı',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            hint: const Text('Ünvan seçiniz...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            items: [
              ..._getAvailableTitlesForBranch().map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
              const DropdownMenuItem(
                value: 'custom',
                child: Text('✏️ Diğer / Kendim Yazacağım...', style: TextStyle(color: AppTheme.cyanLine, fontWeight: FontWeight.bold)),
              ),
            ],
            onChanged: (val) {
              setState(() {
                if (val == 'custom') {
                  _isCustomTitle = true;
                  _selectedTitle = 'custom';
                } else {
                  _isCustomTitle = false;
                  _selectedTitle = val;
                  _titleController.text = val ?? '';
                }
              });
            },
          ),
          if (_isCustomTitle) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Özel Ünvanınız',
                hintText: 'Örn: Kıdemli Cephe Proje Ressamı',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              validator: (val) => _isCustomTitle && (val == null || val.trim().isEmpty) ? 'Ünvan giriniz' : null,
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: _bioController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Kısa Biyografi / Teknik Özet',
              hintText: 'Örn: 8 yıldır endüstriyel çelik ve borulama projelerinde Tekla & AutoCAD ile modelleme yapmaktayım.',
              isDense: true,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContactCard() {
    return _buildSectionCard(
      title: 'Kimlik & İletişim Bilgileri',
      icon: Icons.contact_mail_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Adınızı girin' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Şehir / Konum',
                    hintText: 'Örn: İstanbul',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    hintText: '05xx xxx xx xx',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'E-Posta',
                    hintText: 'ornek@mail.com',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _linkedinController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'LinkedIn',
                    hintText: 'linkedin.com/in/...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    prefixIcon: Icon(Icons.link, size: 18, color: Color(0xFF0077B5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _kariyerNetController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Kariyer.net',
                    hintText: 'kariyer.net/ozgecmis/...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    prefixIcon: Icon(Icons.business_center_outlined, size: 18, color: Color(0xFF832161)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSkillsCard() {
    return _buildSectionCard(
      title: 'CAD / BIM Yetkinlikleri (${_selectedSkills.length})',
      icon: Icons.code,
      trailing: TextButton.icon(
        onPressed: _showAddCustomSkillDialog,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.add, size: 14, color: AppTheme.cyanLine),
        label: const Text('+ Özel Yetenek', style: TextStyle(fontSize: 11, color: AppTheme.cyanLine)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ...availableSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill, style: TextStyle(fontSize: 11, color: isSelected ? AppTheme.blueprintDark : AppTheme.textLight)),
              selected: isSelected,
              selectedColor: AppTheme.cyanLine,
              backgroundColor: AppTheme.blueprintDark,
              side: BorderSide(color: isSelected ? AppTheme.cyanLine : AppTheme.steelBorder),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSkills.add(skill);
                  } else {
                    _selectedSkills.remove(skill);
                  }
                });
              },
            );
          }),
          ..._customSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill, style: TextStyle(fontSize: 11, color: isSelected ? AppTheme.blueprintDark : AppTheme.textLight)),
              selected: isSelected,
              selectedColor: AppTheme.amberSteel,
              backgroundColor: AppTheme.blueprintDark,
              side: BorderSide(color: isSelected ? AppTheme.amberSteel : AppTheme.steelBorder),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSkills.add(skill);
                  } else {
                    _selectedSkills.remove(skill);
                    _customSkills.remove(skill);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }

  void _removeCertificate(String id) {
    setState(() {
      _certificates.removeWhere((c) => c.id == id);
    });
  }

  Future<void> _openCertificateFile(CertificateItem cert) async {
    try {
      if (cert.filePath != null && cert.filePath!.isNotEmpty && File(cert.filePath!).existsSync()) {
        await FileLauncherService.openFile(cert.filePath!);
        return;
      }
      if (cert.fileBase64 != null && cert.fileBase64!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final ext = cert.fileName != null && cert.fileName!.contains('.')
            ? cert.fileName!.split('.').last
            : 'pdf';
        final tempFile = File('${tempDir.path}/cert_${cert.id}.$ext');
        await tempFile.writeAsBytes(base64Decode(cert.fileBase64!));
        await FileLauncherService.openFile(tempFile.path);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Sertifika belgesi cihazda bulunamadı.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.statusDanger, content: Text('Belge açılamadı: $e')),
        );
      }
    }
  }

  Future<void> _showAddCertificateDialog() async {
    final titleController = TextEditingController();
    final issuerController = TextEditingController();
    final yearController = TextEditingController(text: DateTime.now().year.toString());
    final credIdController = TextEditingController();
    String? certFileName;
    String? certFilePath;
    String? certBase64;
    int? certFileSize;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.blueprintDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.amberSteel, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: AppTheme.amberSteel, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Yeni Mesleki Sertifika / Belge Ekle',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Sertifika / Uzmanlık Adı *',
                    hintText: 'Örn: Autodesk Certified: AutoCAD, SolidWorks CSWP...',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.amberSteel),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: issuerController,
                        style: const TextStyle(color: AppTheme.textLight),
                        decoration: const InputDecoration(
                          labelText: 'Veren Kurum / Kuruluş *',
                          hintText: 'Autodesk, Dassault, MEB, TMMOB...',
                          prefixIcon: Icon(Icons.business_outlined, color: AppTheme.cyanLine),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textLight),
                        decoration: const InputDecoration(
                          labelText: 'Yıl',
                          hintText: '2024',
                          prefixIcon: Icon(Icons.calendar_today_outlined, color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: credIdController,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Sertifika No / Doğrulama Kodu (Opsiyonel)',
                    hintText: 'Örn: CSWP-982341 veya Lisans Kodu',
                    prefixIcon: Icon(Icons.qr_code, color: AppTheme.cyanLine),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.steelBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        certFileName != null ? Icons.check_circle : Icons.upload_file,
                        color: certFileName != null ? AppTheme.statusSuccess : AppTheme.cyanLine,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              certFileName ?? 'Sertifika Belgesi Ekle (Opsiyonel)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: certFileName != null ? AppTheme.textLight : AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              certFileName != null
                                  ? FileHelper.formatFileSize(certFileSize ?? 0)
                                  : 'PDF, JPG veya PNG formatında',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.cyanLine,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(certFileName != null ? 'Değiştir' : 'Dosya Seç'),
                        onPressed: () async {
                          final res = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          );
                          if (res.isNotEmpty && res.first.path != null) {
                            final picked = res.first;
                            final path = picked.path!;
                            final file = File(path);
                            final bytes = await file.readAsBytes();
                            setModalState(() {
                              certFileName = picked.name;
                              certFilePath = path;
                              certFileSize = bytes.length;
                              if (bytes.length <= 500 * 1024) {
                                certBase64 = base64Encode(bytes);
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.amberSteel,
                      foregroundColor: AppTheme.blueprintDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.verified, size: 20),
                    label: const Text(
                      'SERTİFİKAYI EKLE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      final title = titleController.text.trim();
                      final issuer = issuerController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppTheme.statusDanger,
                            content: Text('Lütfen sertifika adını giriniz.'),
                          ),
                        );
                        return;
                      }
                      final newCert = CertificateItem(
                        id: 'cert_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        issuer: issuer.isNotEmpty ? issuer : 'Yetkili Kurum',
                        issueYear: yearController.text.trim(),
                        credentialId: credIdController.text.trim().isNotEmpty
                            ? credIdController.text.trim()
                            : null,
                        fileName: certFileName,
                        filePath: certFilePath,
                        fileBase64: certBase64,
                        fileSize: certFileSize,
                        dateAdded: DateTime.now(),
                      );
                      setState(() {
                        _certificates.add(newCert);
                      });
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCertificatesCard() {
    return _buildSectionCard(
      title: 'Mesleki Sertifikalar & Yetkinlikler (${_certificates.length})',
      icon: Icons.workspace_premium,
      trailing: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.amberSteel,
          foregroundColor: AppTheme.blueprintDark,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.add, size: 14),
        label: const Text('Sertifika Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: _showAddCertificateDialog,
      ),
      child: _certificates.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: AppTheme.textSubtle, size: 28),
                  SizedBox(height: 6),
                  Text(
                    'Henüz sertifika eklenmedi.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Autodesk, SolidWorks, Revit, Tekla veya MYK belgelerinizi ekleyin; şirketler yetkinliklerinize göre size doğrudan iş teklifi iletsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            )
          : Column(
              children: _certificates.map((cert) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.amberSteel.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.military_tech, color: AppTheme.amberSteel, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cert.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cert.issuer}${cert.issueYear.isNotEmpty ? ' • ${cert.issueYear}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: AppTheme.cyanLine),
                            ),
                            if (cert.credentialId != null && cert.credentialId!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'No: ${cert.credentialId!}',
                                style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontFamily: 'monospace'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (cert.fileName != null)
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.cyanLine),
                          tooltip: 'Belgeyi Görüntüle',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openCertificateFile(cert),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.statusDanger),
                        tooltip: 'Sil',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeCertificate(cert.id),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildCompactPortfolioCard() {
    return _buildSectionCard(
      title: 'Portföy Çizimleri & Dosyalar (${_portfolioFiles.length})',
      icon: Icons.folder_open,
      trailing: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.cyanLine,
          foregroundColor: AppTheme.blueprintDark,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.add, size: 14),
        label: const Text('Dosya Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: _pickAndAddFile,
      ),
      child: _portfolioFiles.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                'Henüz portföy çizimi (DWG, STEP, PDF, Revit vb.) eklenmedi.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            )
          : Column(
              children: _portfolioFiles.map((file) {
                final iconData = FileHelper.getFileIcon(file.fileExtension);
                final color = FileHelper.getFileColor(file.fileExtension);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.steelBorder.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(iconData, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                            Text(
                              '${file.fileExtension.toUpperCase()} • ${FileHelper.formatFileSize(file.fileSize)}',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16, color: AppTheme.cyanLine),
                        tooltip: 'Aç',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openPortfolioFile(file),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.statusDanger),
                        tooltip: 'Sil',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeFile(file.id),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: BlueprintHeader(title: 'Teknik Ressam Profili'),
        body: Center(child: CircularProgressIndicator(color: AppTheme.cyanLine)),
      );
    }

    return Scaffold(
      appBar: const BlueprintHeader(title: 'Teknik Ressam Profili'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactHeroHeader(),
              _buildCompactCvCard(),
              _buildCompactProfessionCard(),
              _buildCompactContactCard(),
              _buildCompactEDevletCard(),
              _buildCompactSkillsCard(),
              _buildCompactCertificatesCard(),
              _buildCompactPortfolioCard(),
              const BatteryOptimizationCard(),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanLine,
                    foregroundColor: AppTheme.blueprintDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text(
                    'PROFİLİ KAYDET VE P2P AĞINA DUYUR',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                  ),
                  onPressed: _saveProfile,
                ),
              ),
              const SizedBox(height: 12),

              // Sürüm & Güncelleme Denetimi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.blueprintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.steelBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppTheme.cyanLine, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KO|Apps Teknik Ressamlar',
                            style: TextStyle(color: AppTheme.textLight, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Sürüm: v${AppVersion.version}',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.cyanLine,
                        side: const BorderSide(color: AppTheme.cyanLine),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.system_update_alt, size: 14),
                      label: const Text('Güncelle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => AppUpdateDialog.checkAndShow(
                        context,
                        force: true,
                        showIfNotAvailable: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Hesaptan Çıkış', style: TextStyle(fontSize: 12)),
                    onPressed: _signOut,
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.statusDanger),
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: const Text('Hesabı Kalıcı Sil', style: TextStyle(fontSize: 12)),
                    onPressed: _deleteAccount,
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
