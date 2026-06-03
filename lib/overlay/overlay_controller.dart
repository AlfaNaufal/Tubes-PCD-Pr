// lib/overlay/overlay_controller.dart
//
// ChangeNotifier yang menjadi pusat integrasi Role 3.
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
  // ── Dependencies ───────────────────────────────────────────────────────────

  final FeedbackService _feedbackService;

  // ── State Publik ───────────────────────────────────────────────────────────

  /// Bounding box yang sudah dikonversi ke screen space — siap digambar.
  List<MappedBox> get mappedBoxes => List.unmodifiable(_mappedBoxes);
  List<MappedBox> _mappedBoxes = const [];

  /// Status kepatuhan dari frame terakhir.
  ComplianceStatus get complianceStatus => _complianceStatus;
  ComplianceStatus _complianceStatus = ComplianceStatus.noDetection;

  /// Hasil mentah dari inference terakhir (dibutuhkan Role 4 untuk Hive).
  List<ApdResult> get lastResults => List.unmodifiable(_lastResults);
  List<ApdResult> _lastResults = const [];

  /// Bytes JPEG dari capture laporan (null jika belum ada capture).
  /// Role 4 mengambil nilai ini setelah [captureForReport] dipanggil.
  Uint8List? get capturedImageBytes => _capturedImageBytes;
  Uint8List? _capturedImageBytes;

  /// Apakah ada capture baru yang belum dikonsumsi oleh Role 4.
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
  ///
  /// Harus dipanggil setelah [IsolateRunner.init()] selesai.
  void startListening() {
    _inferenceSubscription?.cancel();
    _inferenceSubscription = IsolateRunner.reportStream.listen(
      _onInferenceResult,
      onError: _onInferenceError,
    );
  }

  /// Hentikan listener tanpa dispose controller.
  void stopListening() {
    _inferenceSubscription?.cancel();
    _inferenceSubscription = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    stopListening();
    await _feedbackService.cancelFeedback();
    super.dispose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Update ukuran widget overlay (dipanggil dari LayoutBuilder di widget).
  void updateWidgetSize(Size size) {
    if (_widgetSize == size) return;
    _widgetSize = size;
    _remapBoxes(); // remap ulang karena ukuran berubah
  }

  /// Update ukuran preview kamera dari CameraManager.previewSize.
  void updatePreviewSize(Size? size) {
    if (_previewSize == size) return;
    _previewSize = size;
    _remapBoxes();
  }

  /// Minta isolate untuk menyimpan frame berikutnya sebagai laporan.
  /// Bytes JPEG akan tersedia di [capturedImageBytes] setelah frame berikutnya.
  void captureForReport() {
    IsolateRunner.captureForReport();
  }

  /// Konsumsi [capturedImageBytes] — mengembalikan nilai lalu menghapusnya.
  ///
  /// Role 4 memanggil ini setelah menyimpan gambar ke Hive/MongoDB:
  /// ```dart
  /// final bytes = overlayController.consumeCapture();
  /// if (bytes != null) await inspectionService.saveSnapshot(bytes);
  /// ```
  Uint8List? consumeCapture() {
    final bytes = _capturedImageBytes;
    _capturedImageBytes = null;
    return bytes;
  }

  // ── Internal: Inference Handler ────────────────────────────────────────────

  void _onInferenceResult(IsolateResponse response) {
    if (_disposed) return;

    _lastResults = response.results;

    // Simpan capture bytes jika ini adalah capture response.
    if (response.isCaptureResponse && response.capturedImageBytes != null) {
      _capturedImageBytes = response.capturedImageBytes;
    }

    _remapBoxes();

    // Hitung status dan trigger feedback (fire-and-forget).
    final status = _feedbackService.evaluate(_mappedBoxes);
    if (status != _complianceStatus) {
      _complianceStatus = status;
    }
    _feedbackService.triggerFeedback(status); // intentionally not awaited

    if (!_disposed) notifyListeners();
  }

  void _onInferenceError(Object error, StackTrace stack) {
    debugPrint('[OverlayController] Inference stream error: $error\n$stack');
  }

  // ── Internal: Coordinate Remapping ────────────────────────────────────────

  /// Panggil ulang CoordinateMapper dengan ukuran terkini.
  /// Aman dipanggil kapan saja — guard null tersedia.
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