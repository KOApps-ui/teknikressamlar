import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/user_profile.dart';
import '../core/services/local_db_service.dart';
import '../core/services/p2p_service.dart';
import '../core/services/background_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/quick_login_view.dart';
import '../core/widgets/account_removal_dialog.dart';
import '../core/widgets/battery_optimization_dialog.dart';
import '../core/services/recovery_key_backup_service.dart';
import '../main.dart';
import 'views/company_search_view.dart';
import 'views/company_sent_offers_view.dart';
import 'views/company_profile_view.dart';
import 'views/company_admin_view.dart';

class CompanyApp extends StatefulWidget {
  const CompanyApp({super.key});

  @override
  State<CompanyApp> createState() => _CompanyAppState();
}

class _CompanyAppState extends State<CompanyApp> with WidgetsBindingObserver {
  final _localDb = LocalDbService();
  final _p2pService = P2PService();

  UserProfile? _companyProfile;
  bool _isLoading = true;
  bool _isLoggedIn = true;
  bool _isEditingProfile = false;
  int _currentIndex = 0;
  int _profileViewEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCompanyProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _p2pService.resume();
    }
  }

  Future<void> _checkCompanyProfile() async {
    _profileViewEpoch++;
    try {
      final profile = await _localDb.getUserProfile();
      final loggedIn = await _localDb.isUserLoggedIn();

      if (profile != null && loggedIn) {
        await _p2pService.start(userProfile: profile).timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            debugPrint('Company P2PService start timed out; continuing in background');
          },
        );
        unawaited(_p2pService.listenBranch('all'));
        unawaited(_p2pService.scanNetwork());
        unawaited(BackgroundService.start(profile));
      }

      if (mounted) {
        setState(() {
          _companyProfile = profile;
          _isLoggedIn = loggedIn;
          _isLoading = false;
          _isEditingProfile = false;
        });

        if (profile != null && loggedIn) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              BatteryOptimizationDialog.checkAndShow(context);
            }
          });
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _checkCompanyProfile: $e\n$stack');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectSession() async {
    if (_companyProfile == null) return;
    setState(() => _isLoading = true);
    try {
      await _localDb.setLoggedIn(true);
      await _p2pService.start(userProfile: _companyProfile!).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Company P2PService start timed out; continuing in background');
        },
      );
      unawaited(_p2pService.listenBranch('all'));
      unawaited(_p2pService.scanNetwork());
      unawaited(BackgroundService.start(_companyProfile!));
    } catch (e, stack) {
      debugPrint('Error in _connectSession: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCurrentAccount() async {
    final res = await AccountRemovalDialog.confirm(
      context: context,
      title: 'Şirket Hesabını Kalıcı Olarak Sil',
      message:
          'Şirket profiliniz, kimlik anahtarlarınız ve bu cihazdaki tüm teklifleriniz kalıcı olarak silinecektir.',
      profile: _companyProfile,
      confirmLabel: 'KALICI OLARAK SİL',
    );

    if (res.decision == RemovalDecision.restoreBackup && res.backup != null) {
      await RecoveryKeyBackupService().restoreToLocal(res.backup!);
      await _checkCompanyProfile();
      return;
    }

    if (res.decision == RemovalDecision.confirmDelete && mounted) {
      setState(() => _isLoading = true);
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

  @override
  Widget build(BuildContext context) {
    if (_companyProfile == null || _isEditingProfile) {
      if (_isLoading) {
        return const Scaffold(
          backgroundColor: AppTheme.blueprintDark,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.cyanLine),
          ),
        );
      }
      return CompanyProfileView(
        key: ValueKey('company_profile_$_profileViewEpoch'),
        onProfileSaved: () => _checkCompanyProfile(),
      );
    }

    if (!_isLoggedIn) {
      return QuickLoginView(
        profile: _companyProfile!,
        isLoading: _isLoading,
        onConnect: _connectSession,
        onEditProfile: () => setState(() => _isEditingProfile = true),
        onDeleteAccount: _deleteCurrentAccount,
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.blueprintDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.cyanLine),
        ),
      );
    }

    final bool isAdmin = _companyProfile != null &&
        (_companyProfile!.name.trim().toLowerCase().contains('ko|apps') ||
            _companyProfile!.name.trim().toLowerCase().contains('ko apps'));

    final List<Widget> pages = [
      const CompanySearchView(),
      const CompanySentOffersView(),
      CompanyProfileView(
        key: ValueKey('company_profile_$_profileViewEpoch'),
        onProfileSaved: () => _checkCompanyProfile(),
      ),
      if (isAdmin)
        CompanyAdminView(companyProfile: _companyProfile),
    ];

    final effectiveIndex = _currentIndex < pages.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: effectiveIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.steelBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: effectiveIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.saved_search),
              label: 'Aday Keşfet',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.outbox_outlined),
              activeIcon: Icon(Icons.outbox),
              label: 'Teklifler',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Şirket Profili',
            ),
            if (isAdmin)
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings_outlined),
                activeIcon: Icon(Icons.admin_panel_settings),
                label: '👑 Admin',
              ),
          ],
        ),
      ),
    );
  }
}
