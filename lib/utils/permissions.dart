import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph
    show openAppSettings;

/// Permission handling utilities
class PermissionHelper {
  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // User has permanently denied permission, must go to settings
      return false;
    }

    return false;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    return await Permission.camera.isGranted;
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    // Prefixed so this calls the package function, not this method
    await ph.openAppSettings();
  }

  /// Request storage permission (for Android < 13)
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.storage.request();
      return result.isGranted;
    }

    return false;
  }

  /// Get permission status message for UI
  static String getPermissionMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Permission granted';
      case PermissionStatus.denied:
        return 'Permission denied. Please grant permission to continue.';
      case PermissionStatus.permanentlyDenied:
        return 'Permission permanently denied. Please enable it in app settings.';
      case PermissionStatus.restricted:
        return 'Permission restricted by system.';
      case PermissionStatus.limited:
        return 'Permission granted with limitations.';
      default:
        return 'Permission status unknown.';
    }
  }
}
