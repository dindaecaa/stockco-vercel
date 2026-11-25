
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../inventory/add_sku_screen.dart';
import 'scan_result_screen.dart';

class ScannerCameraScreen extends StatefulWidget {
  final bool returnBarcodeOnly;

  const ScannerCameraScreen({
    super.key,
    this.returnBarcodeOnly = false,
  });

  @override
  State<ScannerCameraScreen> createState() =>
      _ScannerCameraScreenState();
}

class _ScannerCameraScreenState extends State<ScannerCameraScreen> {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3001';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

  late final MobileScannerController _controller;

  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();

    _controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      torchEnabled: false,
      autoZoom: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // =========================================================
  // AUTHENTICATION
  // =========================================================

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();

     final token = prefs.getString('token')?.trim();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Token login tidak ditemukan. Silakan login kembali.',
      );
    }

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // =========================================================
  // BARCODE DETECTED
  // =========================================================

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.first.rawValue?.trim();

    if (barcode == null || barcode.isEmpty) {
      return;
    }

    _isProcessing = true;

    try {
      await _controller.stop();

      if (!mounted) return;

      // Mode khusus untuk mengembalikan barcode ke halaman pemanggil.
      // Tidak membutuhkan request API di halaman scanner.
      if (widget.returnBarcodeOnly) {
        Navigator.pop(context, barcode);
        return;
      }

      final headers = await _getAuthHeaders();

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/products'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil data barang (${response.statusCode}): '
          '${response.body}',
        );
      }

      final body = jsonDecode(response.body);

      if (body is! Map ||
          body['success'] != true ||
          body['data'] is! List) {
        throw Exception(
          body is Map
              ? body['message']?.toString() ??
                  'Format respons API produk tidak sesuai.'
              : 'Format respons API produk tidak valid.',
        );
      }

      Map<String, dynamic>? foundProduct;

      for (final item in body['data']) {
        if (item is Map) {
          final product = Map<String, dynamic>.from(item);
          final sku = product['sku']?.toString().trim();

          if (sku != null &&
              sku.toLowerCase() == barcode.toLowerCase()) {
            foundProduct = product;
            break;
          }
        }
      }

      if (!mounted) return;

      if (foundProduct != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              product: foundProduct!,
              barcode: barcode,
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddSkuScreen(
              scannedSku: barcode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa barcode: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted && !widget.returnBarcodeOnly) {
        _isProcessing = false;

        try {
          await _controller.start();
        } catch (_) {
          // Kamera mungkin sudah tidak tersedia.
        }
      }
    }
  }

  // =========================================================
  // FLASHLIGHT
  // =========================================================

  Future<void> _toggleFlashlight() async {
    try {
      await _controller.toggleTorch();

      if (!mounted) return;

      setState(() {
        _torchOn = !_torchOn;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Flashlight tidak tersedia: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                fit: BoxFit.cover,
                onDetect: _onDetect,
              ),
            ),

            // OVERLAY GELAP
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(),
                ),
              ),
            ),

            // HEADER
            Positioned(
              top: 15,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Text(
                      'Scan QR/Barcode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 31,
                        height: 31,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF69717B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BINGKAI BARCODE
            Center(
              child: SizedBox(
                width: 300,
                height: 170,
                child: CustomPaint(
                  painter: _ScannerFramePainter(),
                ),
              ),
            ),

            // FLASHLIGHT
            Positioned(
              bottom: 135,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleFlashlight,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      _torchOn
                          ? Icons.flashlight_on
                          : Icons.flashlight_off_outlined,
                      size: 23,
                      color: const Color(0xFF587B55),
                    ),
                  ),
                ),
              ),
            ),

            // PETUNJUK
            const Positioned(
              bottom: 76,
              left: 30,
              right: 30,
              child: Text(
                'Arahkan kamera ke barcode atau QR\ncode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            // STATUS SCANNER
            Positioned(
              bottom: 27,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 7,
                        height: 7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF8ED19A),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isProcessing
                            ? 'Memeriksa database...'
                            : 'Mencari barcode...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// SCANNER FRAME
// =============================================================

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    const cornerLength = 34.0;
    const radius = 18.0;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const left = 1.5;
    const top = 1.5;
    final right = size.width - 1.5;
    final bottom = size.height - 1.5;

    canvas.drawPath(
      Path()
        ..moveTo(left + cornerLength, top)
        ..lineTo(left + radius, top)
        ..quadraticBezierTo(left, top, left, top + radius)
        ..lineTo(left, top + cornerLength),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, top)
        ..lineTo(right - radius, top)
        ..quadraticBezierTo(right, top, right, top + radius)
        ..lineTo(right, top + cornerLength),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cornerLength)
        ..lineTo(left, bottom - radius)
        ..quadraticBezierTo(left, bottom, left + radius, bottom)
        ..lineTo(left + cornerLength, bottom),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(right, bottom - cornerLength)
        ..lineTo(right, bottom - radius)
        ..quadraticBezierTo(right, bottom, right - radius, bottom)
        ..lineTo(right - cornerLength, bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================
// CAMERA OVERLAY
// =============================================================

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.42);

    const scanWidth = 300.0;
    const scanHeight = 170.0;

    final left = (size.width - scanWidth) / 2;
    final top = (size.height - scanHeight) / 2;

    final fullRect = Offset.zero & size;

    final scanRect = Rect.fromLTWH(
      left,
      top,
      scanWidth,
      scanHeight,
    );

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(
        RRect.fromRectAndRadius(
          scanRect,
          const Radius.circular(18),
        ),
      );

    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
