/// Student model representing a student in the database
class Student {
  final int? id; // Auto-increment primary key
  final String? studentId; // Optional student identifier (e.g., student number)
  final String studentName;
  final String codeValue; // QR or barcode value (unique)
  final String? codeType; // 'qr' or 'barcode' (optional)
  final DateTime createdAt;

  Student({
    this.id,
    this.studentId,
    required this.studentName,
    required this.codeValue,
    this.codeType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert Student to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'code_value': codeValue,
      'code_type': codeType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create Student from database Map
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      studentId: map['student_id'] as String?,
      studentName: map['student_name'] as String,
      codeValue: map['code_value'] as String,
      codeType: map['code_type'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Create Student from Excel row
  factory Student.fromExcelRow(Map<String, dynamic> row) {
    final codeTypeValue = row['code_type']?.toString();
    return Student(
      studentId: row['student_id']?.toString(),
      studentName: row['student_name']?.toString() ?? '',
      codeValue: row['code_value']?.toString() ?? '',
      codeType: codeTypeValue?.toLowerCase(),
    );
  }

  /// Copy with method for creating modified copies
  Student copyWith({
    int? id,
    String? studentId,
    String? studentName,
    String? codeValue,
    String? codeType,
    DateTime? createdAt,
  }) {
    return Student(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      codeValue: codeValue ?? this.codeValue,
      codeType: codeType ?? this.codeType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Student{id: $id, studentId: $studentId, studentName: $studentName, codeValue: $codeValue, codeType: $codeType}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Student &&
        other.id == id &&
        other.studentId == studentId &&
        other.studentName == studentName &&
        other.codeValue == codeValue &&
        other.codeType == codeType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        studentId.hashCode ^
        studentName.hashCode ^
        codeValue.hashCode ^
        codeType.hashCode;
  }
}
