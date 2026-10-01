import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import '../services/scanner_service.dart';
import '../services/sound_service.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';

/// Screen for scanning QR codes and barcodes
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ScannerService _scannerService = ScannerService();
  final SoundService _soundService = SoundService();
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  // Only stops two database calls from overlapping; not a timed lock
  bool _busy = false;
  // When the last code was handled, for the short gap between any two codes
  DateTime _lastHandled = DateTime.fromMillisecondsSinceEpoch(0);
  // code -> when it was last handled, so a card held in view isn't re-processed
  final Map<String, DateTime> _recentCodes = {};

  // Non-modal feedback card shown over the camera
  _ScanFeedback? _feedback;
  int _feedbackCounter = 0;
  Timer? _feedbackTimer;

  bool _hasVibrator = false;

  @override
  void initState() {
    super.initState();
    // Check once instead of on every scan
    Vibration.hasVibrator().then((value) => _hasVibrator = value == true);
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _controller.dispose();
    _soundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
            tooltip: 'معلومات',
          ),
        ],
      ),
      body: activeSession.when(
        data: (session) {
          if (session == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'لا توجد جلسة نشطة. الرجاء بدء جلسة أولاً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return Column(
            children: [
              // Session banner with a live count of scanned students
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.green.shade700,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            session.courseName,
                            style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.how_to_reg,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${ref.watch(attendanceRecordsProvider).value?.length ?? 0} حاضر',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Camera preview
              Expanded(
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _handleBarcode,
                    ),
                    // Scanning overlay
                    CustomPaint(
                      painter: ScannerOverlayPainter(),
                      child: Container(),
                    ),
                    // Scan result (non-modal, so the camera keeps scanning)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _feedback == null
                            ? const SizedBox.shrink(key: ValueKey('no_feedback'))
                            : _ScanFeedbackCard(
                                key: ValueKey(_feedback!.id),
                                feedback: _feedback!,
                              ),
                      ),
                    ),
                    // Instructions
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ضع رمز QR أو الباركود داخل الإطار',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Controls
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Icon follows the real torch state
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, child) {
                          final isOn = state.torchState == TorchState.on;
                          return _ControlButton(
                            icon: isOn ? Icons.flash_on : Icons.flash_off,
                            label: isOn ? 'إطفاء الفلاش' : 'الفلاش',
                            highlighted: isOn,
                            onPressed: state.torchState == TorchState.unavailable
                                ? null
                                : () => _controller.toggleTorch(),
                          );
                        },
                      ),
                      _ControlButton(
                        icon: Icons.cameraswitch_outlined,
                        label: 'تبديل الكاميرا',
                        onPressed: () => _controller.switchCamera(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ: $error'),
        ),
      ),
    );
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    // Prevent processing multiple scans simultaneously
    if (_busy) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? code = barcode.rawValue;

    if (code == null || code.isEmpty) return;

    // Extract first line only (handle multi-line QR codes)
    final String firstLine = code.split('\n').first.trim();

    if (firstLine.isEmpty) return;

    // Short gap between any two codes, so one card can leave the frame
    final now = DateTime.now();
    if (now.difference(_lastHandled) < AppConstants.scanGlobalGap) return;

    // Ignore a card that is still held in view
    final lastSeen = _recentCodes[firstLine];
    if (lastSeen != null &&
        now.difference(lastSeen) < AppConstants.scanSameCodeLock) {
      return;
    }

    _busy = true;
    try {
      final result = await _scannerService.processScan(
        rawValue: firstLine,
        format: barcode.format,
      );

      if (!mounted) return;

      final handledAt = DateTime.now();
      _lastHandled = handledAt;
      _recentCodes[firstLine] = handledAt;
      // Forget codes whose lock has expired so the map stays small
      _recentCodes.removeWhere((_, seenAt) =>
          handledAt.difference(seenAt) >= AppConstants.scanSameCodeLock);

      if (result.success && result.student != null) {
        _soundService.playSuccess();
        _vibrate(200);
        _showFeedback(
          _ScanFeedback(
            id: ++_feedbackCounter,
            success: true,
            title: 'تم تسجيل الحضور',
            message: result.student!.studentName,
            detail: firstLine,
          ),
          const Duration(milliseconds: 1500),
        );
        ref.read(attendanceRecordsProvider.notifier).refresh();
      } else {
        if (result.errorType == ScanErrorType.alreadyScanned) {
          _soundService.playDuplicate();
        } else {
          _soundService.playError();
        }
        _vibrate(500);
        _showFeedback(
          _ScanFeedback(
            id: ++_feedbackCounter,
            success: false,
            title: 'فشل المسح',
            message: result.errorMessage ?? 'خطأ غير معروف',
          ),
          const Duration(milliseconds: 2500),
        );
      }
    } finally {
      _busy = false;
    }
  }

  void _vibrate(int milliseconds) {
    if (_hasVibrator) {
      Vibration.vibrate(duration: milliseconds);
    }
  }

  /// Show a result card over the camera; a newer scan replaces it immediately
  void _showFeedback(_ScanFeedback feedback, Duration visibleFor) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = feedback);
    _feedbackTimer = Timer(visibleFor, () {
      if (mounted) {
        setState(() => _feedback = null);
      }
    });
  }

  void _showInfo() {
    // Built from the constants so the text always matches the real timings
    final lockSeconds = AppConstants.scanSameCodeLock.inSeconds;
    final gapSeconds =
        (AppConstants.scanGlobalGap.inMilliseconds / 1000).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات الماسح'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'الأنواع المدعومة:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• QR Code'),
              const Text('• Code 128'),
              const Text('• Code 39'),
              const Text('• EAN-13'),
              const Text('• EAN-8'),
              const Text('• UPC-A / UPC-E'),
              const Text('• وأنواع أخرى...'),
              const SizedBox(height: 16),
              const Text(
                'نصائح:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• أمسك الكاميرا بثبات'),
              const Text('• تأكد من الإضاءة الجيدة'),
              const Text('• أبق الرمز داخل الإطار'),
              const Text('• استخدم الفلاش في الإضاءة المنخفضة'),
              const SizedBox(height: 16),
              const Text(
                'الميزات:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• اكتشاف تلقائي'),
              Text('• تجاهل نفس الرمز لمدة $lockSeconds ثوانٍ'),
              Text('• قبول الرمز التالي بعد $gapSeconds ثانية'),
              const Text('• تغذية راجعة بصرية وحسية'),
              const Text('• مسح متعدد الأنواع'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

/// Labelled round button for the scanner's bottom controls
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          icon: Icon(icon),
          iconSize: 28,
          onPressed: onPressed,
          style: highlighted
              ? IconButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Result of one scan, shown briefly over the camera
class _ScanFeedback {
  final int id; // Unique per scan so AnimatedSwitcher swaps cards
  final bool success;
  final String title;
  final String message;
  final String? detail;

  const _ScanFeedback({
    required this.id,
    required this.success,
    required this.title,
    required this.message,
    this.detail,
  });
}

/// Card used for both success and error scan results
class _ScanFeedbackCard extends StatelessWidget {
  final _ScanFeedback feedback;

  const _ScanFeedbackCard({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final color = feedback.success ? Colors.green : Colors.red;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Icon(
              feedback.success ? Icons.check_circle : Icons.error,
              color: color,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feedback.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback.message,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (feedback.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      feedback.detail!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for scanner overlay
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    // Draw overlay with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(scanArea.left, scanArea.top + cornerLength),
      Offset(scanArea.left, scanArea.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left, scanArea.top),
      Offset(scanArea.left + cornerLength, scanArea.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanArea.right - cornerLength, scanArea.top),
      Offset(scanArea.right, scanArea.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right, scanArea.top),
      Offset(scanArea.right, scanArea.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanArea.left, scanArea.bottom - cornerLength),
      Offset(scanArea.left, scanArea.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left, scanArea.bottom),
      Offset(scanArea.left + cornerLength, scanArea.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanArea.right - cornerLength, scanArea.bottom),
      Offset(scanArea.right, scanArea.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right, scanArea.bottom - cornerLength),
      Offset(scanArea.right, scanArea.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
