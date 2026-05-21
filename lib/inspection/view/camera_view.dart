import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../core/env_config.dart';

import '../../hardware/controller/camera_manager.dart';
import '../../hardware/handler/camera_stream_handler.dart';

import '../../inference/service/isolate_runner.dart';
import '../../inference/model/apd_result.dart';
import '../../auth/controller/auth_controller.dart';
import '../../supervisor/controller/dashboard_controller.dart';
import '../../inspection/model/report_model.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late final CameraManager _cameraManager;
  late final CameraStreamHandler _streamHandler;
  List<ApdResult> _detectionResults = [];
  bool _isCapturing = false;
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _cameraManager = CameraManager();
    _streamHandler = CameraStreamHandler(_cameraManager);
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _cameraManager.initialize();

    if (_cameraManager.isReady) {
      await IsolateRunner.init(
        modelPath: Env.modelPath,
        labelPath: Env.labelPath,
        modelInputSize: Env.modelInputSize,
        confidenceThreshold: Env.confidenceThreshold,
      );

      await _streamHandler.start();
      _listenToInferenceResults();
    }
  }

  void _listenToInferenceResults() {
    IsolateRunner.reportStream.listen((response) async {
      if (!mounted || response.capturedImageBytes == null) return;
      await _streamHandler.start();
      if (mounted) setState(() => _isCapturing = false);
      _showReportPreviewDialog(response.capturedImageBytes!, response.results);
    });

    _streamHandler.imageStream.listen((image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      try {
        final results = await IsolateRunner.process(image);
        if (mounted && !_isCapturing) {
          setState(() => _detectionResults = results);
        }
      } catch (e) {
        debugPrint('Error: $e');
      } finally {
        _isProcessingFrame = false;
        _streamHandler.markFrameProcessed();
      }
    });
  }

  @override
  void dispose() {
    IsolateRunner.dispose();
    _streamHandler.dispose();
    _cameraManager.dispose();
    super.dispose();
  }

  void _showReportPreviewDialog(Uint8List imageBytes, List<ApdResult> results) {
    final nameController = TextEditingController();
    final siteController = TextEditingController();
    final divisionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            title: const Text(
              'Kirim Laporan HSE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(imageBytes, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: _buildInputDecoration(
                          'Nama Pekerja',
                          Icons.person_outline,
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Nama tidak boleh kosong'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: siteController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: _buildInputDecoration(
                          'Site / Lokasi Kerja',
                          Icons.location_on_outlined,
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Site tidak boleh kosong'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: divisionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: _buildInputDecoration(
                          'Divisi / Vendor',
                          Icons.business_outlined,
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Divisi tidak boleh kosong'
                                    : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Color(0xFF8B949E)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final auth = context.read<AuthController>();

                    final newReport = ReportModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      timestamp: DateTime.now(),
                      imageBytes: imageBytes,
                      detections: results,
                      inspectorName: auth.currentUser?.name ?? 'Inspector',
                      workerName: nameController.text.trim(),
                      site: siteController.text.trim(),
                      division: divisionController.text.trim(),
                    );

                    context.read<DashboardController>().addReport(newReport);
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Laporan berhasil disimpan offline!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Kirim'),
              ),
            ],
          ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFFFFB800), size: 18),
      filled: true,
      fillColor: const Color(0xFF0D1117),
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFFFB800)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _cameraManager,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<CameraManager>(
          builder: (context, cam, _) {
            if (!cam.isReady)
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildCameraPreview(cam),
                _buildStatusOverlay(cam),
                _buildTopBar(context),
              ],
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton(
          backgroundColor: _isCapturing ? Colors.grey : const Color(0xFFFFB800),
          onPressed:
              _isCapturing
                  ? null
                  : () async {
                    setState(() => _isCapturing = true);
                    await Future.delayed(const Duration(milliseconds: 300));
                    IsolateRunner.captureForReport();
                  },
          child:
              _isCapturing
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
                  )
                  : const Icon(Icons.camera_alt, color: Colors.black, size: 28),
        ),
      ),
    );
  }

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

    if (!cam.isReady || cam.controller == null) return const SizedBox.shrink();

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
          margin: const EdgeInsets.only(bottom: 100),
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
