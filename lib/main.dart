import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/models/user_profile.dart';
import 'core/services/local_db_service.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_mode_selector_view.dart';
import 'draftsman/draftsman_app.dart';
import 'company/company_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.blueprintSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final localDb = LocalDbService();
  await localDb.init();
  await NotificationService().init();
  BackgroundService.init();

  runApp(const TeknikRessamlarApp());
}

class TeknikRessamlarApp extends StatefulWidget {
  const TeknikRessamlarApp({super.key});

  static TeknikRessamlarAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<TeknikRessamlarAppState>();

  static void resetToModeSelector(BuildContext context) {
    final state = of(context);
    state?.resetUser();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AppModeSelectorView(
          onSelected: () => state?.reloadUser(),
        ),
      ),
      (route) => false,
    );
  }

  @override
  State<TeknikRessamlarApp> createState() => TeknikRessamlarAppState();
}

class TeknikRessamlarAppState extends State<TeknikRessamlarApp> {
  final _localDb = LocalDbService();
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void resetUser() {
    if (mounted) {
      setState(() {
        _profile = null;
        _isLoading = false;
      });
    }
  }

  Future<void> reloadUser() async {
    setState(() => _isLoading = true);
    await _loadUser();
  }

  Future<void> _loadUser() async {
    final profile = await _localDb.getUserProfile();
    final isLoggedIn = await _localDb.isUserLoggedIn();
    if (profile != null && isLoggedIn) {
      BackgroundService.start(profile);
    }
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KO|Apps - Teknik Ressamlar & İşveren',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _isLoading
          ? const Scaffold(
              backgroundColor: AppTheme.blueprintDark,
              body: Center(child: CircularProgressIndicator(color: AppTheme.cyanLine)),
            )
          : _profile != null
              ? (_profile!.role == 'company' ? const CompanyApp() : const DraftsmanApp())
              : AppModeSelectorView(onSelected: () => _loadUser()),
    );
  }
}

