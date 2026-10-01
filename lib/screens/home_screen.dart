import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../models/subject.dart';
import '../providers/session_provider.dart';
import '../providers/student_provider.dart';
import '../providers/subject_provider.dart';
import '../widgets/session_list_tile.dart';
import '../widgets/subject_form_dialog.dart';
import 'all_sessions_screen.dart';
import 'import_students_screen.dart';
import 'scanner_screen.dart';
import 'session_detail_screen.dart';
import 'subject_screen.dart';

/// Home dashboard: the active session (if any), a compact summary, and the subjects.
/// Each action appears once; the floating button changes with context.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider).value;
    final sessions = ref.watch(sessionsProvider);
    final students = ref.watch(studentsProvider);
    final subjects = ref.watch(subjectsProvider);

    final sessionList = sessions.value ?? const <Session>[];
    final noStudentsYet = students.hasValue && students.value!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'سجل الجلسات',
            onPressed: () => _push(context, const AllSessionsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'الطلاب',
            onPressed: () => _push(context, const ImportStudentsScreen()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (activeSession != null) ...[
              _ActiveSessionCard(
                session: activeSession,
                onDetails: () => _openSessionDetails(context, ref, activeSession),
                onEnd: () => _showEndSessionDialog(context, ref),
              ),
              const SizedBox(height: 16),
            ],
            if (noStudentsYet) ...[
              _NoStudentsBanner(
                onImport: () => _push(context, const ImportStudentsScreen()),
              ),
              const SizedBox(height: 16),
            ],
            _SummaryStrip(
              studentCount: students.value?.length ?? 0,
              subjectCount: subjects.value?.length ?? 0,
              sessionCount: sessionList.length,
              onStudentsTap: () =>
                  _push(context, const ImportStudentsScreen()),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'المواد',
              subtitle: activeSession == null &&
                      (subjects.value?.isNotEmpty ?? false)
                  ? 'اختر مادة لبدء جلسة جديدة'
                  : null,
              // The floating button adds subjects unless a session is running
              action: activeSession != null
                  ? IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      tooltip: 'مادة جديدة',
                      onPressed: () => _addSubject(context, ref),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            subjects.when(
              data: (subjectList) {
                if (subjectList.isEmpty) {
                  return _EmptySubjects(
                    onAdd: () => _addSubject(context, ref),
                  );
                }
                return Column(
                  children: [
                    for (final subject in subjectList)
                      _SubjectCard(
                        subject: subject,
                        sessions: sessionList
                            .where((s) => s.subjectId == subject.id)
                            .toList(),
                        isActive: activeSession?.subjectId == subject.id,
                        onTap: () => _push(
                          context,
                          SubjectScreen(subjectId: subject.id!),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text('خطأ: $error'),
            ),
          ],
        ),
      ),
      floatingActionButton: activeSession != null
          ? FloatingActionButton.extended(
              onPressed: () => _push(context, const ScannerScreen()),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('مسح'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _addSubject(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('مادة جديدة'),
            ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(activeSessionProvider.notifier).loadActiveSession(),
      ref.read(sessionsProvider.notifier).loadSessions(),
      ref.read(studentsProvider.notifier).loadStudents(),
      ref.read(subjectsProvider.notifier).loadSubjects(),
    ]);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _openSessionDetails(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailScreen(sessionId: session.id!),
      ),
    );
    // Deleting the active session must clear it here too
    if (deleted == true) {
      ref.read(sessionsProvider.notifier).loadSessions();
      ref.read(activeSessionProvider.notifier).loadActiveSession();
    }
  }

  Future<void> _addSubject(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final values = await showSubjectFormDialog(context);
    if (values == null) return;

    final error = await ref
        .read(subjectsProvider.notifier)
        .addSubject(name: values.name, code: values.code);

    messenger.showSnackBar(
      error == null
          ? SnackBar(content: Text('تمت إضافة المادة "${values.name}"'))
          : SnackBar(content: Text(error), backgroundColor: Colors.red),
    );
  }

  void _showEndSessionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الجلسة'),
        content: const Text('هل أنت متأكد من إنهاء هذه الجلسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final result =
                  await ref.read(activeSessionProvider.notifier).endSession();

              if (context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                if (result.success) {
                  ref.read(sessionsProvider.notifier).loadSessions();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('تم إنهاء الجلسة بنجاح')),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'فشل إنهاء الجلسة'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('إنهاء الجلسة'),
          ),
        ],
      ),
    );
  }
}

