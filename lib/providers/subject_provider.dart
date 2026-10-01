import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../database/database_helper.dart';
import 'student_provider.dart';

/// Provider for subjects list
final subjectsProvider =
    StateNotifierProvider<SubjectsNotifier, AsyncValue<List<Subject>>>((ref) {
  return SubjectsNotifier(ref.read(databaseHelperProvider));
});

/// Notifier for managing subjects state
class SubjectsNotifier extends StateNotifier<AsyncValue<List<Subject>>> {
  final DatabaseHelper _dbHelper;

  SubjectsNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
    loadSubjects();
  }

  /// Load all subjects from database
  Future<void> loadSubjects() async {
    state = const AsyncValue.loading();
    try {
      final subjects = await _dbHelper.getAllSubjects();
      state = AsyncValue.data(subjects);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add a subject; returns an error message, or null on success
  Future<String?> addSubject({required String name, String? code}) async {
    try {
      if (await _dbHelper.subjectNameExists(name)) {
        return 'توجد مادة بنفس الاسم بالفعل';
      }
      await _dbHelper.insertSubject(Subject(name: name, code: code));
      await loadSubjects();
      return null;
    } catch (e) {
      return 'فشل إضافة المادة: $e';
    }
  }

  /// Rename or edit a subject; returns an error message, or null on success
  Future<String?> updateSubject(Subject subject) async {
    try {
      if (await _dbHelper.subjectNameExists(subject.name,
          excludeId: subject.id)) {
        return 'توجد مادة بنفس الاسم بالفعل';
      }
      await _dbHelper.updateSubject(subject);
      await loadSubjects();
      return null;
    } catch (e) {
      return 'فشل تعديل المادة: $e';
    }
  }

  /// Delete a subject with all its sessions; returns an error message, or null on success
  Future<String?> deleteSubject(int subjectId) async {
    try {
      await _dbHelper.deleteSubjectWithSessions(subjectId);
      await loadSubjects();
      return null;
    } catch (e) {
      return 'فشل حذف المادة: $e';
    }
  }
}
