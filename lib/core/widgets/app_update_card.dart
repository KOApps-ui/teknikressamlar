import 'package:flutter/material.dart';
import '../constants/app_version.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../views/app_update_view.dart';

class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard({super.key});

  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  final _updateService = UpdateService();
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkSilently();
  }

  Future<void> _checkSilently() async {
    try {
      final info = await _updateService.checkForUpdate(force: false);
      if (mounted && info != null) {
        setState(() {
          _hasUpdate = info.hasUpdate;
        });
      }
    } catch (_) {}
  }

  void _openUpdateCenter() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppUpdateView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.blueprintSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasUpdate
              ? AppTheme.amberSteel.withValues(alpha: 0.8)
              : AppTheme.cyanLine.withValues(alpha: 0.35),
          width: _hasUpdate ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (_hasUpdate ? AppTheme.amberSteel : AppTheme.cyanLine).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openUpdateCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (_hasUpdate ? AppTheme.amberSteel : AppTheme.cyanLine).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_hasUpdate ? AppTheme.amberSteel : AppTheme.cyanLine).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    _hasUpdate ? Icons.system_update : Icons.system_update_alt,
                    color: _hasUpdate ? AppTheme.amberSteel : AppTheme.cyanLine,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'KO|Apps Teknik Ressamlar',
                            style: TextStyle(
                              color: AppTheme.textLight,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_hasUpdate)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.amberSteel,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YENİ SÜRÜM',
                                style: TextStyle(
                                  color: AppTheme.blueprintDark,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Yüklü: v${AppVersion.version} • Güncelleme Merkezi',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasUpdate ? AppTheme.amberSteel : AppTheme.cyanLine.withValues(alpha: 0.2),
                    foregroundColor: _hasUpdate ? AppTheme.blueprintDark : AppTheme.cyanLine,
                    elevation: _hasUpdate ? 2 : 0,
                    side: _hasUpdate ? null : const BorderSide(color: AppTheme.cyanLine),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(
                    _hasUpdate ? Icons.download : Icons.arrow_forward_ios,
                    size: 12,
                  ),
                  label: Text(
                    _hasUpdate ? 'GÜNCELLE' : 'AÇ',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _openUpdateCenter,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
