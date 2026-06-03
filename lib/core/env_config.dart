// Single source of truth untuk semua konstanta runtime aplikasi.
//
// Cara pakai:
//   await dotenv.load(fileName: '.env');
//   final threshold = EnvConfig.confidenceThreshold;

import 'package:flutter_dotenv/flutter_dotenv.dart';

const double _kDefaultConfidenceThreshold = 0.5;
const double _kDefaultIouThreshold = 0.45;
const int _kDefaultModelInputSize = 320;

const String _kDefaultModelPath = 'assets/models/apd_yolov8n.tflite';

const String _kDefaultLabelPath = 'assets/labels/apd_labels.txt';

class EnvConfig {
  EnvConfig._();

  // ── AI / Model ────────────────────────────────────────────────────────────

  /// Minimum confidence score agar deteksi dianggap valid.
  static double get confidenceThreshold =>
      _parseDouble('CONFIDENCE_THRESHOLD', _kDefaultConfidenceThreshold);

  /// Threshold IoU untuk Non-Maximum Suppression.
  static double get iouThreshold =>
      _parseDouble('IOU_THRESHOLD', _kDefaultIouThreshold);

  /// Resolusi input model (width = height karena square).
  static int get modelInputSize =>
      _parseInt('MODEL_INPUT_SIZE', _kDefaultModelInputSize);

  /// Path asset model TFLite.
  static String get modelPath => dotenv.env['MODEL_PATH'] ?? _kDefaultModelPath;

  /// Path asset label model.
  static String get labelPath => dotenv.env['LABEL_PATH'] ?? _kDefaultLabelPath;

  /// MongoDB URL.
  static String get mongoUrl => dotenv.env['MONGO_URL'] ?? '';

  // ── Overlay ──────────────────────────────────────────────────────

  /// Durasi feedback vibrasi dalam milidetik.
  static int get vibrationDurationMs => _parseInt('VIBRATION_DURATION_MS', 300);

  /// Interval minimum antar feedback vibrasi (ms) agar tidak spam.
  static int get vibrationCooldownMs =>
      _parseInt('VIBRATION_COOLDOWN_MS', 2000);

  // ── Private Helpers ───────────────────────────────────────────────────────

  static double _parseDouble(String key, double fallback) {
    final raw = dotenv.env[key];
    if (raw == null) return fallback;

    return double.tryParse(raw) ?? fallback;
  }

  static int _parseInt(String key, int fallback) {
    final raw = dotenv.env[key];
    if (raw == null) return fallback;

    return int.tryParse(raw) ?? fallback;
  }
}
