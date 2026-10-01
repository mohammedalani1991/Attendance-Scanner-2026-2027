import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/session.dart';
import '../models/subject.dart';
import '../providers/session_provider.dart';
import '../providers/subject_provider.dart';
import '../widgets/session_list_tile.dart';
import '../widgets/subject_form_dialog.dart';
import 'scanner_screen.dart';

/// Subject summary: coloured initial, name, code and session counts
class _SubjectHeader extends StatelessWidget {
  final Subject subject;
  final List<Session> sessions; // Newest first
  final bool blockedByOtherSession;

  const _SubjectHeader({
    required this.subject,
    required this.sessions,
    required this.blockedByOtherSession,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Same colour as the subject's card on the home screen
    final accent = Colors.primaries[(subject.id ?? 0) % Colors.primaries.length];
    final initial = subject.name.trim().isEmpty ? '?' : subject.name.trim()[0];
    final lastDate = sessions.isEmpty
        ? '—'
        : formatSessionDateTime(sessions.first.timestampStart).split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: accent.withAlpha(40),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: accent.shade700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (subject.code != null)
                    Text(
                      subject.code!,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          color: colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _HeaderStat(label: 'الجلسات', value: '${sessions.length}'),
                SizedBox(
                  height: 32,
                  child: VerticalDivider(color: colors.outlineVariant),
                ),
                _HeaderStat(label: 'آخر جلسة', value: lastDate),
              ],
            ),
          ),
        ),
        // Explain why "start session" will be refused
        if (blockedByOtherSession) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'توجد جلسة نشطة في مادة أخرى. أنهِها أولاً لبدء جلسة هنا.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown before the subject's first session
class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text(
            'لا توجد جلسات بعد',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'اضغط "بدء جلسة" لإنشاء أول جلسة وبدء تسجيل الحضور.',
            style: TextStyle(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Screen for one subject: its sessions and starting a new one
class SubjectScreen extends ConsumerWidget {
  final int subjectId;

  const SubjectScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Look the subject up from the provider so a rename shows immediately
    final subject = _findSubject(ref.watch(subjectsProvider).value);
    final sessions = ref.watch(sessionsProvider);
    final activeSession = ref.watch(activeSessionProvider).value;

    if (subject == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final subjectSessions = (sessions.value ?? [])
        .where((session) => session.subjectId == subjectId)
        .toList();
    final isActiveHere = activeSession?.subjectId == subjectId;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'تصدير الحضور',
            onPressed: subjectSessions.isEmpty
                ? null
                : () => _exportSubject(context, ref, subject),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editSubject(context, ref, subject);
              } else if (value == 'delete') {
                _deleteSubject(context, ref, subject, subjectSessions);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('تعديل المادة'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('حذف المادة', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(sessionsProvider.notifier).loadSessions(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _SubjectHeader(
              subject: subject,
              sessions: subjectSessions,
              blockedByOtherSession: activeSession != null && !isActiveHere,
            ),
            const SizedBox(height: 24),
            Text(
              'الجلسات',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (sessions.isLoading && sessions.value == null)
              const Center(child: CircularProgressIndicator())
            else if (subjectSessions.isEmpty)
              const _EmptySessions()
            else
              ...subjectSessions.map(
                (session) => SessionListTile(
                  key: ValueKey('subject_session_${session.id}'),
                  session: session,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isActiveHere
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('مسح'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _startSession(context, ref, subject,
                  activeSession, subjectSessions.length),
              icon: const Icon(Icons.play_arrow),
              label: const Text('بدء جلسة'),
            ),
    );
  }

  Subject? _findSubject(List<Subject>? subjects) {
    for (final subject in subjects ?? const <Subject>[]) {
      if (subject.id == subjectId) return subject;
    }
    return null;
  }

  Future<void> _startSession(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
    Session? activeSession,
    int existingSessionCount,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    // Only one session can be active at a time
    if (activeSession != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'توجد جلسة نشطة بالفعل: ${activeSession.courseName}. '
            'الرجاء إنهاؤها قبل بدء جلسة جديدة.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // The name becomes the column header in the subject export
    final titleController =
        TextEditingController(text: 'محاضرة ${existingSessionCount + 1}');
    final notesController = TextEditingController();
    String? titleError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('بدء جلسة: ${subject.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'اسم الجلسة',
                  hintText: 'مثال: محاضرة 1',
                  errorText: titleError,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  hintText: 'مثال: اختبار نصفي',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  setDialogState(() => titleError = 'الرجاء إدخال اسم الجلسة');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('بدء'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    titleController.dispose();
    notesController.dispose();

    if (confirmed != true) return;

    final result = await ref.read(activeSessionProvider.notifier).startSession(
          subject: subject,
          title: title,
          notes: notes.isEmpty ? null : notes,
        );

    if (result.success) {
      ref.read(sessionsProvider.notifier).loadSessions();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم بدء الجلسة بنجاح')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'فشل بدء الجلسة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportSubject(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Blocking progress dialog while the file is built
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('جاري تصدير حضور المادة...')),
          ],
        ),
      ),
    );

    try {
      final filePath = await ref
          .read(sessionServiceProvider)
          .exportSubjectAttendance(subject.id!);
      navigator.pop();
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Attendance - ${subject.name}',
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل التصدير: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editSubject(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final values = await showSubjectFormDialog(context, initial: subject);
    if (values == null) return;

    // Built directly (not copyWith) so the code can be cleared
    final error = await ref.read(subjectsProvider.notifier).updateSubject(
          Subject(
            id: subject.id,
            name: values.name,
            code: values.code,
            createdAt: subject.createdAt,
          ),
        );

    if (error == null) {
      // Sessions and the active session carry the subject name
      ref.read(sessionsProvider.notifier).loadSessions();
      ref.read(activeSessionProvider.notifier).loadActiveSession();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تعديل المادة')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteSubject(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
    List<Session> subjectSessions,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المادة'),
        content: Text(
          'هل أنت متأكد من حذف "${subject.name}"؟\n\n'
          'سيؤدي هذا إلى حذف ${subjectSessions.length} جلسة وجميع سجلات الحضور الخاصة بها نهائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sessionsNotifier = ref.read(sessionsProvider.notifier);
    final activeSessionNotifier = ref.read(activeSessionProvider.notifier);
    final error =
        await ref.read(subjectsProvider.notifier).deleteSubject(subject.id!);

    if (error == null) {
      sessionsNotifier.loadSessions();
      // The active session may have belonged to this subject
      activeSessionNotifier.loadActiveSession();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم حذف المادة'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }
}
