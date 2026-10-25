import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'blueprint_header.dart';
import '../../draftsman/draftsman_app.dart';
import '../../company/company_app.dart';

class AppModeSelectorView extends StatelessWidget {
  final VoidCallback onSelected;

  const AppModeSelectorView({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BlueprintHeader(title: 'KO|Apps Platform Seçimi'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Hoş Geldiniz',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lütfen kullanmak istediğiniz bağımsız uygulama modunu seçin. Sistemler sıfır sunucu ve gizlilik prensibiyle birbirinden tamamen izoledir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Draftsman Mode Card
              _buildRoleCard(
                context: context,
                icon: Icons.architecture,
                title: 'TEKNİK RESSAM UYGULAMASI',
                subtitle: 'Kendi profilinizi ve DWG/DXF/PDF çizimlerinizi yönetin. Şirketlerden gelen teklifleri inceleyin.',
                badge: 'Tamamen Gizli & Pasif',
                primaryColor: AppTheme.cyanLine,
                buttonText: 'Ressam Olarak Başla',
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DraftsmanApp()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Company Mode Card
              _buildRoleCard(
                context: context,
                icon: Icons.business,
                title: 'İŞVEREN ŞİRKET UYGULAMASI',
                subtitle: 'Çelik, betonarme, harita, mekanik branşlarındaki aktif ressamları P2P ile keşfedin ve doğrudan teklif verin.',
                badge: 'Doğrudan Teklif & Arama',
                primaryColor: AppTheme.amberSteel,
                buttonText: 'İşveren Şirket Olarak Başla',
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CompanyApp()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color primaryColor,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      badge,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: AppTheme.blueprintDark,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onTap,
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
