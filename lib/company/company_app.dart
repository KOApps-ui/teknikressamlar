import 'package:flutter/material.dart';
import '../core/models/user_profile.dart';
import '../core/services/local_db_service.dart';
import '../core/services/p2p_service.dart';
import '../core/services/background_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/quick_login_view.dart';
import 'views/company_search_view.dart';
import 'views/company_sent_offers_view.dart';
import 'views/company_profile_view.dart';

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
    final profile = await _localDb.getUserProfile();
    final loggedIn = await _localDb.isUserLoggedIn();

    if (profile != null && loggedIn) {
      await _p2pService.start(userProfile: profile);
      await _p2pService.listenBranch('all');
      await _p2pService.scanNetwork();
      await BackgroundService.start(profile);
    }

    if (mounted) {
      setState(() {
        _companyProfile = profile;
        _isLoggedIn = loggedIn;
        _isLoading = false;
        _isEditingProfile = false;
      });
    }
  }

  Future<void> _connectSession() async {
    if (_companyProfile == null) return;
    setState(() => _isLoading = true);
    await _localDb.setLoggedIn(true);
    await _p2pService.start(userProfile: _companyProfile!);
    await _p2pService.listenBranch('all');
    await _p2pService.scanNetwork();
    await BackgroundService.start(_companyProfile!);
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.blueprintDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.cyanLine),
        ),
      );
    }

    if (_companyProfile == null || _isEditingProfile) {
      return CompanyProfileView(
        onProfileSaved: () => _checkCompanyProfile(),
      );
    }

    if (!_isLoggedIn) {
      return QuickLoginView(
        profile: _companyProfile!,
        isLoading: _isLoading,
        onConnect: _connectSession,
        onEditProfile: () => setState(() => _isEditingProfile = true),
        onSwitchAccount: () => setState(() {
          _isEditingProfile = true;
        }),
        onDeleteAccount: () async {
          await BackgroundService.stop();
          await _p2pService.dispose();
          await _localDb.deleteUserProfile();
          await _localDb.clearAllOffers();
          await _checkCompanyProfile();
        },
      );
    }

    final List<Widget> pages = [
      const CompanySearchView(),
      const CompanySentOffersView(),
      CompanyProfileView(onProfileSaved: () => _checkCompanyProfile()),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.steelBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.saved_search),
              label: 'Aday Keşfet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.outbox_outlined),
              activeIcon: Icon(Icons.outbox),
              label: 'Teklifler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Şirket Profili',
            ),
          ],
        ),
      ),
    );
  }
}
