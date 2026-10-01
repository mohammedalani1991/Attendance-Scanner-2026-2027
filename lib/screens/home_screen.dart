import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/session_list_tile.dart';
import 'all_sessions_screen.dart';
import 'import_students_screen.dart';
import 'scanner_screen.dart';
import 'session_detail_screen.dart';

/// Home dashboard screen - main entry point of the app
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Number of sessions shown on the dashboard before "view all"
  static const int _recentSessionsLimit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final sessions = ref.watch(sessionsProvider);
    final students = ref.watch(studentsProvider);

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
            _buildStatistics(students, sessions),
            const SizedBox(height: 24),

            // Recent sessions
            _buildRecentSessions(context, ref, sessions),
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
          : null,
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
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'لا توجد جلسة نشطة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('ابدأ جلسة جديدة لبدء تسجيل الحضور.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showStartSessionDialog(context, ref),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('بدء جلسة'),
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
                  session.courseName,
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
    AsyncValue<dynamic> students,
    AsyncValue<dynamic> sessions,
  ) {
    final studentCount = students.value?.length ?? 0;
    final sessionCount = sessions.value?.length ?? 0;

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
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.people, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        '$studentCount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('الطلاب'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.event, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        '$sessionCount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('الجلسات'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSessions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> sessions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الجلسات الأخيرة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        sessions.when(
          data: (sessionList) {
            if (sessionList.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('لا توجد جلسات بعد'),
                  ),
                ),
              );
            }

            final recentSessions = sessionList.take(_recentSessionsLimit).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentSessions.length,
                  itemBuilder: (context, index) =>
                      SessionListTile(session: recentSessions[index]),
                ),
                // Older sessions are only reachable from the full list
                if (sessionList.length > _recentSessionsLimit)
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

  void _showStartSessionDialog(BuildContext context, WidgetRef ref) {
    final courseNameController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بدء جلسة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courseNameController,
              decoration: const InputDecoration(
                labelText: 'اسم المقرر',
                hintText: 'مثال: علوم الحاسب 101',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (courseNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال اسم المقرر')),
                );
                return;
              }

              final result = await ref
                  .read(activeSessionProvider.notifier)
                  .startSession(
                    courseName: courseNameController.text.trim(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );

              if (context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
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
            },
            child: const Text('بدء'),
          ),
        ],
      ),
    ).then((_) {
      courseNameController.dispose();
      notesController.dispose();
    });
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
