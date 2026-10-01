import '../models/session.dart';
import '../models/subject.dart';
import '../models/attendance_record.dart';
import '../database/database_helper.dart';
import 'excel_service.dart';

/// Result of session operations
class SessionOperationResult {
  final bool success;
  final Session? session;
  final String? errorMessage;

  SessionOperationResult.success(this.session)
      : success = true,
        errorMessage = null;

  SessionOperationResult.error(this.errorMessage)
      : success = false,
        session = null;
}

/// Service for managing lecture sessions
class SessionService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExcelService _excelService = ExcelService();

  /// Start a new session under a subject
  Future<SessionOperationResult> startSession({
    required Subject subject,
    required String title,
    String? notes,
  }) async {
    try {
      // Check if there's already an active session
      final activeSession = await _dbHelper.getActiveSession();
      if (activeSession != null) {
        return SessionOperationResult.error(
          'توجد جلسة نشطة بالفعل: ${activeSession.courseName}. '
          'الرجاء إنهاؤها قبل بدء جلسة جديدة.',
        );
      }

      // Create new session
      final session = Session(
        subjectId: subject.id,
        title: title,
        courseName: subject.name,
        notes: notes,
      );

      // Insert into database
      final insertedSession = await _dbHelper.insertSession(session);

      return SessionOperationResult.success(insertedSession);
    } catch (e) {
      return SessionOperationResult.error('فشل بدء الجلسة: $e');
    }
  }

  /// End an active session
  Future<SessionOperationResult> endSession(int sessionId) async {
    try {
      // Get session
      final session = await _dbHelper.getSessionById(sessionId);
      if (session == null) {
        return SessionOperationResult.error('الجلسة غير موجودة');
      }

      if (!session.isActive) {
        return SessionOperationResult.error('الجلسة منتهية بالفعل');
      }

      // End session
      final endedSession = await _dbHelper.endSession(sessionId);

      return SessionOperationResult.success(endedSession);
    } catch (e) {
      return SessionOperationResult.error('فشل إنهاء الجلسة: $e');
    }
  }

  /// Rename a session; returns false if it failed
  Future<bool> renameSession(int sessionId, String title) async {
    try {
      await _dbHelper.updateSessionTitle(sessionId, title);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Export every session of a subject to one Excel file and return its path
  Future<String> exportSubjectAttendance(int subjectId) async {
    final subject = await _dbHelper.getSubjectById(subjectId);
    if (subject == null) {
      throw Exception('المادة غير موجودة');
    }

    final sessions = await _dbHelper.getSessionsBySubject(subjectId);
    if (sessions.isEmpty) {
      throw Exception('لا توجد جلسات لهذه المادة');
    }

    final records = await _dbHelper.getAttendanceRecordsBySubject(subjectId);
    final students = await _dbHelper.getAllStudents();

    return _excelService.exportSubjectAttendanceToExcel(
      subject: subject,
      sessions: sessions,
      records: records,
      studentsById: {for (final student in students) student.id!: student},
    );
  }

  /// Reopen an ended session so scanning can continue in it
  Future<SessionOperationResult> resumeSession(int sessionId) async {
    try {
      final session = await _dbHelper.getSessionById(sessionId);
      if (session == null) {
        return SessionOperationResult.error('الجلسة غير موجودة');
      }

      if (session.isActive) {
        return SessionOperationResult.error('الجلسة نشطة بالفعل');
      }

      // Only one session can be active at a time
      final activeSession = await _dbHelper.getActiveSession();
      if (activeSession != null) {
        return SessionOperationResult.error(
          'توجد جلسة نشطة بالفعل: ${activeSession.courseName}. '
          'الرجاء إنهاؤها قبل استئناف هذه الجلسة.',
        );
      }

      final resumedSession = await _dbHelper.resumeSession(sessionId);
      return SessionOperationResult.success(resumedSession);
    } catch (e) {
      return SessionOperationResult.error('فشل استئناف الجلسة: $e');
    }
  }

  /// Get active session
  Future<Session?> getActiveSession() async {
    try {
      return await _dbHelper.getActiveSession();
    } catch (e) {
      return null;
    }
  }

  /// Get all sessions
  Future<List<Session>> getAllSessions() async {
    try {
      return await _dbHelper.getAllSessions();
    } catch (e) {
      return [];
    }
  }

  /// Get session by ID
  Future<Session?> getSessionById(int sessionId) async {
    try {
      return await _dbHelper.getSessionById(sessionId);
    } catch (e) {
      return null;
    }
  }

  /// Get attendance records for a session
  Future<List<AttendanceRecord>> getAttendanceRecords(int sessionId) async {
    try {
      return await _dbHelper.getAttendanceRecordsBySession(sessionId);
    } catch (e) {
      return [];
    }
  }

  /// Get attendance count for a session
  Future<int> getAttendanceCount(int sessionId) async {
    try {
      return await _dbHelper.getAttendanceCount(sessionId);
    } catch (e) {
      return 0;
    }
  }

  /// Export session attendance to Excel and return file path
  Future<String> exportSessionAttendance(int sessionId) async {
    final session = await _dbHelper.getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    final attendanceRecords =
        await _dbHelper.getAttendanceRecordsBySession(sessionId);

    final filePath = await _excelService.exportAttendanceToExcel(
      session: session,
      attendanceRecords: attendanceRecords,
    );

    return filePath;
  }

  /// Delete a session and all its attendance records
  Future<bool> deleteSession(int sessionId) async {
    try {
      await _dbHelper.deleteSessionWithRecords(sessionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get session statistics
  Future<SessionStats> getSessionStats(int sessionId) async {
    final session = await _dbHelper.getSessionById(sessionId);
    final attendanceCount = await _dbHelper.getAttendanceCount(sessionId);
    final totalStudents = (await _dbHelper.getAllStudents()).length;

    return SessionStats(
      session: session,
      attendanceCount: attendanceCount,
      totalStudents: totalStudents,
      attendanceRate: totalStudents > 0
          ? (attendanceCount / totalStudents * 100).toStringAsFixed(1)
          : '0.0',
    );
  }
}

/// Session statistics
class SessionStats {
  final Session? session;
  final int attendanceCount;
  final int totalStudents;
  final String attendanceRate; // Percentage as string

  SessionStats({
    required this.session,
    required this.attendanceCount,
    required this.totalStudents,
    required this.attendanceRate,
  });
}
