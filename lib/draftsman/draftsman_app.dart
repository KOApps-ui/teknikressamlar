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
import '../core/widgets/app_mode_selector_view.dart';
import '../core/services/recovery_key_backup_service.dart';
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
  int _profileViewEpoch = 0;
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
    _profileViewEpoch++;
    try {
      final profile = await _localDb.getUserProfile();
      final loggedIn = await _localDb.isUserLoggedIn();

      if (profile != null && loggedIn) {
        await _p2pService.start(userProfile: profile).timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            debugPrint('Draftsman P2PService start timed out; continuing in background');
          },
        );
        unawaited(BackgroundService.start(profile));
      }

      if (mounted) {
        setState(() {
          _userProfile = profile;
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
      debugPrint('Error in _checkUserProfile: $e\n$stack');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectSession() async {
    if (_userProfile == null) return;
    setState(() => _isLoading = true);
    try {
      await _localDb.setLoggedIn(true);
      await _p2pService.start(userProfile: _userProfile!).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Draftsman P2PService start timed out after 4s; continuing in background');
        },
      );
      unawaited(BackgroundService.start(_userProfile!));
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
      title: 'Profili Kalıcı Olarak Sil',
      message:
          'Profiliniz, kriptografik anahtarlarınız ve bu cihazdaki teklifleriniz kalıcı olarak silinecektir.',
      profile: _userProfile,
      confirmLabel: 'KALICI OLARAK SİL',
    );
    final handled = await _handleRemovalResult(res);
    if (handled) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    await BackgroundService.stop();
    await _p2pService.dispose();
    await _localDb.deleteUserProfile();
    await _localDb.clearAllOffers();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AppModeSelectorView(
          onSelected: () {},
        ),
      ),
      (route) => false,
    );
  }

  /// Returns true when the removal was cancelled or the account was restored.
  Future<bool> _handleRemovalResult(RemovalResult res) async {
    if (res.decision == RemovalDecision.restoreBackup && res.backup != null) {
      await RecoveryKeyBackupService().restoreToLocal(res.backup!);
      await _checkUserProfile();
      return true;
    }
    return res.decision != RemovalDecision.confirmDelete;
  }

  @override
  Widget build(BuildContext context) {
    if (_userProfile == null || _isEditingProfile) {
      if (_isLoading) {
        return const Scaffold(
          backgroundColor: AppTheme.blueprintDark,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.cyanLine),
          ),
        );
      }
      return DraftsmanProfileView(
        key: ValueKey('draftsman_profile_$_profileViewEpoch'),
        onProfileSaved: () => _checkUserProfile(),
      );
    }

    if (!_isLoggedIn) {
      return QuickLoginView(
        profile: _userProfile!,
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

    final List<Widget> pages = [
      DraftsmanProfileView(
        key: ValueKey('draftsman_profile_$_profileViewEpoch'),
        onProfileSaved: () => _checkUserProfile(),
      ),
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
