import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'blueprint_header.dart';

class QuickLoginView extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onConnect;
  final VoidCallback onEditProfile;
  final VoidCallback onSwitchAccount;
  final VoidCallback onDeleteAccount;
  final bool isLoading;

  const QuickLoginView({
    super.key,
    required this.profile,
    required this.onConnect,
    required this.onEditProfile,
    required this.onSwitchAccount,
    required this.onDeleteAccount,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompany = profile.role == 'company';
    final accentColor = isCompany ? AppTheme.amberSteel : AppTheme.cyanLine;

    ImageProvider? imageProvider;
    if (profile.avatarPath != null && File(profile.avatarPath!).existsSync()) {
      imageProvider = FileImage(File(profile.avatarPath!));
    } else if (profile.avatarBase64 != null && profile.avatarBase64!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(profile.avatarBase64!));
      } catch (_) {}
    }

    final initials = profile.name.isNotEmpty
        ? profile.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : (isCompany ? 'Ş' : 'TR');

    return Scaffold(
      backgroundColor: AppTheme.blueprintDark,
      appBar: BlueprintHeader(
        title: isCompany ? 'ŞİRKET OTURUMU' : 'RESSAM OTURUMU',
        showLogo: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_clock_outlined, size: 14, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Kayıtlı Profil Cihazda Hazır',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Identity Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.blueprintSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: AppTheme.blueprintDark,
                              backgroundImage: imageProvider,
                              child: imageProvider == null
                                  ? Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (profile.isVerified)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.statusSuccess,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified, size: 18, color: Colors.white),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        profile.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textLight,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Title & Branch
                      Text(
                        profile.title.isNotEmpty ? profile.title : (isCompany ? 'Kurumsal İşveren' : 'Teknik Ressam'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        '${profile.branch} • ${profile.city.isNotEmpty ? profile.city : 'Türkiye'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),

                      if (profile.verificationBadge != null && profile.verificationBadge!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cyanLine.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 13, color: AppTheme.cyanLine),
                              const SizedBox(width: 5),
                              Text(
                                profile.verificationBadge!,
                                style: const TextStyle(fontSize: 11, color: AppTheme.cyanLine, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.steelBorder),
                      const SizedBox(height: 10),

                      // DID Identity info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.vpn_key_outlined, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            profile.publicKey.length >= 16
                                ? 'Anahtar: ${profile.publicKey.substring(0, 8)}...${profile.publicKey.substring(profile.publicKey.length - 8)}'
                                : 'Kriptografik DID Hazır',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Main Connect Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: AppTheme.blueprintDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blueprintDark),
                          )
                        : const Icon(Icons.power_settings_new, size: 22),
                    label: Text(
                      isCompany ? 'ŞİRKET AĞINA BAĞLAN & GİRİŞ YAP' : 'AĞA BAĞLAN & GİRİŞ YAP',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                    ),
                    onPressed: isLoading ? null : onConnect,
                  ),
                ),
                const SizedBox(height: 14),

                // Secondary Action: Edit Profile
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textLight,
                      side: const BorderSide(color: AppTheme.steelBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Profili / Bilgileri Düzenle'),
                    onPressed: onEditProfile,
                  ),
                ),
                const SizedBox(height: 10),

                // Switch Account or Delete
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppTheme.cyanLine),
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                        label: const Text('Yeni Profil Aç', style: TextStyle(fontSize: 12)),
                        onPressed: onSwitchAccount,
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppTheme.statusDanger),
                        icon: const Icon(Icons.delete_forever_outlined, size: 16),
                        label: const Text('Profili Sil', style: TextStyle(fontSize: 12)),
                        onPressed: onDeleteAccount,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
