import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/p2p_service.dart';

class BlueprintHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final Widget? leading;
  final bool showLogo;

  const BlueprintHeader({
    super.key,
    required this.title,
    this.trailing,
    this.leading,
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final p2pService = P2PService();

    return AppBar(
      titleSpacing: 16,
      leading: leading,
      title: Row(
        children: [
          if (showLogo) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.blueprintDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cyanLine.withValues(alpha: 0.7), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                StreamBuilder<String>(
                  stream: p2pService.connectionStatusStream,
                  builder: (context, snapshot) {
                    final isOnline = p2pService.isConnected;
                    final status = isOnline ? p2pService.connectionStatus : (snapshot.data ?? 'P2P Bağlanıyor...');
                    return Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isOnline ? AppTheme.statusSuccess : AppTheme.amberSteel,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: isOnline ? AppTheme.cyanLine : AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: trailing != null ? [trailing!, const SizedBox(width: 12)] : null,
    );
  }
}
