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
        title: Text(subject.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
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
                  leading: Icon(Icons.edit),
                  title: Text('تعديل المادة'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
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
            // Subject summary
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book, size: 36),
                title: Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  [
                    if (subject.code != null) subject.code!,
                    '${subjectSessions.length} جلسة',
                  ].join(' • '),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'الجلسات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (sessions.isLoading && sessions.value == null)
              const Center(child: CircularProgressIndicator())
            else if (subjectSessions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'لا توجد جلسات لهذه المادة بعد.\nاضغط "بدء جلسة" لإنشاء أول جلسة.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
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
