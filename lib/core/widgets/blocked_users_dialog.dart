import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';

class BlockedUsersDialog extends StatefulWidget {
  final String currentRole; // 'draftsman' or 'company'
  final VoidCallback onUpdated;

  const BlockedUsersDialog({
    super.key,
    required this.currentRole,
    required this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, [
    String currentRole = 'company',
    VoidCallback? onUpdated,
  ]) {
    return showDialog(
      context: context,
      builder: (_) => BlockedUsersDialog(
        currentRole: currentRole,
        onUpdated: onUpdated ?? () {},
      ),
    );
  }

  static Future<void> showModal(
    BuildContext context, {
    bool isCompany = false,
    String currentRole = 'company',
    VoidCallback? onUnblocked,
    VoidCallback? onUpdated,
  }) {
    final role = isCompany ? 'company' : currentRole;
    final cb = onUnblocked ?? onUpdated ?? () {};
    return showDialog(
      context: context,
      builder: (_) => BlockedUsersDialog(
        currentRole: role,
        onUpdated: cb,
      ),
    );
  }

  @override
  State<BlockedUsersDialog> createState() => _BlockedUsersDialogState();
}

class _BlockedUsersDialogState extends State<BlockedUsersDialog> {
  final _localDb = LocalDbService();
  List<Map<String, dynamic>> _blockedList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    final list = await _localDb.getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedList = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblock(String id, String name) async {
    await _localDb.unblockUser(id);
    await _loadBlocked();
    widget.onUpdated();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.statusSuccess,
          content: Text('$name üzerindeki engel kaldırıldı.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompany = widget.currentRole == 'company';
    final targetLabel = isCompany ? 'Adaylar' : 'Şirketler';

    return AlertDialog(
      backgroundColor: AppTheme.blueprintDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.steelBorder),
      ),
      title: Row(
        children: [
          const Icon(Icons.block, color: AppTheme.statusDanger),
          const SizedBox(width: 8),
          Text(
            'Engellenen $targetLabel',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _blockedList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: AppTheme.statusSuccess.withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(
                          'Engellenen $targetLabel bulunmuyor.',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _blockedList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _blockedList[i];
                      final name = item['name'] as String? ?? 'Bilinmeyen';
                      final id = item['id'] as String? ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.blueprintSurface,
                          child: Icon(Icons.person_off, size: 18, color: AppTheme.statusDanger),
                        ),
                        title: Text(name, style: const TextStyle(color: AppTheme.textLight, fontSize: 13)),
                        subtitle: Text(
                          id.length > 20 ? '${id.substring(0, 20)}...' : id,
                          style: const TextStyle(color: AppTheme.textSubtle, fontSize: 11, fontFamily: 'monospace'),
                        ),
                        trailing: TextButton(
                          onPressed: () => _unblock(id, name),
                          child: const Text('Engeli Kaldır', style: TextStyle(color: AppTheme.cyanLine, fontSize: 12)),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
