import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/user_profile.dart';
import '../core/services/local_db_service.dart';
import '../core/services/p2p_service.dart';
import '../core/services/background_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/quick_login_view.dart';
import 'views/draftsman_profile_view.dart';
import 'views/draftsman_offers_view.dart';

class DraftsmanApp extends StatefulWidget {
  const DraftsmanApp({super.key});

  @override
  State<DraftsmanApp> createState() => _DraftsmanAppState();
}

class _DraftsmanAppState extends State<DraftsmanApp> with WidgetsBindingObserver {
  final _localDb = LocalDbService();
  final _p2pService = P2PService();

  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isLoggedIn = true;
  bool _isEditingProfile = false;
  int _currentIndex = 0;
  int _pendingOffersCount = 0;
  StreamSubscription? _offerSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUserProfile();
    _refreshPendingOffersCount();

    _offerSub = _p2pService.incomingOfferStream.listen((offer) {
      _refreshPendingOffersCount();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.amberSteel,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.mark_email_unread, color: AppTheme.blueprintDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '📬 YENİ İŞ TEKLİFİ: ${offer.companyName} (${offer.budget})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.blueprintDark),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'İNCELE',
              textColor: AppTheme.blueprintDark,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                setState(() => _currentIndex = 1);
              },
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offerSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _p2pService.resume();
      _refreshPendingOffersCount();
    }
  }

  Future<void> _refreshPendingOffersCount() async {
    final offers = await _localDb.getOffers();
    final count = offers.where((o) => o.status == 'pending').length;
    if (mounted) {
      setState(() => _pendingOffersCount = count);
    }
  }

  Future<void> _checkUserProfile() async {
    final profile = await _localDb.getUserProfile();
    final loggedIn = await _localDb.isUserLoggedIn();

    if (profile != null && loggedIn) {
      await _p2pService.start(userProfile: profile);
      await BackgroundService.start(profile);
    }

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoggedIn = loggedIn;
        _isLoading = false;
        _isEditingProfile = false;
      });
    }
  }

  Future<void> _connectSession() async {
    if (_userProfile == null) return;
    setState(() => _isLoading = true);
    await _localDb.setLoggedIn(true);
    await _p2pService.start(userProfile: _userProfile!);
    await BackgroundService.start(_userProfile!);
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

    if (_userProfile == null || _isEditingProfile) {
      return DraftsmanProfileView(
        onProfileSaved: () => _checkUserProfile(),
      );
    }

    if (!_isLoggedIn) {
      return QuickLoginView(
        profile: _userProfile!,
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
          await _checkUserProfile();
        },
      );
    }

    final List<Widget> pages = [
      DraftsmanProfileView(onProfileSaved: () => _checkUserProfile()),
      const DraftsmanOffersView(),
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
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined),
              activeIcon: Icon(Icons.badge),
              label: 'Profilim & Portföy',
            ),
            BottomNavigationBarItem(
              icon: _pendingOffersCount > 0
                  ? Badge(
                      label: Text('$_pendingOffersCount'),
                      backgroundColor: AppTheme.amberSteel,
                      textColor: AppTheme.blueprintDark,
                      child: const Icon(Icons.mail_outline),
                    )
                  : const Icon(Icons.mail_outline),
              activeIcon: _pendingOffersCount > 0
                  ? Badge(
                      label: Text('$_pendingOffersCount'),
                      backgroundColor: AppTheme.amberSteel,
                      textColor: AppTheme.blueprintDark,
                      child: const Icon(Icons.mail),
                    )
                  : const Icon(Icons.mail),
              label: 'Gelen Teklifler',
            ),
          ],
        ),
      ),
    );
  }
}
