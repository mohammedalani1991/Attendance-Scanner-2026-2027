import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';

/// Result of Excel import operation
class ImportResult {
  final bool success;
  final List<Student> students;
  final List<String> errors;
  final Map<String, List<int>> duplicates; // code_value -> row numbers

  ImportResult({
    required this.success,
    required this.students,
    required this.errors,
    required this.duplicates,
  });

  bool get hasErrors => errors.isNotEmpty || duplicates.isNotEmpty;
}

/// Service for Excel import and export operations
class ExcelService {
  /// Import students from Excel file
  /// Expected columns: student_id, student_name, code_value, code_type
  Future<ImportResult> importStudentsFromExcel(String filePath) async {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Get first sheet
      if (excel.tables.isEmpty) {
        return ImportResult(
          success: false,
          students: [],
          errors: ['Excel file is empty'],
          duplicates: {},
        );
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        return ImportResult(
          success: false,
          students: [],
          errors: ['Sheet is empty'],
          duplicates: {},
        );
      }

      // Parse header row (first row)
      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '').toList();

      // Validate required columns
      if (!headers.contains(AppConstants.excelColCodeValue)) {
        return ImportResult(
          success: false,
          students: [],
          errors: ['Missing required column: ${AppConstants.excelColCodeValue}'],
          duplicates: {},
        );
      }

      if (!headers.contains(AppConstants.excelColStudentName)) {
        return ImportResult(
          success: false,
          students: [],
          errors: ['Missing required column: ${AppConstants.excelColStudentName}'],
          duplicates: {},
        );
      }

      // Get column indices
      final studentIdIndex = headers.indexOf(AppConstants.excelColStudentId);
      final studentNameIndex = headers.indexOf(AppConstants.excelColStudentName);
      final codeValueIndex = headers.indexOf(AppConstants.excelColCodeValue);
      final codeTypeIndex = headers.indexOf(AppConstants.excelColCodeType);

      // Parse data rows
      final List<Student> students = [];
      final List<String> errors = [];
      final List<Map<String, dynamic>> rowData = [];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final rowNum = i + 1; // Excel row number (1-indexed)

        // Skip empty rows
        if (row.every((cell) => cell?.value == null)) continue;

        // Extract values
        final studentId = studentIdIndex >= 0 && row.length > studentIdIndex
            ? row[studentIdIndex]?.value?.toString()
            : null;
        final studentName = studentNameIndex >= 0 && row.length > studentNameIndex
            ? row[studentNameIndex]?.value?.toString().trim()
            : null;
        final codeValue = codeValueIndex >= 0 && row.length > codeValueIndex
            ? row[codeValueIndex]?.value?.toString().trim().split('\n').first.trim()
            : null;
        final codeType = codeTypeIndex >= 0 && row.length > codeTypeIndex
            ? row[codeTypeIndex]?.value?.toString().trim()
            : null;

        // Validate row
        final rowErrors = <String>[];

        if (Validators.validateStudentName(studentName) != null) {
          rowErrors.add('Row $rowNum: Invalid student name');
        }

        if (Validators.validateCodeValue(codeValue) != null) {
          rowErrors.add('Row $rowNum: Invalid code value');
        }

        if (codeType != null && Validators.validateCodeType(codeType) != null) {
          rowErrors.add('Row $rowNum: Invalid code type (must be "qr" or "barcode")');
        }

        if (studentId != null && Validators.validateStudentId(studentId) != null) {
          rowErrors.add('Row $rowNum: Student ID must be numeric');
        }

        if (rowErrors.isNotEmpty) {
          errors.addAll(rowErrors);
          continue;
        }

        // Create student object
        final student = Student(
          studentId: studentId,
          studentName: studentName!,
          codeValue: codeValue!,
          codeType: codeType?.toLowerCase(),
        );

