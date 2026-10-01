import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/session_service.dart';
import '../providers/session_provider.dart';
import '../providers/student_provider.dart';
import 'scanner_screen.dart';

/// Screen showing details of a specific session
class SessionDetailScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  final SessionService _sessionService = SessionService();
  final TextEditingController _searchController = TextEditingController();
  Session? _session;
  List<AttendanceRecord> _attendanceRecords = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isResuming = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // _isLoading already starts true
    _loadSessionData(showSpinner: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final session = await _sessionService.getSessionById(widget.sessionId);
    final records = await _sessionService.getAttendanceRecords(widget.sessionId);

    if (!mounted) return;
    setState(() {
      _session = session;
      _attendanceRecords = records;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الجلسة'),
        actions: [
          if (!_isLoading && session != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'export') _exportToExcel();
                if (value == 'rename') _renameSession();
                if (value == 'delete') _confirmDeleteSession();
              },
              itemBuilder: (context) => [
                if (_attendanceRecords.isNotEmpty)
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.file_download_outlined),
                      title: Text('تصدير Excel'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('تعديل اسم الجلسة'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      'حذف الجلسة',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : session == null
              ? const Center(child: Text('الجلسة غير موجودة'))
              : _buildContent(session),
      floatingActionButton: _buildFab(session),
    );
  }

  /// Scan while the session runs; export once it is finished
  Widget? _buildFab(Session? session) {
    if (_isLoading || session == null) return null;

    if (session.isActive) {
      return FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          );
          // Show students scanned meanwhile
          _loadSessionData(showSpinner: false);
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('مسح'),
      );
    }

    if (_attendanceRecords.isEmpty) return null;

    return FloatingActionButton.extended(
      onPressed: _isExporting ? null : _exportToExcel,
      icon: _isExporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined),
      label: Text(_isExporting ? 'جاري التصدير...' : 'تصدير'),
    );
  }

  Widget _buildContent(Session session) {
    // Real student numbers come from the students table (records store the internal id)
    final studentsById = {
      for (final student in ref.watch(studentsProvider).value ?? const <Student>[])
        student.id: student,
    };

    return RefreshIndicator(
      onRefresh: () => _loadSessionData(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _buildHeader(session),
          const SizedBox(height: 16),
          _buildInfoCard(session),
          if (!session.isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isResuming ? null : _confirmResumeSession,
                icon: _isResuming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('استئناف الجلسة'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildAttendanceSection(studentsById),
        ],
      ),
    );
  }

  Widget _buildHeader(Session session) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = session.isActive ? Colors.green : colors.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                session.isActive ? Icons.circle : Icons.check_circle,
                size: 10,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                session.isActive ? 'جلسة نشطة' : 'جلسة منتهية',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                session.displayName,
                style:
                    textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل اسم الجلسة',
              onPressed: _renameSession,
            ),
          ],
        ),
        Text(
          session.courseName,
          style: textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildInfoCard(Session session) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _InfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'التاريخ',
                  value: _formatDate(session.timestampStart),
                ),
                _InfoTile(
                  icon: Icons.timer_outlined,
                  label: 'المدة',
                  value: _formatDuration(session.duration),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoTile(
                  icon: Icons.login,
                  label: 'البداية',
                  value: _formatTime(session.timestampStart),
                ),
                _InfoTile(
                  icon: Icons.logout,
                  label: 'النهاية',
                  value: session.timestampEnd == null
                      ? 'مستمرة'
                      : _formatTime(session.timestampEnd!),
                ),
              ],
            ),
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              Divider(height: 28, color: colors.outlineVariant),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 20, color: colors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(session.notes!)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(Map<int?, Student> studentsById) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Most recent scan first
    final records = List<AttendanceRecord>.from(_attendanceRecords)
      ..sort((a, b) => b.timestampScan.compareTo(a.timestampScan));
    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? records
        : records.where((record) {
            final number = studentsById[record.studentId]?.studentId ?? '';
            return record.studentName.toLowerCase().contains(query) ||
                number.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'الحاضرون',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${records.length}',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.person_search_outlined,
                      size: 56, color: colors.outline),
                  const SizedBox(height: 12),
                  Text(
                    'لم يتم تسجيل أي طالب بعد',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Search only helps once the list is long
          if (records.length > 8) ...[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الطالب',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.outlineVariant),
                  _AttendeeTile(
                    record: filtered[i],
                    position: records.length - records.indexOf(filtered[i]),
                    studentNumber: studentsById[filtered[i].studentId]?.studentId,
                  ),
                ],
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('لا توجد نتائج مطابقة'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final filePath =
          await _sessionService.exportSessionAttendance(widget.sessionId);
      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Attendance - ${_session!.courseName} - ${_session!.displayName}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التصدير: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _renameSession() async {
    final controller = TextEditingController(text: _session!.title ?? '');
    String? error;

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل اسم الجلسة'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'اسم الجلسة',
              hintText: 'مثال: محاضرة 1',
              errorText: error,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final title = controller.text.trim();
                if (title.isEmpty) {
                  setDialogState(() => error = 'الرجاء إدخال اسم الجلسة');
                  return;
                }
                Navigator.pop(context, title);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (newTitle == null || !mounted) return;

    final success =
        await _sessionService.renameSession(widget.sessionId, newTitle);
    if (!mounted) return;

    if (success) {
      ref.read(sessionsProvider.notifier).loadSessions();
      // The active session card on the home screen shows the name too
      if (_session!.isActive) {
        ref.read(activeSessionProvider.notifier).loadActiveSession();
      }
      await _loadSessionData(showSpinner: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل تعديل اسم الجلسة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmResumeSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استئناف الجلسة'),
        content: Text(
          'هل تريد إعادة فتح جلسة "${_session!.displayName}"؟\n\n'
          'ستصبح الجلسة النشطة، ويمكنك متابعة مسح الحضور فيها. '
          'الطلاب المسجلون سابقاً يبقون مسجلين.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استئناف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResuming = true);
    final result = await ref
        .read(activeSessionProvider.notifier)
        .resumeSession(widget.sessionId);
    if (!mounted) return;
    setState(() => _isResuming = false);

    if (result.success) {
      ref.read(sessionsProvider.notifier).loadSessions();
      await _loadSessionData(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استئناف الجلسة. اضغط "مسح" لمتابعة التسجيل.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'فشل استئناف الجلسة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجلسة'),
        content: Text(
          'هل أنت متأكد من حذف "${_session!.displayName}" (${_session!.courseName})؟\n\n'
          'سيؤدي هذا إلى حذف الجلسة وجميع سجلات الحضور البالغ عددها ${_attendanceRecords.length} بشكل دائم.',
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

    if (confirmed == true) {
      await _deleteSession();
    }
  }

  Future<void> _deleteSession() async {
    try {
      final success = await _sessionService.deleteSession(widget.sessionId);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الجلسة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        // Return true so the previous screen refreshes
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل حذف الجلسة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حذف الجلسة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '$hours س $minutes د' : '$minutes د';
  }
}

/// Small labelled value used in the session info card
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One present student: scan order, name, student number and scan time
class _AttendeeTile extends StatelessWidget {
  final AttendanceRecord record;
  final int position;
  final String? studentNumber;

  const _AttendeeTile({
    required this.record,
    required this.position,
    this.studentNumber,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = record.timestampScan;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.green.withAlpha(35),
        child: Text(
          '$position',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        record.studentName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: studentNumber == null || studentNumber!.isEmpty
          ? null
          : Text('رقم الطالب: $studentNumber'),
      trailing: Text(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
    );
  }
}
