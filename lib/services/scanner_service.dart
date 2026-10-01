import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../database/database_helper.dart';

/// Result of a scan operation
class ScanResult {
  final bool success;
  final Student? student;
  final String? errorMessage;
  final ScanErrorType? errorType;

  ScanResult.success(this.student)
      : success = true,
        errorMessage = null,
        errorType = null;

  ScanResult.error(this.errorMessage, this.errorType)
      : success = false,
        student = null;
}

/// Types of scan errors
enum ScanErrorType {
  unknownCode, // Code not found in database
  alreadyScanned, // Student already scanned in this session
  noActiveSession, // No active session
  databaseError, // Database operation failed
}

/// Service for handling QR and barcode scanning operations
class ScannerService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Process a scanned code
  /// Returns ScanResult with student if successful, or error message if failed
  Future<ScanResult> processScan({
    required String rawValue,
    required BarcodeFormat format,
  }) async {
    try {
      // Get active session
      final session = await _dbHelper.getActiveSession();
      if (session == null) {
        return ScanResult.error(
          'لا توجد جلسة نشطة. الرجاء بدء جلسة أولاً.',
          ScanErrorType.noActiveSession,
        );
      }

      // Find student by code value
      final student = await _dbHelper.getStudentByCodeValue(rawValue);
      if (student == null) {
        return ScanResult.error(
          'رمز غير معروف: $rawValue',
          ScanErrorType.unknownCode,
        );
      }

      // Check if student already attended this session
      final hasAttended = await _dbHelper.hasStudentAttended(
        session.id!,
        student.id!,
      );

      if (hasAttended) {
        return ScanResult.error(
          'تم تسجيل ${student.studentName} مسبقاً في هذه الجلسة.',
          ScanErrorType.alreadyScanned,
        );
      }

      // Create attendance record
      final attendanceRecord = AttendanceRecord(
        sessionId: session.id!,
        studentId: student.id!,
        studentName: student.studentName,
        codeValue: rawValue,
      );

      // Insert into database
      await _dbHelper.insertAttendanceRecord(attendanceRecord);

      return ScanResult.success(student);
    } catch (e) {
      return ScanResult.error(
        'خطأ في قاعدة البيانات: $e',
        ScanErrorType.databaseError,
      );
    }
  }

  /// Get barcode format as string for display
  static String getBarcodeFormatString(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code93:
        return 'Code 93';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.aztec:
        return 'Aztec';
      case BarcodeFormat.codabar:
        return 'Codabar';
      case BarcodeFormat.itf:
        return 'ITF';
      default:
        return 'Unknown';
    }
  }

  /// Check if barcode format is a QR code
  static bool isQRCode(BarcodeFormat format) {
    return format == BarcodeFormat.qrCode;
  }

  /// Check if barcode format is a standard barcode
  static bool isBarcode(BarcodeFormat format) {
    return !isQRCode(format);
  }
}