/// Highlighted card for the running session, with a live count of scanned students
class _ActiveSessionCard extends ConsumerWidget {
  final Session session;
  final VoidCallback onDetails;
  final VoidCallback onEnd;

  const _ActiveSessionCard({
    required this.session,
    required this.onDetails,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final presentCount =
        ref.watch(attendanceRecordsProvider).value?.length ?? 0;
    final start = session.timestampStart;
    final startTime =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'جلسة نشطة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.schedule, size: 16, color: colors.onPrimaryContainer),
                const SizedBox(width: 4),
                Text(
                  'بدأت $startTime',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              session.courseName,
              style: textTheme.titleSmall?.copyWith(
                color: colors.onPrimaryContainer.withAlpha(190),
              ),
            ),
            Text(
              session.displayName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.how_to_reg, color: colors.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  '$presentCount طالب حاضر',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.list_alt),
                    label: const Text('التفاصيل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEnd,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('إنهاء الجلسة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// First-run hint shown until a student list is imported
class _NoStudentsBanner extends StatelessWidget {
  final VoidCallback onImport;

  const _NoStudentsBanner({required this.onImport});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'لم يتم استيراد قائمة الطلاب بعد. استوردها لتتمكن من تسجيل الحضور.',
                style: TextStyle(color: colors.onTertiaryContainer),
              ),
            ),
            TextButton(
              onPressed: onImport,
              child: const Text('استيراد'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One compact row of counts instead of large statistic cards
class _SummaryStrip extends StatelessWidget {
  final int studentCount;
  final int subjectCount;
  final int sessionCount;
  final VoidCallback onStudentsTap;

  const _SummaryStrip({
    required this.studentCount,
    required this.subjectCount,
    required this.sessionCount,
    required this.onStudentsTap,
  });

  @override
  Widget build(BuildContext context) {
    final divider = SizedBox(
      height: 36,
      child: VerticalDivider(color: Theme.of(context).dividerColor),
    );

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _SummaryItem(
            icon: Icons.groups_outlined,
            value: studentCount,
            label: 'الطلاب',
            onTap: onStudentsTap,
          ),
          divider,
          _SummaryItem(
            icon: Icons.menu_book_outlined,
            value: subjectCount,
            label: 'المواد',
          ),
          divider,
          _SummaryItem(
            icon: Icons.event_note_outlined,
            value: sessionCount,
            label: 'الجلسات',
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final VoidCallback? onTap;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const _SectionHeader({required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// Subject row: coloured initial, name/code, session summary, active badge
class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final List<Session> sessions; // Newest first, as loaded
  final bool isActive;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.sessions,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // A stable colour per subject makes the list easy to scan
    final accent = Colors.primaries[(subject.id ?? 0) % Colors.primaries.length];
    final initial = subject.name.trim().isEmpty ? '?' : subject.name.trim()[0];

    final details = sessions.isEmpty
        ? 'لا توجد جلسات بعد'
        : '${sessions.length} جلسة • آخر جلسة ${formatSessionDateTime(sessions.first.timestampStart).split(' ').first}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green : colors.outlineVariant,
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accent.withAlpha(40),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accent.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subject.name,
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subject.code != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            subject.code!,
                            style: textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'نشطة',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown before the first subject is added
class _EmptySubjects extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptySubjects({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text(
            'لا توجد مواد بعد',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'أضف مادة، ثم ابدأ الجلسات بداخلها.',
            style: TextStyle(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول مادة'),
          ),
        ],
      ),
    );
  }
}
