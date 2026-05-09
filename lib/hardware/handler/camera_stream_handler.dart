// lib/hardware/handler/camera_stream_handler.dart

import 'dart:async';
import 'package:camera/camera.dart';
import '../controller/camera_manager.dart';

/// CameraStreamHandler adalah jembatan antara [CameraManager] (Role 1)
/// dan inference pipeline milik Role 2 (APDInterpreter / IsolateRunner).
///
/// Tanggung jawab:
/// - Subscribe ke stream CameraImage dari CameraManager
/// - Mencegah frame flooding dengan flag [_isProcessing]
/// - Expose [imageStream] sebagai Stream<CameraImage> untuk Role 2

class CameraStreamHandler {
  final CameraManager _cameraManager;

  final StreamController<CameraImage> _streamController =
      StreamController<CameraImage>.broadcast();

  bool _isProcessing = false;
  bool _isActive = false;

  CameraStreamHandler(this._cameraManager);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Stream CameraImage yang bisa di-listen oleh Role 2.
  /// Menggunakan broadcast agar bisa di-listen lebih dari satu kali.
  Stream<CameraImage> get imageStream => _streamController.stream;

  /// Mulai mengalirkan frame dari kamera.
  /// Harus dipanggil setelah [CameraManager.initialize()] selesai.
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    await _cameraManager.startImageStream((CameraImage image) {
      // Guard: skip frame jika frame sebelumnya masih diproses
      // Ini mencegah antrean frame menumpuk di memory
      if (_isProcessing) return;
      _isProcessing = true;
      _streamController.add(image);
    });
  }

  /// Sinyal bahwa frame telah selesai diproses oleh Role 2.
  /// Harus dipanggil oleh InferenceEngine setelah inference selesai.
  void markFrameProcessed() {
    _isProcessing = false;
  }

  /// Hentikan streaming.
  Future<void> stop() async {
    if (!_isActive) return;
    _isActive = false;
    _isProcessing = false;
    await _cameraManager.stopImageStream();
  }

  /// Bersihkan resource. Dipanggil bersamaan dengan dispose widget.
  Future<void> dispose() async {
    await stop();
    await _streamController.close();
  }
}
