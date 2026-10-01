/// Application-wide constants
class AppConstants {
  // Database
  static const String databaseName = 'attendance_scanner.db';
  // v2: subjects table, sessions.subject_id
  // v3: sessions.title (session name typed by the user)
  static const int databaseVersion = 3;

  // Table names
  static const String subjectsTable = 'subjects';
  static const String studentsTable = 'students';
  static const String sessionsTable = 'sessions';
  static const String attendanceRecordsTable = 'attendance_records';

  // Minimum gap before any new code is processed
  static const Duration scanGlobalGap = Duration(milliseconds: 800);

  // The same code is ignored for this long after it was last handled
  static const Duration scanSameCodeLock = Duration(seconds: 5);

  // Export file name pattern
  static String getExportFileName(String courseName, DateTime dateTime) {
    final formattedDate =
        '${dateTime.year}${_pad(dateTime.month)}${_pad(dateTime.day)}_'
        '${_pad(dateTime.hour)}${_pad(dateTime.minute)}';
    return 'Attendance_${_sanitizeFileName(courseName)}_$formattedDate.xlsx';
  }

  // Subject export file name: Attendance_<subject>_All_<YYYYMMDD>.xlsx
  static String getSubjectExportFileName(String subjectName, DateTime dateTime) {
    final formattedDate =
        '${dateTime.year}${_pad(dateTime.month)}${_pad(dateTime.day)}';
    return 'Attendance_${_sanitizeFileName(subjectName)}_All_$formattedDate.xlsx';
  }

  // Remove only characters that file systems reject, so Arabic names survive
  static String _sanitizeFileName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  // Excel import columns
  static const String excelColStudentId = 'student_id';
  static const String excelColStudentName = 'student_name';
  static const String excelColCodeValue = 'code_value';
  static const String excelColCodeType = 'code_type';

  // Code types
  static const String codeTypeQR = 'qr';
  static const String codeTypeBarcode = 'barcode';

  // Permissions
  static const String permissionCamera = 'camera';
  static const String permissionStorage = 'storage';

  // UI
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;

  // Scan feedback
  static const Duration vibrationDuration = Duration(milliseconds: 200);
}
