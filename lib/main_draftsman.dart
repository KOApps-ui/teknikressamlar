import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/local_db_service.dart';
import 'core/theme/app_theme.dart';
import 'draftsman/draftsman_app.dart';

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

  runApp(const TeknikRessamStandaloneApp());
}

class TeknikRessamStandaloneApp extends StatelessWidget {
  const TeknikRessamStandaloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KO|Apps - Teknik Ressam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DraftsmanApp(),
    );
  }
}
