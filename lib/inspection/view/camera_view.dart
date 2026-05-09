// lib/inspection/view/camera_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import '../../hardware/controller/camera_manager.dart';
import '../../hardware/handler/camera_stream_handler.dart';

// ── Stub types untuk integrasi dengan Role 2 & 3 ─────────────────────────────
// Uncomment dan sesuaikan path import saat Role 2 & 3 sudah siap.
//
// import '../../inference/service/apd_result.dart';
// import '../../inspection/controller/inspection_controller.dart';
// import '../../overlay/painter/bbox_painter.dart';

/// Placeholder APDResult — hapus saat Role 2 sudah punya file aslinya
class APDResult {
  final String label;
  final double confidence;
  final Rect bbox;
  const APDResult({
    required this.label,
    required this.confidence,
    required this.bbox,
  });
}

/// CameraView adalah halaman utama untuk Petugas K3.
///
/// Lifecycle:
/// - [didChangeDependencies]: panggil CameraManager.initialize()
/// - [dispose]: panggil CameraManager.disposeCamera() + StreamHandler.dispose()
///
/// Integrasi:
/// - CameraStreamHandler.start() → stream ke Role 2
/// - Hasil deteksi (List<APDResult>) → diteruskan ke BBoxPainter (Role 3)
class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late final CameraManager _cameraManager;
  late final CameraStreamHandler _streamHandler;

  // Hasil deteksi dari Role 2 (diupdate via callback/stream)
  List<APDResult> _detectionResults = [];

  @override
  void initState() {
    super.initState();
    _cameraManager = CameraManager();
    _streamHandler = CameraStreamHandler(_cameraManager);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _cameraManager.initialize();

    if (_cameraManager.isReady) {
      await _streamHandler.start();
      _listenToInferenceResults();
    }
  }

  /// Role 2 akan expose stream atau callback hasil inference.
  /// Uncomment dan sambungkan ke InspectionController saat Role 2 siap.
  void _listenToInferenceResults() {
    // Contoh integrasi (aktifkan saat Role 2 siap):
    //
    // final inspController = context.read<InspectionController>();
    // inspController.resultsStream.listen((results) {
    //   if (mounted) {
    //     setState(() => _detectionResults = results);
    //     _streamHandler.markFrameProcessed();
    //   }
    // });
  }

  @override
  void dispose() {
    // FR-01: Dispose kamera dan stream saat widget unmount
    _streamHandler.dispose();
    _cameraManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _cameraManager,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<CameraManager>(
          builder: (context, cam, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Camera Preview ─────────────────────────────────
                _buildCameraPreview(cam),

                // ── Bounding Box Overlay (FR-03) ───────────────────
                // Uncomment saat Role 3 (BBoxPainter) sudah siap:
                //
                // if (_detectionResults.isNotEmpty && cam.previewSize != null)
                //   CustomPaint(
                //     painter: BBoxPainter(
                //       results: _detectionResults,
                //       previewSize: cam.previewSize!,
                //       screenSize: MediaQuery.of(context).size,
                //     ),
                //   ),

                // ── Status Overlay ─────────────────────────────────
                _buildStatusOverlay(cam),

                // ── Top Bar ────────────────────────────────────────
                _buildTopBar(context),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _buildCameraPreview(CameraManager cam) {
    if (cam.status == CameraStatus.initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFB800)),
            SizedBox(height: 16),
            Text(
              'Menginisialisasi kamera...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (cam.status == CameraStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                cam.errorMessage ?? 'Kamera tidak tersedia.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!cam.isReady || cam.controller == null) {
      return const SizedBox.shrink();
    }

    // Preview memenuhi layar (cover mode)
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: cam.controller!.value.previewSize!.height,
          height: cam.controller!.value.previewSize!.width,
          child: CameraPreview(cam.controller!),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap:
                  () => Navigator.of(
                    context,
                  ).pushReplacementNamed('/inspection/home'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Deteksi APD Real-time',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'YOLOv8 Nano · Edge Inference',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00C853), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Color(0xFF00C853), size: 8),
                  SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFF00C853),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverlay(CameraManager cam) {
    if (cam.status == CameraStatus.paused) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 40),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            'Kamera dijeda · Buka aplikasi untuk melanjutkan',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
