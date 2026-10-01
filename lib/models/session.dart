/// Session model representing a lecture session
class Session {
  final int? id; // Auto-increment primary key
  final String courseName;
  final DateTime timestampStart;
  final DateTime? timestampEnd; // Null if session is ongoing
  final String? notes; // Optional notes about the session
  final DateTime createdAt;

  Session({
    this.id,
    required this.courseName,
    DateTime? timestampStart,
    this.timestampEnd,
    this.notes,
    DateTime? createdAt,
  })  : timestampStart = timestampStart ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Check if session is active (not ended)
  bool get isActive => timestampEnd == null;

  /// Get session duration
  Duration get duration {
    final end = timestampEnd ?? DateTime.now();
    return end.difference(timestampStart);
  }

  /// Convert Session to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_name': courseName,
      'timestamp_start': timestampStart.toIso8601String(),
      'timestamp_end': timestampEnd?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create Session from database Map
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      courseName: map['course_name'] as String,
      timestampStart: DateTime.parse(map['timestamp_start'] as String),
      timestampEnd: map['timestamp_end'] != null
          ? DateTime.parse(map['timestamp_end'] as String)
          : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Copy with method for creating modified copies
  Session copyWith({
    int? id,
    String? courseName,
    DateTime? timestampStart,
    DateTime? timestampEnd,
    String? notes,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      timestampStart: timestampStart ?? this.timestampStart,
      timestampEnd: timestampEnd ?? this.timestampEnd,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// End the session (set timestampEnd to now)
  Session end() {
    return copyWith(timestampEnd: DateTime.now());
  }

  @override
  String toString() {
    return 'Session{id: $id, courseName: $courseName, timestampStart: $timestampStart, timestampEnd: $timestampEnd, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Session &&
        other.id == id &&
        other.courseName == courseName &&
        other.timestampStart == timestampStart &&
        other.timestampEnd == timestampEnd &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        courseName.hashCode ^
        timestampStart.hashCode ^
        timestampEnd.hashCode ^
        notes.hashCode;
  }
}
