/// Validation utilities for the application
class Validators {
  /// Validates if a string is not empty
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Validates student name (must be non-empty, alphanumeric with spaces)
  static String? validateStudentName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Student name is required';
    }
    if (value.trim().length < 2) {
      return 'Student name must be at least 2 characters';
    }
    return null;
  }

  /// Validates code value (must be non-empty)
  static String? validateCodeValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Code value is required';
    }
    return null;
  }

  /// Validates course name
  static String? validateCourseName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Course name is required';
    }
    if (value.trim().length < 3) {
      return 'Course name must be at least 3 characters';
    }
    return null;
  }

  /// Validates code type (optional, but if provided must be 'qr' or 'barcode')
  static String? validateCodeType(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Code type is optional
    }
    final lowercaseValue = value.toLowerCase();
    if (lowercaseValue != 'qr' && lowercaseValue != 'barcode') {
      return 'Code type must be "qr" or "barcode"';
    }
    return null;
  }

  /// Validates student ID (optional, but if provided must be numeric)
  static String? validateStudentId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Student ID is optional
    }
    if (int.tryParse(value) == null) {
      return 'Student ID must be numeric';
    }
    return null;
  }

  /// Checks if a list of code values has duplicates
  static Map<String, List<int>> findDuplicateCodeValues(
      List<Map<String, dynamic>> rows) {
    final codeValueMap = <String, List<int>>{};

    for (int i = 0; i < rows.length; i++) {
      final codeValue = rows[i]['code_value']?.toString().trim();
      if (codeValue != null && codeValue.isNotEmpty) {
        if (codeValueMap.containsKey(codeValue)) {
          codeValueMap[codeValue]!.add(i + 2); // +2 for Excel row (1-indexed + header)
        } else {
          codeValueMap[codeValue] = [i + 2];
        }
      }
    }

    // Filter to only include duplicates
    codeValueMap.removeWhere((key, value) => value.length <= 1);
    return codeValueMap;
  }
}
