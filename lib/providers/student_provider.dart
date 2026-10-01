import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student.dart';
import '../database/database_helper.dart';
import '../services/excel_service.dart';

/// Provider for database helper
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Provider for Excel service
final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});

/// Provider for students list
final studentsProvider = StateNotifierProvider<StudentsNotifier, AsyncValue<List<Student>>>((ref) {
  return StudentsNotifier(ref.read(databaseHelperProvider));
});

/// Notifier for managing students state
class StudentsNotifier extends StateNotifier<AsyncValue<List<Student>>> {
  final DatabaseHelper _dbHelper;

  StudentsNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
    loadStudents();
  }

  /// Load all students from database
  Future<void> loadStudents() async {
    state = const AsyncValue.loading();
    try {
      final students = await _dbHelper.getAllStudents();
      state = AsyncValue.data(students);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add a single student
  Future<bool> addStudent(Student student) async {
    try {
      await _dbHelper.insertStudent(student);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add multiple students (batch operation)
  Future<bool> addStudents(List<Student> students) async {
    try {
      await _dbHelper.insertStudents(students);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update a student
  Future<bool> updateStudent(Student student) async {
    try {
      await _dbHelper.updateStudent(student);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a student
  Future<bool> deleteStudent(int id) async {
    try {
      await _dbHelper.deleteStudent(id);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete all students
  Future<bool> deleteAllStudents() async {
    try {
      await _dbHelper.deleteAllStudents();
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get student by code value
  Future<Student?> getStudentByCodeValue(String codeValue) async {
    try {
      return await _dbHelper.getStudentByCodeValue(codeValue);
    } catch (e) {
      return null;
    }
  }
}
