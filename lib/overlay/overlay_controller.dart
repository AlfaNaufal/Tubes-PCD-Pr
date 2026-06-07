//
// ── Tanggung jawab ──────────────────────────────────────────────────────────
//   - Subscribe ke IsolateRunner.reportStream (hasil inference dari Role 2)
//   - Memanggil CoordinateMapper untuk konversi koordinat
//   - Memanggil FeedbackService untuk vibrasi dan status
//   - Expose state siap-pakai ke ApdOverlayWidget
//   - Menjadi handoff point ke Role 4 (expose lastResults + capturedImage)
//
// ── Tidak boleh ────────────────────────────────────────────────────────────
//   - Menggambar UI secara langsung
//   - Mengakses CameraController secara langsung
//   - Menyentuh TFLite / isolate langsung

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../inference/model/apd_result.dart';
import '../inference/service/isolate_runner.dart';
import 'coordinate_mapper.dart';
import 'feedback_service.dart';

class OverlayController extends ChangeNotifier {
  final FeedbackService _feedbackService;

  // ── State Publik ───────────────────────────────────────────────────────────

  /// Bounding box yang sudah dikonversi ke screen space
  List<MappedBox> get mappedBoxes => List.unmodifiable(_mappedBoxes);
  List<MappedBox> _mappedBoxes = const [];

  /// Status kepatuhan dari frame terakhir.
  ComplianceStatus get complianceStatus => _complianceStatus;
  ComplianceStatus _complianceStatus = ComplianceStatus.noDetection;

  /// Hasil mentah dari inference terakhir
  List<ApdResult> get lastResults => List.unmodifiable(_lastResults);
  List<ApdResult> _lastResults = const [];

  /// Bytes JPEG dari capture laporan (null jika belum ada capture).
  Uint8List? get capturedImageBytes => _capturedImageBytes;
  Uint8List? _capturedImageBytes;

  bool get hasPendingCapture => _capturedImageBytes != null;

  /// Ukuran widget overlay saat ini — diupdate oleh [updateWidgetSize].
  Size? get widgetSize => _widgetSize;
  Size? _widgetSize;

  /// Ukuran preview kamera — diupdate oleh [updatePreviewSize].
  Size? get previewSize => _previewSize;
  Size? _previewSize;

  // ── Internal ───────────────────────────────────────────────────────────────

  StreamSubscription<IsolateResponse>? _inferenceSubscription;
  bool _disposed = false;

  // ── Constructor ────────────────────────────────────────────────────────────

  OverlayController({FeedbackService? feedbackService})
    : _feedbackService = feedbackService ?? FeedbackService();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Mulai mendengarkan stream inference dari IsolateRunner.
  /// Harus dipanggil setelah [IsolateRunner.init()] selesai.
  void startListening() {
    _inferenceSubscription?.cancel();
    _inferenceSubscription = IsolateRunner.reportStream.listen(
      _onInferenceResult,
      onError: _onInferenceError,
    );
  }

  void stopListening() {
    _inferenceSubscription?.cancel();
    _inferenceSubscription = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stopListening();

    _feedbackService.cancelFeedback();

    super.dispose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Update ukuran widget overlay (dipanggil dari LayoutBuilder di widget).
  void updateWidgetSize(Size size) {
    if (_widgetSize == size) return;
    _widgetSize = size;
    _remapBoxes();
  }

  void updatePreviewSize(Size? size) {
    if (_previewSize == size) return;
    _previewSize = size;
    _remapBoxes();
  }

  void captureForReport() {
    IsolateRunner.captureForReport();
  }

  Uint8List? consumeCapture() {
    final bytes = _capturedImageBytes;
    _capturedImageBytes = null;
    return bytes;
  }

  // ── Internal: Inference Handler ────────────────────────────────────────────

  void _onInferenceResult(IsolateResponse response) {
    if (_disposed) return;

    _lastResults = response.results;

    if (response.isCaptureResponse && response.capturedImageBytes != null) {
      _capturedImageBytes = response.capturedImageBytes;
    }

    _remapBoxes();

    final status = _feedbackService.evaluate(_mappedBoxes);
    if (status != _complianceStatus) {
      _complianceStatus = status;
    }
    _feedbackService.triggerFeedback(status);

    if (!_disposed) notifyListeners();
  }

  void _onInferenceError(Object error, StackTrace stack) {
    debugPrint('[OverlayController] Inference stream error: $error\n$stack');
  }

  // ── Internal: Coordinate Remapping ────────────────────────────────────────

  void _remapBoxes() {
    if (_previewSize == null || _widgetSize == null) {
      _mappedBoxes = const [];
      return;
    }

    _mappedBoxes = CoordinateMapper.mapAll(
      results: _lastResults,
      previewSize: _previewSize!,
      widgetSize: _widgetSize!,
    );
  }
}
