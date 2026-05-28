// lib/overlay/feedback_service.dart
//
// Feedback haptik dan status visual berdasarkan hasil deteksi APD.
//
// ── Tanggung jawab ──────────────────────────────────────────────────────────
//   - Memberikan vibrasi ketika ada ketidakpatuhan APD terdeteksi
//   - Menerapkan cooldown agar vibrasi tidak spam setiap frame
//   - Menyediakan warna status bar overlay sesuai kondisi
//   - Tidak menyimpan state UI — hanya side effect & pure computation
//
// ── Dependency ──────────────────────────────────────────────────────────────
//   pubspec.yaml: vibration: ^2.0.0

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../core/env_config.dart';
import 'apd_painter.dart' show ApdColorScheme;
import 'coordinate_mapper.dart' show MappedBox;

// ── Enum Status Kepatuhan ──────────────────────────────────────────────────

/// Status kepatuhan keseluruhan dari satu frame deteksi.
enum ComplianceStatus {
  /// Tidak ada objek yang terdeteksi (kamera kosong / confidence terlalu rendah).
  noDetection,

  /// Semua APD yang terdeteksi dalam kondisi patuh.
  compliant,

  /// Minimal satu APD tidak terpasang.
  nonCompliant,
}

// ── Warna per Status ───────────────────────────────────────────────────────

/// Konstanta warna UI untuk tiap status kepatuhan.
extension ComplianceStatusColor on ComplianceStatus {
  /// Warna utama status bar overlay.
  Color get primaryColor => switch (this) {
        ComplianceStatus.noDetection => const Color(0xFF546E7A),    // abu-abu
        ComplianceStatus.compliant => const Color(0xFF00C853),       // hijau
        ComplianceStatus.nonCompliant => const Color(0xFFD50000),    // merah
      };

  /// Warna latar semi-transparan untuk status banner.
  Color get backgroundColor => switch (this) {
        ComplianceStatus.noDetection =>
          const Color(0xFF546E7A).withOpacity(0.75),
        ComplianceStatus.compliant =>
          const Color(0xFF00C853).withOpacity(0.80),
        ComplianceStatus.nonCompliant =>
          const Color(0xFFD50000).withOpacity(0.85),
      };

  /// Label teks singkat untuk status banner.
  String get displayText => switch (this) {
        ComplianceStatus.noDetection => 'Menunggu Deteksi...',
        ComplianceStatus.compliant => '✓ APD Lengkap',
        ComplianceStatus.nonCompliant => '⚠ APD Tidak Lengkap',
      };
}

// ── Feedback Service ───────────────────────────────────────────────────────

/// Service stateless untuk feedback haptik dan komputasi status kepatuhan.
///
/// Instance tunggal cukup — lifecycle dikelola oleh [OverlayController].
class FeedbackService {
  /// Timestamp vibrasi terakhir, untuk enforcing cooldown.
  DateTime? _lastVibrationAt;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Menghitung [ComplianceStatus] dari daftar [MappedBox].
  ///
  /// Logika:
  ///   - Tidak ada box → [ComplianceStatus.noDetection]
  ///   - Ada box dengan label non-compliant → [ComplianceStatus.nonCompliant]
  ///   - Semua box compliant → [ComplianceStatus.compliant]
  ComplianceStatus evaluate(List<MappedBox> boxes) {
    if (boxes.isEmpty) return ComplianceStatus.noDetection;

    final hasViolation = boxes.any(
      (b) => ApdColorScheme.isNonCompliant(b.label),
    );

    return hasViolation
        ? ComplianceStatus.nonCompliant
        : ComplianceStatus.compliant;
  }

  /// Memicu vibrasi jika status [nonCompliant] dan cooldown sudah lewat.
  ///
  /// Cooldown diambil dari [EnvConfig.vibrationCooldownMs] agar bisa
  /// dikonfigurasi via .env tanpa rebuild.
  ///
  /// [status] harus dihitung lebih dulu via [evaluate].
  Future<void> triggerFeedback(ComplianceStatus status) async {
    if (status != ComplianceStatus.nonCompliant) return;
    if (!_isCooldownElapsed()) return;

    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    _lastVibrationAt = DateTime.now();

    await Vibration.vibrate(
      pattern: [0, EnvConfig.vibrationDurationMs, 100, EnvConfig.vibrationDurationMs],
      intensities: [0, 200, 0, 128],
    );
  }

  /// Hentikan vibrasi yang sedang berjalan (dipanggil saat dispose).
  Future<void> cancelFeedback() async {
    await Vibration.cancel();
  }

  // ── Private Helpers ─────────────────────────────────────────────────────

  bool _isCooldownElapsed() {
    if (_lastVibrationAt == null) return true;
    final elapsed = DateTime.now().difference(_lastVibrationAt!).inMilliseconds;
    return elapsed >= EnvConfig.vibrationCooldownMs;
  }
}