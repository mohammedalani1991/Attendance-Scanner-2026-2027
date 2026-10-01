import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student.dart';
import '../models/session.dart';
import '../models/subject.dart';
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
          errors: ['ملف Excel فارغ'],
          duplicates: {},
        );
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        return ImportResult(
          success: false,
          students: [],
          errors: ['الورقة الأولى في الملف فارغة'],
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
          errors: ['عمود إلزامي مفقود: ${AppConstants.excelColCodeValue}'],
          duplicates: {},
        );
      }

      if (!headers.contains(AppConstants.excelColStudentName)) {
        return ImportResult(
          success: false,
          students: [],
          errors: ['عمود إلزامي مفقود: ${AppConstants.excelColStudentName}'],
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
          rowErrors.add('الصف $rowNum: اسم الطالب غير صالح');
        }

        if (Validators.validateCodeValue(codeValue) != null) {
          rowErrors.add('الصف $rowNum: قيمة الرمز (code_value) فارغة');
        }

        if (codeType != null && Validators.validateCodeType(codeType) != null) {
          rowErrors.add('الصف $rowNum: نوع الرمز يجب أن يكون qr أو barcode');
        }

        if (studentId != null && Validators.validateStudentId(studentId) != null) {
          rowErrors.add('الصف $rowNum: رقم الطالب يجب أن يكون أرقاماً فقط');
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
        errors: ['تعذر قراءة ملف Excel: $e'],
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
        TextCellValue('الجلسة:'),
        TextCellValue(session.displayName),
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

      return await _saveExcel(
        excel,
        AppConstants.getExportFileName(
          session.courseName,
          session.timestampStart,
        ),
      );
    } catch (e) {
      throw Exception('Failed to export attendance: $e');
    }
  }

  /// Export all sessions of a subject to one sheet:
  /// one row per student, one column per session (✓ / ✗), plus totals
  Future<String> exportSubjectAttendanceToExcel({
    required Subject subject,
    required List<Session> sessions,
    required List<AttendanceRecord> records,
    required Map<int, Student> studentsById,
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      const sheetName = 'حضور المادة';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      sheet.isRTL = true;

      // Sessions left to right from oldest to newest
      final orderedSessions = [...sessions]
        ..sort((a, b) => a.timestampStart.compareTo(b.timestampStart));
      final sessionCount = orderedSessions.length;

      // session id -> ids of students present in it
      final presentBySession = <int, Set<int>>{};
      // Rows: every student who attended at least one session
      final studentNames = <int, String>{};
      for (final record in records) {
        presentBySession
            .putIfAbsent(record.sessionId, () => <int>{})
            .add(record.studentId);
        studentNames[record.studentId] =
            studentsById[record.studentId]?.studentName ?? record.studentName;
      }
      final studentIds = studentNames.keys.toList()
        ..sort((a, b) => studentNames[a]!.compareTo(studentNames[b]!));

      final boldStyle = CellStyle(bold: true);
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#FFE3F2FD'),
      );
      final centerStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
      final presentStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        fontColorHex: ExcelColor.fromHexString('#FF2E7D32'),
      );
      final absentStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        fontColorHex: ExcelColor.fromHexString('#FFC62828'),
      );

      void put(int column, int row, CellValue value, [CellStyle? style]) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
          value,
          cellStyle: style,
        );
      }

      // Subject metadata
      var row = 0;
      put(0, row, TextCellValue('المادة:'), boldStyle);
      put(1, row, TextCellValue(
          subject.code == null ? subject.name : '${subject.name} (${subject.code})'));
      row++;
      put(0, row, TextCellValue('عدد الجلسات:'), boldStyle);
      put(1, row, IntCellValue(sessionCount));
      row++;
      put(0, row, TextCellValue('عدد الطلاب:'), boldStyle);
      put(1, row, IntCellValue(studentIds.length));
      row++;
      put(0, row, TextCellValue('تاريخ التصدير:'), boldStyle);
      put(1, row, TextCellValue(_formatDate(DateTime.now())));
      row += 2;

      const firstSessionColumn = 3;
      final countColumn = firstSessionColumn + sessionCount;
      final rateColumn = countColumn + 1;

      // Header: session names typed by the user
      put(0, row, TextCellValue('#'), headerStyle);
      put(1, row, TextCellValue('رقم الطالب'), headerStyle);
      put(2, row, TextCellValue('اسم الطالب'), headerStyle);
      for (var i = 0; i < sessionCount; i++) {
        put(firstSessionColumn + i, row,
            TextCellValue(orderedSessions[i].displayName), headerStyle);
      }
      put(countColumn, row, TextCellValue('عدد الحضور'), headerStyle);
      put(rateColumn, row, TextCellValue('نسبة الحضور'), headerStyle);
      row++;

      // Dates under the names, so sessions with the same name stay distinct
      put(2, row, TextCellValue('التاريخ'), boldStyle);
      for (var i = 0; i < sessionCount; i++) {
        put(firstSessionColumn + i, row,
            TextCellValue(_formatDate(orderedSessions[i].timestampStart)),
            centerStyle);
      }
      row++;

      // One row per student
      for (var index = 0; index < studentIds.length; index++) {
        final studentId = studentIds[index];
        put(0, row, IntCellValue(index + 1), centerStyle);
        put(1, row,
            TextCellValue(studentsById[studentId]?.studentId ?? ''), centerStyle);
        put(2, row, TextCellValue(studentNames[studentId]!));

        var presentCount = 0;
        for (var i = 0; i < sessionCount; i++) {
          final isPresent =
              presentBySession[orderedSessions[i].id]?.contains(studentId) ??
                  false;
          if (isPresent) presentCount++;
          put(firstSessionColumn + i, row, TextCellValue(isPresent ? '✓' : '✗'),
              isPresent ? presentStyle : absentStyle);
        }

        put(countColumn, row, TextCellValue('$presentCount/$sessionCount'),
            centerStyle);
        put(rateColumn, row,
            TextCellValue('${(presentCount * 100 / sessionCount).round()}%'),
            centerStyle);
        row++;
      }

      // Present count per session
      put(2, row, TextCellValue('عدد الحاضرين'), headerStyle);
      for (var i = 0; i < sessionCount; i++) {
        put(firstSessionColumn + i, row,
            IntCellValue(presentBySession[orderedSessions[i].id]?.length ?? 0),
            headerStyle);
      }

      // Column widths
      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 14);
      sheet.setColumnWidth(2, 28);
      for (var i = 0; i < sessionCount; i++) {
        sheet.setColumnWidth(firstSessionColumn + i, 14);
      }
      sheet.setColumnWidth(countColumn, 12);
      sheet.setColumnWidth(rateColumn, 12);

      return await _saveExcel(
        excel,
        AppConstants.getSubjectExportFileName(subject.name, DateTime.now()),
      );
    } catch (e) {
      throw Exception('Failed to export subject attendance: $e');
    }
  }

  /// Save a workbook to the app documents folder and return its path
  Future<String> _saveExcel(Excel excel, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to encode Excel file');
    }
    await File(filePath).writeAsBytes(fileBytes);
    return filePath;
  }

  /// Format a date as yyyy/MM/dd
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.day.toString().padLeft(2, '0')}';
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