        students.add(student);
        rowData.add({
          'code_value': codeValue,
          'student_name': studentName,
        });
      }

      // Check for duplicate code_values
      final duplicates = Validators.findDuplicateCodeValues(rowData);

      return ImportResult(
        success: errors.isEmpty && duplicates.isEmpty,
        students: students,
        errors: errors,
        duplicates: duplicates,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        students: [],
        errors: ['Failed to import Excel file: $e'],
        duplicates: {},
      );
    }
  }

  /// Export attendance records to Excel file
  Future<String> exportAttendanceToExcel({
    required Session session,
    required List<AttendanceRecord> attendanceRecords,
  }) async {
    try {
      final excel = Excel.createExcel();

      // Delete the default 'Sheet1' to avoid empty sheet in export
      excel.delete('Sheet1');

      final sheetName = 'Attendance';
      final sheet = excel[sheetName];

      // Add session metadata at the top
      sheet.appendRow([
        TextCellValue('المقرر:'),
        TextCellValue(session.courseName),
      ]);
      sheet.appendRow([
        TextCellValue('بداية الجلسة:'),
        TextCellValue(session.timestampStart.toString()),
      ]);
      sheet.appendRow([
        TextCellValue('نهاية الجلسة:'),
        TextCellValue(session.timestampEnd?.toString() ?? 'مستمرة'),
      ]);
      if (session.notes != null && session.notes!.isNotEmpty) {
        sheet.appendRow([
          TextCellValue('ملاحظات:'),
          TextCellValue(session.notes!),
        ]);
      }
      sheet.appendRow([
        TextCellValue('إجمالي الحضور:'),
        IntCellValue(attendanceRecords.length),
      ]);

      // Add empty row
      sheet.appendRow([]);

      // Add header row for attendance data
      sheet.appendRow([
        TextCellValue('رقم الطالب'),
        TextCellValue('اسم الطالب'),
        TextCellValue('قيمة الرمز'),
        TextCellValue('وقت المسح'),
        TextCellValue('موقع المسح'),
      ]);

      // Add attendance data rows
      for (final record in attendanceRecords) {
        sheet.appendRow([
          IntCellValue(record.studentId),
          TextCellValue(record.studentName),
          TextCellValue(record.codeValue),
          TextCellValue(record.timestampScan.toString()),
          TextCellValue(record.scanLocation ?? 'N/A'),
        ]);
      }

      // Get temporary directory to save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = AppConstants.getExportFileName(
        session.courseName,
        session.timestampStart,
      );
      final filePath = '${directory.path}/$fileName';

      // Save Excel file
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      } else {
        throw Exception('Failed to encode Excel file');
      }
    } catch (e) {
      throw Exception('Failed to export attendance: $e');
    }
  }

  /// Create a sample Excel file for import template
  Future<String> createSampleExcelFile() async {
    try {
      final excel = Excel.createExcel();
      final sheetName = 'Students';
      final sheet = excel[sheetName];

      // Add header row
      sheet.appendRow([
        TextCellValue('student_id'),
        TextCellValue('student_name'),
        TextCellValue('code_value'),
        TextCellValue('code_type'),
      ]);

      // Add sample data rows
      final sampleData = [
        ['1001', 'Alice Johnson', 'QR12345ABC', 'qr'],
        ['1002', 'Bob Smith', 'BAR987654XYZ', 'barcode'],
        ['1003', 'Charlie Brown', 'QR67890DEF', 'qr'],
        ['1004', 'Diana Prince', '123456789012', 'barcode'],
        ['1005', 'Ethan Hunt', 'QRCODE2024XYZ', 'qr'],
      ];

      for (final row in sampleData) {
        sheet.appendRow([
          TextCellValue(row[0]),
          TextCellValue(row[1]),
          TextCellValue(row[2]),
          TextCellValue(row[3]),
        ]);
      }

      // Get directory to save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/sample_students.xlsx';

      // Save Excel file
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      } else {
        throw Exception('Failed to encode sample Excel file');
      }
    } catch (e) {
      throw Exception('Failed to create sample file: $e');
    }
  }
}
