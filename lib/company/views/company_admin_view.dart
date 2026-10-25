import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/nostr_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blueprint_header.dart';

/// Hidden Master Admin Console for KO|Apps Platform Owner.
/// Features:
/// - Protected by Master Admin PIN (Default: 1080 / koapps2026) to prevent unauthorized access
/// - Invisible Monitoring & Network Health
/// - Real-time Network Audit Logs (Who deleted their account, who registered, P2P telemetry)
/// - 1-Click Junk/Test Account Cleaner
/// - NIP-09 Kind 5 Moderation Broadcast
class CompanyAdminView extends StatefulWidget {
  final UserProfile? companyProfile;

  const CompanyAdminView({super.key, this.companyProfile});

  @override
  State<CompanyAdminView> createState() => _CompanyAdminViewState();
}

class _CompanyAdminViewState extends State<CompanyAdminView> with SingleTickerProviderStateMixin {
  final _p2pService = NostrService();
  final _localDb = LocalDbService();

  late TabController _tabController;
  final _pinController = TextEditingController();

  bool _isVerified = false;
  bool _isLoading = false;
  String? _pinError;

  List<Map<String, dynamic>> _draftsmen = [];
  List<Map<String, dynamic>> _companies = [];
  List<String> _deletedCandidateIds = [];
  List<Map<String, dynamic>> _auditLogs = [];

  StreamSubscription? _companiesSub;
  StreamSubscription? _draftsmenSub;
  StreamSubscription? _auditLogsSub;

  static const List<String> _masterPins = ['1080', 'koapps2026', 'koapps2026!'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkVerification();

    _companiesSub = _p2pService.discoveredCompaniesStream.listen((_) {
      if (mounted && _isVerified) _loadAdminData();
    });
    _draftsmenSub = _p2pService.discoveredDraftsmenStream.listen((_) {
      if (mounted && _isVerified) _loadAdminData();
    });
    _auditLogsSub = _p2pService.auditLogsStream.listen((_) {
      if (mounted && _isVerified) _loadAdminData();
    });
  }

  @override
  void dispose() {
    _companiesSub?.cancel();
    _draftsmenSub?.cancel();
    _auditLogsSub?.cancel();
    _tabController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    final verified = await _localDb.isMasterAdminVerified();
    if (mounted) {
      setState(() => _isVerified = verified);
      if (verified) {
        _p2pService.queryDraftsmen();
        _loadAdminData();
      }
    }
  }

  Future<void> _verifyPin() async {
    final entered = _pinController.text.trim();
    if (_masterPins.contains(entered)) {
      await _localDb.setMasterAdminVerified(true);
      if (mounted) {
        setState(() {
          _isVerified = true;
          _pinError = null;
        });
        _pinController.clear();
        _p2pService.queryDraftsmen();
        await _loadAdminData();
      }
    } else {
      setState(() {
        _pinError = 'Geçersiz Master Güvenlik Anahtarı! Erişim reddedildi.';
      });
    }
  }

  Future<void> _lockAdmin() async {
    await _localDb.setMasterAdminVerified(false);
    if (mounted) {
      setState(() {
        _isVerified = false;
        _pinController.clear();
        _pinError = null;
      });
    }
  }

