import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import '../screens/session_detail_screen.dart';

/// Session row with swipe-to-delete, shared by the home and all-sessions screens
class SessionListTile extends ConsumerWidget {
  final Session session;

  /// Show the subject name in the subtitle (for lists that mix subjects)
  final bool showSubject;

  const SessionListTile({
    super.key,
    required this.session,
    this.showSubject = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('session_${session.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20.0),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: colors.onError),
      ),
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (direction) => _deleteSession(context, ref),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: session.isActive
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.green, width: 2),
              )
            : null,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: session.isActive
                ? Colors.green.withAlpha(35)
                : colors.surfaceContainerHighest,
            child: Icon(
              session.isActive ? Icons.play_arrow : Icons.check,
              color: session.isActive ? Colors.green : colors.onSurfaceVariant,
            ),
          ),
          title: Text(
            session.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            showSubject
                ? '${session.courseName} • ${formatSessionDateTime(session.timestampStart)}'
                : formatSessionDateTime(session.timestampStart),
          ),
          trailing: session.isActive
              ? const Text(
                  'نشطة',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          onTap: () => _openDetails(context, ref),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجلسة'),
        content: Text(
          'هل أنت متأكد من حذف "${session.displayName}" (${session.courseName})؟\n\n'
          'سيؤدي هذا إلى حذف الجلسة وجميع سجلات الحضور الخاصة بها نهائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(BuildContext context, WidgetRef ref) async {
    // The tile leaves the tree once dismissed, so read everything before awaiting
    final messenger = ScaffoldMessenger.of(context);
    final sessionsNotifier = ref.read(sessionsProvider.notifier);
    final activeSessionNotifier = ref.read(activeSessionProvider.notifier);

    final success = await sessionsNotifier.deleteSession(session.id!);

    if (success) {
      // The deleted session may have been the active one
      if (session.isActive) {
        activeSessionNotifier.loadActiveSession();
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم حذف الجلسة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('فشل حذف الجلسة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openDetails(BuildContext context, WidgetRef ref) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailScreen(sessionId: session.id!),
      ),
    );
    if (deleted == true && context.mounted) {
      ref.read(sessionsProvider.notifier).loadSessions();
      ref.read(activeSessionProvider.notifier).loadActiveSession();
    }
  }
}

/// Format a session timestamp as d/m/yyyy HH:mm
String formatSessionDateTime(DateTime dateTime) {
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}
