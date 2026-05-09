// lib/hardware/controller/camera_manager.dart

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Status kamera untuk diobservasi oleh UI
enum CameraStatus { uninitialized, initializing, ready, paused, error }

/// CameraManager bertanggung jawab atas:
/// 1. Inisialisasi CameraController (FR-01)
/// 2. Lifecycle management: init saat halaman dibuka, dispose saat keluar /
///    app background (FR-01)
/// 3. Expose [previewSize] untuk coordinate mapping oleh Role 3
class CameraManager extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? _controller;
  CameraStatus _status = CameraStatus.uninitialized;
  String? _errorMessage;

  // ── Public Getters ────────────────────────────────────────────────────────

  CameraController? get controller => _controller;
  CameraStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isReady => _status == CameraStatus.ready;

  /// Ukuran preview kamera dalam logical pixels.
  /// Dibutuhkan oleh CoordinateMapper (Role 3) untuk scaling bbox.
  Size? get previewSize {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    return Size(
      _controller!.value.previewSize!.height, // height → width (portrait)
      _controller!.value.previewSize!.width,
    );
  }

  // ── Initialization ────────────────────────────────────────────────────────

  /// Inisialisasi kamera.
  /// Dipanggil dari [didChangeDependencies] atau [initState] pada CameraView.
  Future<void> initialize() async {
    if (_status == CameraStatus.initializing || _status == CameraStatus.ready) {
      return;
    }

    _setStatus(CameraStatus.initializing);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setError('Tidak ada kamera yang tersedia.');
        return;
      }

      // Gunakan kamera belakang
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium, // sesuai CAMERA_RESOLUTION=medium
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // FR-01: YUV420 untuk PCD
      );

      await _controller!.initialize();
      WidgetsBinding.instance.addObserver(this);

      _setStatus(CameraStatus.ready);
    } on CameraException catch (e) {
      _setError('Kamera error: ${e.description}');
    } catch (e) {
      _setError('Inisialisasi gagal: $e');
    }
  }

  // ── Stream ────────────────────────────────────────────────────────────────

  /// Mulai streaming CameraImage ke callback.
  /// Callback ini akan di-listen oleh CameraStreamHandler.
  Future<void> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    if (!isReady) return;
    if (_controller!.value.isStreamingImages) return;
    await _controller!.startImageStream(onImage);
  }

  /// Hentikan streaming tanpa dispose controller.
  Future<void> stopImageStream() async {
    if (!isReady) return;
    if (!(_controller?.value.isStreamingImages ?? false)) return;
    await _controller!.stopImageStream();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  /// Dispose kamera sepenuhnya.
  /// Dipanggil saat widget unmount atau app masuk background.
  Future<void> disposeCamera() async {
    WidgetsBinding.instance.removeObserver(this);

    if (_controller != null) {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      await _controller!.dispose();
      _controller = null;
    }

    _setStatus(CameraStatus.uninitialized);
  }

  // ── AppLifecycleObserver ──────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App masuk background → stop stream & dispose
        disposeCamera();
        break;
      case AppLifecycleState.resumed:
        // App kembali ke foreground → re-initialize kamera
        initialize();
        break;
      default:
        break;
    }
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  void _setStatus(CameraStatus s) {
    _status = s;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = CameraStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await disposeCamera();
    super.dispose();
  }
}