  Future<void> _loadAdminData() async {
    final deleted = await _localDb.getDeletedCandidates();
    final draftsmen = _p2pService.discoveredDraftsmen;

    // Combine discovered companies from network with any locally known companies
    final companiesMap = <String, Map<String, dynamic>>{};
    for (final c in _p2pService.discoveredCompanies) {
      final pk = c['publicKey'] as String? ?? c['id'] as String? ?? '';
      if (pk.isNotEmpty) companiesMap[pk] = c;
    }

    try {
      final offers = await _localDb.getOffers();
      for (final o in offers) {
        if (o.companyId.isNotEmpty && !companiesMap.containsKey(o.companyId)) {
          companiesMap[o.companyId] = {
            'id': o.companyId,
            'publicKey': o.companyId,
            'name': o.companyName,
            'branch': o.projectTitle.isNotEmpty ? o.projectTitle : 'İşveren Şirket',
            'city': o.companyCity ?? '',
            'role': 'company',
            'isVerified': o.companyIsVerified ?? false,
            'verificationBadge': o.companyVerificationBadge,
            'companyLogo': o.companyLogoBase64,
          };
        }
      }
    } catch (_) {}

    final logs = _p2pService.auditLogs;

    if (mounted) {
      setState(() {
        _deletedCandidateIds = deleted;
        _draftsmen = draftsmen;
        _companies = companiesMap.values.toList();
        _auditLogs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFromRelays() async {
    setState(() => _isLoading = true);
    await _p2pService.queryDraftsmen();
    await Future.delayed(const Duration(milliseconds: 800));
    await _loadAdminData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusSuccess,
          content: Text('✓ Nostr röleleri yeniden tarandı ve denetim günlüğü güncellendi.'),
        ),
      );
    }
  }

  Future<void> _deleteTarget(Map<String, dynamic> target, {required bool isCompany}) async {
    final name = target['name'] as String? ?? 'İsimsiz';
    final peerId = target['id'] as String? ?? target['publicKey'] as String? ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.statusDanger, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.security, color: AppTheme.statusDanger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ağdan Sil: $name',
                style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '$name adlı ${isCompany ? "şirket" : "teknik ressam"} kaydı ağdan silinecek ve tüm Nostr rölelerine Kind 5 moderasyon silme sinyali gönderilecektir.\n\nEmin misiniz?',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ağdan Sil & Engelle', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true && peerId.isNotEmpty) {
      await _p2pService.broadcastModerationDelete(peerId);
      await _loadAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('✓ $name hesabı KO|Apps Admin tarafından ağdan temizlendi.'),
          ),
        );
      }
    }
  }

  Future<void> _purgeJunkAccounts() async {
    final junkCandidates = _draftsmen.where((c) {
      final name = (c['name'] as String? ?? '').trim().toLowerCase();
      final branch = (c['branch'] as String? ?? '').trim().toLowerCase();
      final bio = (c['bio'] as String? ?? '').trim().toLowerCase();
      return name == 'test' ||
          name.contains('deneme') ||
          name.contains('dummy') ||
          name.contains('asdf') ||
          name == 'null' ||
          name.isEmpty ||
          branch == 'null' ||
          (name.contains('test') && bio.isEmpty);
    }).toList();

    if (junkCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.cyanLine,
          content: Text('Ağda tespit edilen şüpheli veya çöp test hesabı bulunamadı.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.blueprintDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.amberSteel, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: AppTheme.amberSteel),
            SizedBox(width: 8),
            Text('Çöp Kayıtları Temizle', style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
          ],
        ),
        content: Text(
          'Ağda otomatik olarak ${junkCandidates.length} adet test/çöp kayıt tespit edildi:\n\n'
          '${junkCandidates.map((c) => '• ${c['name']} (${c['branch']})').join('\n')}\n\n'
          'Bu kayıtlar ağdan ve tüm rölelerden temizlensin mi?',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amberSteel,
              foregroundColor: AppTheme.blueprintDark,
            ),
            child: const Text('Tümünü Temizle', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      for (final j in junkCandidates) {
        final id = j['id'] as String? ?? j['publicKey'] as String? ?? '';
        if (id.isNotEmpty) {
          await _p2pService.broadcastModerationDelete(id);
        }
      }
      await _loadAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            content: Text('✓ ${junkCandidates.length} adet çöp kayıt başarıyla ağdan silindi.'),
          ),
        );
      }
    }
  }

  Future<void> _restoreDeleted(String peerId) async {
    await _localDb.unblockUser(peerId);
    final deleted = await _localDb.getDeletedCandidates();
    deleted.remove(peerId);
    await _localDb.clearDeletedCandidates();
    for (final id in deleted) {
      await _localDb.addDeletedCandidate(id);
    }
    await _p2pService.clearDeletedCandidates();
    await _loadAdminData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusSuccess,
          content: Text('✓ Kaydın engeli kaldırıldı ve ağdan tekrar yüklendi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVerified) {
      return _buildLockScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.blueprintDark,
      body: SafeArea(
        child: Column(
          children: [
            BlueprintHeader(
              title: '👑 KO|APPS MASTER ADMİN',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.statusSuccess.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_open, size: 12, color: AppTheme.statusSuccess),
                        SizedBox(width: 4),
                        Text(
                          'Yetkili',
                          style: TextStyle(color: AppTheme.statusSuccess, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textSubtle),
                    tooltip: 'Admin Oturumunu Kapat',
                    onPressed: _lockAdmin,
                  ),
                ],
              ),
            ),

            // Stat Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Ressamlar',
                      value: '${_draftsmen.length}',
                      icon: Icons.architecture,
                      color: AppTheme.cyanLine,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Şirketler',
                      value: '${_companies.length}',
                      icon: Icons.business,
                      color: AppTheme.amberSteel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Olay Günlüğü',
                      value: '${_auditLogs.length}',
                      icon: Icons.history,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Temizlenen',
                      value: '${_deletedCandidateIds.length}',
                      icon: Icons.block,
                      color: AppTheme.statusDanger,
                    ),
                  ),
                ],
              ),
            ),

            // Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amberSteel,
                        foregroundColor: AppTheme.blueprintDark,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.cleaning_services, size: 16),
                      label: const Text('Çöp Hesapları Temizle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _purgeJunkAccounts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.cyanLine),
                    tooltip: 'Ağı ve Günlüğü Yenile',
                    onPressed: _refreshFromRelays,
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.blueprintSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.steelBorder),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.cyanLine,
                labelColor: AppTheme.cyanLine,
                unselectedLabelColor: AppTheme.textMuted,
                isScrollable: true,
                tabs: [
                  Tab(text: 'Ressamlar (${_draftsmen.length})'),
                  Tab(text: 'Şirketler (${_companies.length})'),
                  Tab(text: '🔍 Olay Günlüğü (${_auditLogs.length})'),
                  Tab(text: 'Engellenenler (${_deletedCandidateIds.length})'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.cyanLine))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDraftsmenList(),
                        _buildCompaniesList(),
                        _buildAuditLogsList(),
                        _buildDeletedList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockScreen() {
    return Scaffold(
      backgroundColor: AppTheme.blueprintDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.blueprintSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.amberSteel.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.amberSteel.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.amberSteel.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: AppTheme.amberSteel, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '👑 KO|APPS MASTER ADMİN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu konsol merkeziyetsiz ağ teftişi, silinen hesapların denetimi ve moderasyon için yetkilendirme gerektirir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textLight, letterSpacing: 3),
                    decoration: InputDecoration(
                      labelText: 'Master Güvenlik PIN',
                      labelStyle: const TextStyle(color: AppTheme.amberSteel),
                      hintText: 'PIN Girin (Örn: 1080)',
                      hintStyle: const TextStyle(color: AppTheme.textSubtle, letterSpacing: 1),
                      prefixIcon: const Icon(Icons.key, color: AppTheme.amberSteel, size: 20),
                      errorText: _pinError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.steelBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.amberSteel, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _verifyPin(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amberSteel,
                        foregroundColor: AppTheme.blueprintDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('Admin Girişi Yap', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _verifyPin,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsmenList() {
    if (_draftsmen.isEmpty) {
      return const Center(
        child: Text('Ağda keşfedilen teknik ressam bulunamadı.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _draftsmen.length,
      itemBuilder: (context, index) {
        final d = _draftsmen[index];
        final name = d['name'] as String? ?? 'İsimsiz';
        final branch = d['branch'] as String? ?? 'Belirtilmedi';
        final city = d['city'] as String? ?? 'Şehir Yok';
        final peerId = d['id'] as String? ?? d['publicKey'] as String? ?? '';
        final isVerified = d['isVerified'] == true || d['diplomaBarcode'] != null;

        return Card(
          color: AppTheme.blueprintCard,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isVerified ? AppTheme.cyanLine.withValues(alpha: 0.4) : AppTheme.steelBorder),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.cyanLine.withValues(alpha: 0.15),
              child: const Icon(Icons.architecture, color: AppTheme.cyanLine),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cyanLine.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('✓ Onaylı', style: TextStyle(color: AppTheme.cyanLine, fontSize: 10)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$branch • $city', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                Text(
                  peerId.length > 20 ? '${peerId.substring(0, 16)}...' : peerId,
                  style: const TextStyle(fontFamily: 'monospace', color: AppTheme.textSubtle, fontSize: 10),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_forever, color: AppTheme.statusDanger),
              tooltip: 'Ağdan Sil & Engelle',
              onPressed: () => _deleteTarget(d, isCompany: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompaniesList() {
    if (_companies.isEmpty) {
      return const Center(
        child: Text('Ağda henüz başka şirket kaydı keşfedilmedi.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _companies.length,
      itemBuilder: (context, index) {
        final c = _companies[index];
        final name = c['name'] as String? ?? 'İsimsiz Şirket';
        final branch = c['branch'] as String? ?? 'Sektör';
        final city = c['city'] as String? ?? '';
        final peerId = c['publicKey'] as String? ?? c['id'] as String? ?? '';

        return Card(
          color: AppTheme.blueprintCard,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.steelBorder),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.amberSteel.withValues(alpha: 0.15),
              child: const Icon(Icons.business, color: AppTheme.amberSteel),
            ),
            title: Text(
              name,
              style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '$branch • $city\n$peerId',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              maxLines: 2,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_forever, color: AppTheme.statusDanger),
              tooltip: 'Ağdan Sil & Engelle',
              onPressed: () => _deleteTarget(c, isCompany: true),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogsList() {
    if (_auditLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights, size: 40, color: AppTheme.cyanLine),
              const SizedBox(height: 12),
              const Text(
                'Ağ Denetim & Teftiş Kayıtları',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Röleler dinleniyor. Kullanıcıların hesap silme sinyalleri (Kind 5) veya yeni profil kayıtları (Kind 0) burada anlık listelenir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyanLine,
                  foregroundColor: AppTheme.blueprintDark,
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Röleleri Şimdi Tara'),
                onPressed: _refreshFromRelays,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final type = log['type'] as String? ?? 'EVENT';
        final eventTitle = log['event'] as String? ?? 'Olay';
        final timestamp = log['timestamp'] as DateTime? ?? DateTime.now();
        final timeStr =
            '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

        Color logColor;
        IconData logIcon;

        if (type == 'DELETION') {
          logColor = AppTheme.statusDanger;
          logIcon = Icons.delete_forever;
        } else if (type == 'PROFILE') {
          logColor = log['role'] == 'company' ? AppTheme.amberSteel : AppTheme.cyanLine;
          logIcon = log['role'] == 'company' ? Icons.business : Icons.person_add;
        } else {
          logColor = AppTheme.textMuted;
          logIcon = Icons.swap_horiz;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.blueprintCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: logColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: logColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(logIcon, color: logColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          eventTitle,
                          style: TextStyle(color: logColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(color: AppTheme.textSubtle, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (type == 'DELETION') ...[
                      Text(
                        'Silinme Nedeni: ${log['reason']}',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
                      ),
                      Text(
                        log['isSelfDelete'] == true ? '✓ Kullanıcı kendi rızasıyla cihazından sildi' : '⚠️ Moderatör tarafından silindi',
                        style: TextStyle(
                          color: log['isSelfDelete'] == true ? AppTheme.statusSuccess : AppTheme.statusDanger,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'İmzalayan: did:nostr:${(log['pubkey'] as String).length > 16 ? '${(log['pubkey'] as String).substring(0, 16)}...' : log['pubkey']}',
                        style: const TextStyle(color: AppTheme.textSubtle, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ] else if (type == 'PROFILE') ...[
                      Text(
                        '${log['name']} • ${log['branch']} (${log['city']})',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
                      ),
                      Text(
                        'DID: did:nostr:${(log['pubkey'] as String).length > 16 ? '${(log['pubkey'] as String).substring(0, 16)}...' : log['pubkey']}',
                        style: const TextStyle(color: AppTheme.textSubtle, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ] else ...[
                      Text(
                        'Paket: ${log['note']}',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
                      ),
                      Text(
                        'Düğüm: did:nostr:${log['pubkey']}',
                        style: const TextStyle(color: AppTheme.textSubtle, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeletedList() {
    if (_deletedCandidateIds.isEmpty) {
      return const Center(
        child: Text('Şu ana kadar engellenen/silinen bir hesap yok.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _deletedCandidateIds.length,
      itemBuilder: (context, index) {
        final id = _deletedCandidateIds[index];
        return Card(
          color: AppTheme.blueprintCard,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppTheme.statusDanger.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            leading: const Icon(Icons.block, color: AppTheme.statusDanger),
            title: Text(
              id,
              style: const TextStyle(fontFamily: 'monospace', color: AppTheme.textLight, fontSize: 11),
            ),
            subtitle: const Text('Ağdan Silindi / Engellendi', style: TextStyle(color: AppTheme.statusDanger, fontSize: 11)),
            trailing: TextButton.icon(
              icon: const Icon(Icons.undo, size: 14, color: AppTheme.cyanLine),
              label: const Text('Geri Al', style: TextStyle(color: AppTheme.cyanLine, fontSize: 12)),
              onPressed: () => _restoreDeleted(id),
            ),
          ),
        );
      },
    );
  }
}
