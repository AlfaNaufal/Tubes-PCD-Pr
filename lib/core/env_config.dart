// lib/core/env_config.dart
//
// Centralized environment configuration.
// Single source of truth untuk semua konstanta runtime aplikasi.
//
// Cara pakai:
//   await dotenv.load(fileName: '.env');
//   final threshold = EnvConfig.confidenceThreshold;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konstanta fallback — digunakan saat .env tidak tersedia (unit test / CI).
const _kDefaultConfidenceThreshold = 0.5;
const _kDefaultIouThreshold = 0.45;
const _kDefaultModelInputSize = 320;
const _kDefaultModelPath = 'assets/models/apd_yolov8n.tflite';
const _kDefaultLabelPath = 'assets/labels/apd_labels.txt';

class EnvConfig {
  // Konstruktor privat — class ini hanya berisi static members.
  EnvConfig._();

  // ── AI / Model ────────────────────────────────────────────────────────────

  /// Minimum confidence score agar deteksi dianggap valid.
  static double get confidenceThreshold => _parseDouble(
        'CONFIDENCE_THRESHOLD',
        _kDefaultConfidenceThreshold,
      );

  /// Threshold IoU untuk Non-Maximum Suppression.
  static double get iouThreshold => _parseDouble(
        'IOU_THRESHOLD',
        _kDefaultIouThreshold,
      );

  /// Resolusi input model (width = height karena square).
  static int get modelInputSize => _parseInt(
        'MODEL_INPUT_SIZE',
        _kDefaultModelInputSize,
      );

  /// Path asset model TFLite.
  static String get modelPath =>
      dotenv.env['MODEL_PATH'] ?? _kDefaultModelPath;

  /// Path asset label text.
  static String get labelPath =>
      dotenv.env['LABEL_PATH'] ?? _kDefaultLabelPath;

  // ── Network ───────────────────────────────────────────────────────────────

  /// URL MongoDB Atlas untuk sync (digunakan Role 4).
  static String get mongoUrl => dotenv.env['MONGO_URL'] ?? '';

  // ── Overlay (Role 3) ──────────────────────────────────────────────────────

  /// Durasi feedback vibrasi dalam milidetik.
  static int get vibrationDurationMs => _parseInt(
        'VIBRATION_DURATION_MS',
        300,
      );

  /// Interval minimum antar feedback vibrasi (ms) agar tidak spam.
  static int get vibrationCooldownMs => _parseInt(
        'VIBRATION_COOLDOWN_MS',
        2000,
      );

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