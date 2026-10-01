import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';
import '../services/session_service.dart';

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
  Session? _session;
  List<AttendanceRecord> _attendanceRecords = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    setState(() {
      _isLoading = true;
    });

    final session = await _sessionService.getSessionById(widget.sessionId);
    final records = await _sessionService.getAttendanceRecords(widget.sessionId);

    setState(() {
      _session = session;
      _attendanceRecords = records;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الجلسة'),
        actions: [
          if (!_isLoading && _session != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSessionData,
              tooltip: 'تحديث',
            ),
          if (!_isLoading && _session != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDeleteSession,
              tooltip: 'حذف الجلسة',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _session == null
              ? const Center(child: Text('الجلسة غير موجودة'))
              : _buildContent(),
      floatingActionButton: !_isLoading && _session != null && _attendanceRecords.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _exportToExcel,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download),
              label: Text(_isExporting ? 'جاري التصدير...' : 'تصدير'),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final session = _session!;
    final attendanceCount = _attendanceRecords.length;

    return RefreshIndicator(
      onRefresh: _loadSessionData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info card
            _buildSessionInfoCard(session),
            const SizedBox(height: 16),

            // Statistics card
            _buildStatisticsCard(attendanceCount),
            const SizedBox(height: 24),

            // Attendance list header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance List ($attendanceCount)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Attendance list
            if (attendanceCount == 0)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No attendance records yet'),
                  ),
                ),
              )
            else
              _buildAttendanceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard(Session session) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  session.isActive ? Icons.circle : Icons.check_circle,
                  color: session.isActive ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  session.isActive ? 'ACTIVE SESSION' : 'COMPLETED SESSION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: session.isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              session.courseName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              dateFormat.format(session.timestampStart),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Started',
              timeFormat.format(session.timestampStart),
            ),
            if (session.timestampEnd != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.access_time_filled,
                'Ended',
                timeFormat.format(session.timestampEnd!),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.timer,
                'Duration',
                _formatDuration(session.duration),
              ),
            ],
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.notes,
                'Notes',
                session.notes!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCard(int attendanceCount) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.people, size: 36, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    '$attendanceCount',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Present'),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.schedule, size: 36, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(
                    _session!.isActive ? 'Ongoing' : 'Completed',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Status'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    // Sort by scan time (most recent first)
    final sortedRecords = List<AttendanceRecord>.from(_attendanceRecords)
      ..sort((a, b) => b.timestampScan.compareTo(a.timestampScan));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedRecords.length,
      itemBuilder: (context, index) {
        final record = sortedRecords[index];
        final timeFormat = DateFormat('HH:mm:ss');

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              record.studentName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${record.studentId}'),
                Text('Code: ${record.codeValue}'),
                Text(
                  'Scanned: ${timeFormat.format(record.timestampScan)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: const Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportToExcel() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final filePath = await _sessionService.exportSessionAttendance(widget.sessionId);

      if (!mounted) return;

      setState(() {
        _isExporting = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير الحضور بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Attendance - ${_session!.courseName}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isExporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التصدير: $e'),
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
          'هل أنت متأكد من حذف هذه الجلسة "${_session!.courseName}"؟\n\n'
          'سيؤدي هذا إلى حذف الجلسة وجميع سجلات الحضور البالغ عددها ${_attendanceRecords.length} بشكل دائم.',
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

        // Navigate back to home screen
        Navigator.pop(context, true); // Return true to indicate deletion
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
