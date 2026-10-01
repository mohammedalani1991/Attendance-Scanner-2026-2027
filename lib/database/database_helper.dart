import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';
import '../utils/constants.dart';

/// Database helper class for SQLite operations
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.databaseName);
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    // Students table
    await db.execute('''
      CREATE TABLE ${AppConstants.studentsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        student_name TEXT NOT NULL,
        code_value TEXT NOT NULL UNIQUE,
        code_type TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Sessions table
    await db.execute('''
      CREATE TABLE ${AppConstants.sessionsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_name TEXT NOT NULL,
        timestamp_start TEXT NOT NULL,
        timestamp_end TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Attendance records table
    await db.execute('''
      CREATE TABLE ${AppConstants.attendanceRecordsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        student_name TEXT NOT NULL,
        code_value TEXT NOT NULL,
        timestamp_scan TEXT NOT NULL,
        scan_location TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ${AppConstants.sessionsTable} (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES ${AppConstants.studentsTable} (id) ON DELETE CASCADE,
        UNIQUE(session_id, student_id)
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_students_code_value ON ${AppConstants.studentsTable}(code_value)');
    await db.execute(
        'CREATE INDEX idx_attendance_session_id ON ${AppConstants.attendanceRecordsTable}(session_id)');
    await db.execute(
        'CREATE INDEX idx_sessions_timestamp_start ON ${AppConstants.sessionsTable}(timestamp_start)');
  }

  /// Upgrade database (for future migrations)
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here in future versions
  }

  // ==================== STUDENT OPERATIONS ====================

  /// Insert a student
  Future<Student> insertStudent(Student student) async {
    final db = await database;
    final id = await db.insert(
      AppConstants.studentsTable,
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return student.copyWith(id: id);
  }

  /// Insert multiple students (batch operation)
  Future<void> insertStudents(List<Student> students) async {
    final db = await database;
    final batch = db.batch();
    for (final student in students) {
      batch.insert(
        AppConstants.studentsTable,
        student.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get all students
  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query(AppConstants.studentsTable, orderBy: 'student_name ASC');
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Get student by code value
  Future<Student?> getStudentByCodeValue(String codeValue) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.studentsTable,
      where: 'code_value = ?',
      whereArgs: [codeValue],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  /// Get student by ID
  Future<Student?> getStudentById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.studentsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  /// Update a student
  Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update(
      AppConstants.studentsTable,
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  /// Delete a student
  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.studentsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all students
  Future<int> deleteAllStudents() async {
    final db = await database;
    return await db.delete(AppConstants.studentsTable);
  }

  /// Check if code value exists
  Future<bool> codeValueExists(String codeValue) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.studentsTable} WHERE code_value = ?',
      [codeValue],
    ));
    return (count ?? 0) > 0;
  }

  // ==================== SESSION OPERATIONS ====================

  /// Insert a session
  Future<Session> insertSession(Session session) async {
    final db = await database;
    final id = await db.insert(
      AppConstants.sessionsTable,
      session.toMap(),
    );
    return session.copyWith(id: id);
  }

  /// Get all sessions (ordered by most recent first)
  Future<List<Session>> getAllSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.sessionsTable,
      orderBy: 'timestamp_start DESC',
    );
    return List.generate(maps.length, (i) => Session.fromMap(maps[i]));
  }

  /// Get active session (not ended)
  Future<Session?> getActiveSession() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.sessionsTable,
      where: 'timestamp_end IS NULL',
      orderBy: 'timestamp_start DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  /// Get session by ID
  Future<Session?> getSessionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.sessionsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  /// Update a session
  Future<int> updateSession(Session session) async {
    final db = await database;
    return await db.update(
      AppConstants.sessionsTable,
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// End a session
  Future<Session?> endSession(int sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) return null;
    final endedSession = session.end();
    await updateSession(endedSession);
    return endedSession;
  }

  /// Delete a session
  Future<int> deleteSession(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.sessionsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== ATTENDANCE RECORD OPERATIONS ====================

  /// Insert an attendance record
  Future<AttendanceRecord> insertAttendanceRecord(
      AttendanceRecord record) async {
    final db = await database;
    final id = await db.insert(
      AppConstants.attendanceRecordsTable,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return record.copyWith(id: id);
  }

  /// Get all attendance records for a session
  Future<List<AttendanceRecord>> getAttendanceRecordsBySession(
      int sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.attendanceRecordsTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp_scan ASC',
    );
    return List.generate(maps.length, (i) => AttendanceRecord.fromMap(maps[i]));
  }

  /// Check if student attended a session
  Future<bool> hasStudentAttended(int sessionId, int studentId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.attendanceRecordsTable} WHERE session_id = ? AND student_id = ?',
      [sessionId, studentId],
    ));
    return (count ?? 0) > 0;
  }

  /// Get attendance count for a session
  Future<int> getAttendanceCount(int sessionId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.attendanceRecordsTable} WHERE session_id = ?',
      [sessionId],
    ));
    return count ?? 0;
  }

  /// Delete an attendance record
  Future<int> deleteAttendanceRecord(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.attendanceRecordsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a session and its attendance records in one transaction
  Future<void> deleteSessionWithRecords(int sessionId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        AppConstants.attendanceRecordsTable,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        AppConstants.sessionsTable,
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  /// Delete all attendance records for a session
  Future<int> deleteAttendanceRecordsBySession(int sessionId) async {
    final db = await database;
    return await db.delete(
      AppConstants.attendanceRecordsTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // ==================== UTILITY OPERATIONS ====================

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// Delete database (for testing/reset)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
