import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/offer_model.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/p2p_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blueprint_header.dart';
import '../../core/widgets/blocked_users_dialog.dart';
import '../../core/utils/file_helper.dart';

class DraftsmanOffersView extends StatefulWidget {
  const DraftsmanOffersView({super.key});

  @override
  State<DraftsmanOffersView> createState() => _DraftsmanOffersViewState();
}

class _DraftsmanOffersViewState extends State<DraftsmanOffersView> with SingleTickerProviderStateMixin {
  final _localDb = LocalDbService();
  final _p2pService = P2PService();

  List<OfferModel> _allOffers = [];
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOffers();

    _p2pService.incomingOfferStream.listen((_) {
      _loadOffers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    final list = await _localDb.getOffers();
    final blocked = await _localDb.getBlockedUsers();
    final blockedIds = blocked.map((b) => b['id'] as String).toSet();
    final filtered = list.where((o) => !blockedIds.contains(o.companyId)).toList();
    if (mounted) {
      setState(() {
        _allOffers = filtered;
        _isLoading = false;
      });
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
          'Gelen tüm teklif kayıtlarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
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
            content: Text('Gelen tüm teklifler temizlendi.'),
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
          '"${offer.projectTitle}" başlıklı iş teklifini silmek istediğinize emin misiniz?',
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

  Future<void> _confirmBlockCompany(OfferModel offer) async {
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
            Text('Şirketi Engelle', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '"${offer.companyName}" şirketini engellemek/yoksaymak istediğinize emin misiniz?\n\nBu şirketten gelen teklifler gizlenecek ve yeni teklif alamayacaksınız.',
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
            child: const Text('Engelle ve Gizle'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _localDb.blockUser(
        userId: offer.companyId,
        name: offer.companyName,
        role: 'company',
      );
      await _loadOffers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('${offer.companyName} engellendi ve gelen kutunuzdan gizlendi.'),
          ),
        );
      }
    }
  }

  String _getCompanyEmail(OfferModel offer) {
    if (offer.companyEmail != null && offer.companyEmail!.trim().isNotEmpty) {
      return offer.companyEmail!.trim();
    }
    if (offer.companyContact.contains('/')) {
      final parts = offer.companyContact.split('/');
      for (final p in parts) {
        if (p.contains('@')) return p.trim();
      }
    } else if (offer.companyContact.contains('@')) {
      return offer.companyContact.trim();
    }
    return '';
  }

  String _getCompanyPhone(OfferModel offer) {
    if (offer.companyPhone != null && offer.companyPhone!.trim().isNotEmpty) {
      return offer.companyPhone!.trim();
    }
    if (offer.companyContact.contains('/')) {
      final parts = offer.companyContact.split('/');
      for (final p in parts) {
        final clean = p.replaceAll(RegExp(r'[^0-9+]'), '');
        if (clean.length >= 7) return p.trim();
      }
    } else {
      final clean = offer.companyContact.replaceAll(RegExp(r'[^0-9+]'), '');
      if (clean.length >= 7) return offer.companyContact.trim();
    }
    return '';
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

  Future<void> _openWebsite(String url) async {
    var target = url.trim();
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = 'https://$target';
    }
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Widget _buildCompanyAvatar(OfferModel offer, {double size = 44}) {
    if (offer.companyLogoBase64 != null && offer.companyLogoBase64!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(offer.companyLogoBase64!.trim());
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            border: Border.all(
              color: offer.companyIsVip == true
                  ? AppTheme.amberSteel
                  : (offer.companyIsVerified == true ? Colors.blueAccent : AppTheme.cyanLine.withValues(alpha: 0.4)),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular((size * 0.22) - 1.5),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(offer, size),
            ),
          ),
        );
      } catch (_) {
        return _buildFallbackAvatar(offer, size);
      }
    }
    return _buildFallbackAvatar(offer, size);
  }

  Widget _buildFallbackAvatar(OfferModel offer, double size) {
    final letter = offer.companyName.trim().isNotEmpty ? offer.companyName.trim()[0].toUpperCase() : 'Ş';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.blueprintDark,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: offer.companyIsVip == true
              ? AppTheme.amberSteel
              : (offer.companyIsVerified == true ? Colors.blueAccent : AppTheme.cyanLine.withValues(alpha: 0.3)),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: offer.companyIsVip == true
              ? AppTheme.amberSteel
              : (offer.companyIsVerified == true ? Colors.blueAccent : AppTheme.cyanLine),
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildCompactCompanyCard({
    required OfferModel offer,
    required String companyPhone,
    required String companyEmail,
    required BuildContext ctx,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCompanyAvatar(offer, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            offer.companyName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (offer.companyIsVerified == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 16, color: Colors.blueAccent),
                        ],
                        if (offer.companyIsVip == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.workspace_premium, size: 16, color: AppTheme.amberSteel),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${offer.companyCity ?? 'Türkiye'} • ${offer.branch}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine),
                        ),
                        if (offer.companyIsVerified == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'ONAYLI KURUMSAL',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (offer.companyIsVip == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.amberSteel.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              (offer.companyTier ?? 'VIP ŞİRKET').toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.amberSteel,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSubtle, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          if (offer.companyTaxNumber != null && offer.companyTaxNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'VKN / Vergi No: ${offer.companyTaxNumber}',
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
          ],
          if (offer.companyBio != null && offer.companyBio!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              offer.companyBio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
          if (companyPhone.isNotEmpty || companyEmail.isNotEmpty || (offer.companyWebsite != null && offer.companyWebsite!.trim().isNotEmpty)) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (companyPhone.isNotEmpty)
                  InkWell(
                    onTap: () => _makePhoneCall(companyPhone),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.statusSuccess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone, size: 12, color: AppTheme.statusSuccess),
                          const SizedBox(width: 4),
                          Text(
                            companyPhone,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.statusSuccess),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (companyEmail.isNotEmpty)
                  InkWell(
                    onTap: () => _sendEmail(companyEmail),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cyanLine.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined, size: 12, color: AppTheme.cyanLine),
                          const SizedBox(width: 4),
                          Text(
                            companyEmail,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.cyanLine),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (offer.companyWebsite != null && offer.companyWebsite!.trim().isNotEmpty)
                  InkWell(
                    onTap: () => _openWebsite(offer.companyWebsite!),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.amberSteel.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 12, color: AppTheme.amberSteel),
                          SizedBox(width: 4),
                          Text(
                            'Web Sitesi',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.amberSteel),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Future<void> _openAttachment(OfferAttachment att) async {
    try {
      if (att.localPath != null && await File(att.localPath!).exists()) {
        final res = await OpenFilex.open(att.localPath!);
        if (res.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.statusWarning,
              content: Text('Dosya açılamadı: ${res.message}'),
            ),
          );
        }
        return;
      }

      if (att.fileBase64 != null && att.fileBase64!.isNotEmpty) {
        final bytes = base64Decode(att.fileBase64!);
        final tempDir = await getTemporaryDirectory();
        final safeName = att.fileName.replaceAll(RegExp(r'[^\w\.\-\_]'), '_');
        final tempFile = File('${tempDir.path}/$safeName');
        await tempFile.writeAsBytes(bytes);
        final res = await OpenFilex.open(tempFile.path);
        if (res.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.statusWarning,
              content: Text('Dosya açılamadı: ${res.message}'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusWarning,
            content: Text('Dosya verisi bulunamadı veya taşınmış.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Dosya açılırken hata: $e'),
          ),
        );
      }
    }
  }

  void _showOfferDetail(OfferModel offer) {
    final replyNoteController = TextEditingController();
    final companyPhone = _getCompanyPhone(offer);
    final companyEmail = _getCompanyEmail(offer);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
          maxWidth: 720,
        ),
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.blueprintDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.cyanLine, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.steelBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. EN ÜSTTE: ŞİRKET PROFİLİ (KOMPAKT & DERLİ TOPLU)
                    _buildCompactCompanyCard(
                      offer: offer,
                      companyPhone: companyPhone,
                      companyEmail: companyEmail,
                      ctx: ctx,
                    ),
                    const SizedBox(height: 14),

                    // 2. TEKLİF EDİLEN PROJE VE DURUM ROZETİ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TEKLİF EDİLEN PROJE / POZİSYON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cyanLine,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                offer.projectTitle,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(offer.status),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. BÜTÇE VE ÇALIŞMA SÜRESİ KARTI
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
                                Text(
                                  offer.budget,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.amberSteel,
                                  ),
                                ),
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
                                Text(
                                  offer.projectDuration,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cyanLine,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4. TAKVİM & TESLİMAT BİLGİSİ
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.cyanLine),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Takvim & Teslimat: ${offer.deadline}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. PROJE KAPSAMI VE DETAYLARI
                    const Text(
                      'Proje Detayları ve Beklentiler',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cyanLine),
                    ),
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

                    // 6. PROJE DOSYALARI / ŞARTNAME / ÇİZİMLER (EKLER)
                    if (offer.attachments.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.attachment_rounded, size: 16, color: AppTheme.cyanLine),
                          const SizedBox(width: 6),
                          Text(
                            'Proje Dosyaları & Şartname (${offer.attachments.length} Dosya)',
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
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: fileColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: fileColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Icon(fileIcon, size: 18, color: fileColor),
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
                                ElevatedButton.icon(
                                  onPressed: () => _openAttachment(att),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cyanLine,
                                    foregroundColor: AppTheme.blueprintDark,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.open_in_new, size: 12),
                                  label: const Text('Aç', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // İletilmiş yanıt notu varsa
                    if (offer.responseNote != null && offer.responseNote!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.blueprintSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('İlettiğiniz Yanıt:',
                                style: TextStyle(fontSize: 11, color: AppTheme.cyanLine, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(offer.responseNote!,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Teklif Beklemedeyse Kabul / Ret butonları
                    if (offer.status == 'pending') ...[
                      TextField(
                        controller: replyNoteController,
                        decoration: const InputDecoration(
                          labelText: 'Şirkete Yanıt Notunuz (İsteğe Bağlı)',
                          hintText: 'Örn: Teklifinizi kabul ediyorum, belirtilen şartlarda başlayabilirim.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.statusDanger,
                                side: const BorderSide(color: AppTheme.statusDanger),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.close),
                              label: const Text('Reddet'),
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _respondToOffer(
                                  offer: offer,
                                  status: 'rejected',
                                  note: replyNoteController.text.trim(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.statusSuccess,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text('Kabul Et', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _respondToOffer(
                                  offer: offer,
                                  status: 'accepted',
                                  note: replyNoteController.text.trim(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 4),

                    // Şirketi Engelle & Teklifi Sil
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.block, size: 16, color: AppTheme.statusDanger),
                          label: const Text('Şirketi Engelle', style: TextStyle(color: AppTheme.statusDanger, fontSize: 12)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _confirmBlockCompany(offer);
                          },
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToOffer({
    required OfferModel offer,
    required String status,
    String? note,
  }) async {
    final draftsmanProfile = await _localDb.getUserProfile();

    await _p2pService.sendOfferResponse(
      offerId: offer.id,
      companyPeerId: offer.companyId,
      status: status,
      note: note,
      draftsmanEmail: draftsmanProfile?.email,
      draftsmanPhone: draftsmanProfile?.phone,
      draftsmanCity: draftsmanProfile?.city,
      draftsmanTitle: draftsmanProfile?.title,
      draftsmanBio: draftsmanProfile?.bio,
      draftsmanLinkedin: draftsmanProfile?.linkedinUrl,
      draftsmanKariyerNet: draftsmanProfile?.kariyerNetUrl,
    );
    await _loadOffers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: status == 'accepted' ? AppTheme.statusSuccess : AppTheme.steelBorder,
          content: Text(
            status == 'accepted'
                ? 'Teklif kabul edildi! İletişim bilgileriniz şirkete P2P şifreli iletildi.'
                : 'Teklif reddedildi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlueprintHeader(
        title: 'Gelen İş Teklifleri',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.block, color: AppTheme.textSubtle, size: 20),
              tooltip: 'Engellenen Şirketler',
              onPressed: () => BlockedUsersDialog.show(context, 'draftsman', _loadOffers),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textSubtle),
              tooltip: 'Teklifleri Temizle',
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
                      _buildOffersList(_allOffers),
                      _buildOffersList(_allOffers.where((o) => o.status == 'pending').toList()),
                      _buildOffersList(_allOffers.where((o) => o.status == 'accepted').toList()),
                      _buildOffersList(_allOffers.where((o) => o.status == 'rejected').toList()),
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
              Icon(Icons.inbox_outlined, size: 54, color: AppTheme.textSubtle),
              const SizedBox(height: 14),
              const Text(
                'Gelen Teklif Bulunmuyor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight),
              ),
              const SizedBox(height: 6),
              const Text(
                'İşveren şirketler profilinizi inceleyip doğrudan P2P şifreli teklif gönderdiğinde burada listelenecektir.',
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
        return _buildOfferCard(offer);
      },
    );
  }

  Widget _buildOfferCard(OfferModel offer) {
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildCompanyAvatar(offer, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                offer.companyName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (offer.companyIsVerified == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 15, color: Colors.blueAccent),
                            ],
                            if (offer.companyIsVip == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.workspace_premium, size: 15, color: AppTheme.amberSteel),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              offer.branch,
                              style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine, fontWeight: FontWeight.w600),
                            ),
                            if (offer.companyCity != null && offer.companyCity!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '• ${offer.companyCity}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusBadge(offer.status),
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
                      if (offer.attachments.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.attach_file_rounded, size: 13, color: AppTheme.cyanLine),
                            const SizedBox(width: 2),
                            Text(
                              '${offer.attachments.length} dosya',
                              style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ],
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
