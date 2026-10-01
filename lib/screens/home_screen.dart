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

/// Home dashboard screen - main entry point of the app
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final sessions = ref.watch(sessionsProvider);
    final students = ref.watch(studentsProvider);
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح الحضور'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(activeSessionProvider.notifier).loadActiveSession();
              ref.read(sessionsProvider.notifier).loadSessions();
              ref.read(studentsProvider.notifier).loadStudents();
              ref.read(subjectsProvider.notifier).loadSubjects();
            },
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active session card
            _buildActiveSessionCard(context, ref, activeSession),
            const SizedBox(height: 24),

            // Quick actions
            _buildQuickActions(context, ref, activeSession, students),
            const SizedBox(height: 24),

            // Statistics
            _buildStatistics(students, subjects, sessions),
            const SizedBox(height: 24),

            // Subjects (sessions are created inside a subject)
            _buildSubjects(context, ref, subjects, sessions, activeSession),
          ],
        ),
      ),
      floatingActionButton: activeSession.value != null
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
              onPressed: () => _addSubject(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مادة'),
            ),
    );
  }

  Widget _buildActiveSessionCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> activeSession,
  ) {
    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لا توجد جلسة نشطة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'لبدء تسجيل الحضور، اختر مادة من القائمة أدناه ثم اضغط "بدء جلسة". '
                    'إذا لم تكن هناك مواد، أضف مادة أولاً.',
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.green, size: 12),
                    const SizedBox(width: 8),
                    const Text(
                      'جلسة نشطة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.courseName} — ${session.displayName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'بدأت: ${formatSessionDateTime(session.timestampStart)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ملاحظات: ${session.notes}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final deleted = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SessionDetailScreen(sessionId: session.id!),
                          ),
                        );
                        // Deleting the active session must clear it here too
                        if (deleted == true) {
                          ref.read(sessionsProvider.notifier).loadSessions();
                          ref.read(activeSessionProvider.notifier).loadActiveSession();
                        }
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('عرض التفاصيل'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showEndSessionDialog(context, ref),
                      icon: const Icon(Icons.stop),
                      label: const Text('إنهاء الجلسة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('خطأ: $error'),
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> activeSession,
    AsyncValue<dynamic> students,
  ) {
    final studentCount = students.value?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              context: context,
              icon: Icons.upload_file,
              title: 'استيراد الطلاب',
              subtitle: '$studentCount طالب',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportStudentsScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              context: context,
              icon: Icons.qr_code_scanner,
              title: 'مسح رمز QR/الباركود',
              subtitle: activeSession.value != null ? 'نشط' : 'لا توجد جلسة',
              onTap: activeSession.value != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScannerScreen(),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: onTap != null ? Theme.of(context).primaryColor : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics(
    AsyncValue<List<dynamic>> students,
    AsyncValue<List<Subject>> subjects,
    AsyncValue<List<Session>> sessions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إحصائيات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(Icons.people, students.value?.length ?? 0, 'الطلاب'),
            const SizedBox(width: 12),
            _buildStatCard(
                Icons.menu_book, subjects.value?.length ?? 0, 'المواد'),
            const SizedBox(width: 12),
            _buildStatCard(Icons.event, sessions.value?.length ?? 0, 'الجلسات'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, int count, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjects(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Subject>> subjects,
    AsyncValue<List<Session>> sessions,
    AsyncValue<Session?> activeSession,
  ) {
    final sessionList = sessions.value ?? const <Session>[];
    final activeSubjectId = activeSession.value?.subjectId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'المواد',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addSubject(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مادة'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        subjects.when(
          data: (subjectList) {
            if (subjectList.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.menu_book, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد مواد بعد.\nأضف مادة أولاً، ثم أنشئ الجلسات بداخلها.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _addSubject(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة مادة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...subjectList.map((subject) {
                  final subjectSessions = sessionList
                      .where((session) => session.subjectId == subject.id)
                      .toList();
                  final isActive = subject.id == activeSubjectId;
                  final lastSession =
                      subjectSessions.isEmpty ? null : subjectSessions.first;

                  return Card(
                    color: isActive ? Colors.green.shade50 : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isActive ? Colors.green : Colors.blue.shade100,
                        child: Icon(
                          isActive ? Icons.play_arrow : Icons.menu_book,
                          color: isActive ? Colors.white : Colors.blue.shade800,
                        ),
                      ),
                      title: Text(
                        subject.code == null
                            ? subject.name
                            : '${subject.name} (${subject.code})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isActive
                            ? 'جلسة نشطة الآن • ${subjectSessions.length} جلسة'
                            : lastSession == null
                                ? 'لا توجد جلسات بعد'
                                : '${subjectSessions.length} جلسة • آخر جلسة: '
                                    '${formatSessionDateTime(lastSession.timestampStart)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SubjectScreen(subjectId: subject.id!),
                          ),
                        );
                      },
                    ),
                  );
                }),
                // Every session across all subjects, with search and date filter
                if (sessionList.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllSessionsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list),
                    label: Text('عرض كل الجلسات (${sessionList.length})'),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('خطأ: $error'),
        ),
      ],
    );
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
          ElevatedButton(
            onPressed: () async {
              final result = await ref.read(activeSessionProvider.notifier).endSession();

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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('إنهاء الجلسة'),
          ),
        ],
      ),
    );
  }
}
