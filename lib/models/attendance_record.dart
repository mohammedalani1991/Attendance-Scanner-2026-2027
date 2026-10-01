/// AttendanceRecord model representing a student's attendance in a session
class AttendanceRecord {
  final int? id; // Auto-increment primary key
  final int sessionId; // Foreign key to sessions table
  final int studentId; // Foreign key to students table
  final String studentName; // Denormalized for easy export
  final String codeValue; // The scanned code value
  final DateTime timestampScan; // When the student was scanned
  final String? scanLocation; // Optional location data (future feature)
  final DateTime createdAt;

  AttendanceRecord({
    this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.codeValue,
    DateTime? timestampScan,
    this.scanLocation,
    DateTime? createdAt,
  })  : timestampScan = timestampScan ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Convert AttendanceRecord to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'student_name': studentName,
      'code_value': codeValue,
      'timestamp_scan': timestampScan.toIso8601String(),
      'scan_location': scanLocation,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create AttendanceRecord from database Map
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      studentId: map['student_id'] as int,
      studentName: map['student_name'] as String,
      codeValue: map['code_value'] as String,
      timestampScan: DateTime.parse(map['timestamp_scan'] as String),
      scanLocation: map['scan_location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert to Excel export row
  Map<String, dynamic> toExcelRow() {
    return {
      'Student ID': studentId,
      'Student Name': studentName,
      'Code Value': codeValue,
      'Scan Time': timestampScan.toIso8601String(),
      'Scan Location': scanLocation ?? 'N/A',
    };
  }

  /// Copy with method for creating modified copies
  AttendanceRecord copyWith({
    int? id,
    int? sessionId,
    int? studentId,
    String? studentName,
    String? codeValue,
    DateTime? timestampScan,
    String? scanLocation,
    DateTime? createdAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      codeValue: codeValue ?? this.codeValue,
      timestampScan: timestampScan ?? this.timestampScan,
      scanLocation: scanLocation ?? this.scanLocation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AttendanceRecord{id: $id, sessionId: $sessionId, studentId: $studentId, studentName: $studentName, timestampScan: $timestampScan}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AttendanceRecord &&
        other.id == id &&
        other.sessionId == sessionId &&
        other.studentId == studentId &&
        other.studentName == studentName &&
        other.codeValue == codeValue &&
        other.timestampScan == timestampScan;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        sessionId.hashCode ^
        studentId.hashCode ^
        studentName.hashCode ^
        codeValue.hashCode ^
        timestampScan.hashCode;
  }
}
