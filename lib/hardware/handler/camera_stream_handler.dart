import 'dart:async';
import 'package:camera/camera.dart';
import '../controller/camera_manager.dart';

/// CameraStreamHandler adalah jembatan antara [CameraManager]
/// dan inference pipeline
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

  Stream<CameraImage> get imageStream => _streamController.stream;

  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    await _cameraManager.startImageStream((CameraImage image) {
      // Skip frame jika frame sebelumnya masih diproses.
      // Mencegah antrean frame menumpuk di memory (FR-05).
      if (_isProcessing) return;
      _isProcessing = true;
      _streamController.add(image);
    });
  }

  void markFrameProcessed() {
    _isProcessing = false;
  }

  /// Hentikan streaming
  Future<void> stop() async {
    if (!_isActive) return;
    _isActive = false;
    _isProcessing = false;
    await _cameraManager.stopImageStream();
  }

  Future<void> dispose() async {
    await stop();
    await _streamController.close();
  }
}
