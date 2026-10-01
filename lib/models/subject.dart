/// Subject model representing a course that sessions belong to
class Subject {
  final int? id; // Auto-increment primary key
  final String name;
  final String? code; // Optional course code (e.g., CS101)
  final DateTime createdAt;

  Subject({
    this.id,
    required this.name,
    this.code,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert Subject to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create Subject from database Map
  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Copy with method for creating modified copies
  Subject copyWith({
    int? id,
    String? name,
    String? code,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Subject{id: $id, name: $name, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Subject &&
        other.id == id &&
        other.name == name &&
        other.code == code;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ code.hashCode;
  }
}
