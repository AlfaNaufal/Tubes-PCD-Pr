// Feedback dan status visual berdasarkan hasil deteksi APD
//
// ── Tanggung jawab ──────────────────────────────────────────────────────────
//   - Memberikan vibrasi ketika ada ketidakpatuhan APD terdeteksi
//   - Menerapkan cooldown agar vibrasi tidak spam setiap frame
//   - Menyediakan warna status bar overlay sesuai kondisi
//   - Tidak menyimpan state UI — hanya side effect & pure computation

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../core/env_config.dart';
import 'coordinate_mapper.dart' show MappedBox;

// ── Enum Status Kepatuhan ──────────────────────────────────────────────────

/// Status kepatuhan keseluruhan dari satu frame deteksi.
enum ComplianceStatus { noDetection, compliant, nonCompliant }

// ── Warna per Status ───────────────────────────────────────────────────────

extension ComplianceStatusColor on ComplianceStatus {
  Color get primaryColor => switch (this) {
    ComplianceStatus.noDetection => const Color(0xFF546E7A),
    ComplianceStatus.compliant => const Color(0xFF00C853),
    ComplianceStatus.nonCompliant => const Color(0xFFD50000),
  };

  /// Warna latar semi-transparan untuk status banner.
  Color get backgroundColor => switch (this) {
    ComplianceStatus.noDetection => const Color(0xFF546E7A).withOpacity(0.75),
    ComplianceStatus.compliant => const Color(0xFF00C853).withOpacity(0.80),
    ComplianceStatus.nonCompliant => const Color(0xFFD50000).withOpacity(0.85),
  };

  /// Label teks singkat untuk status banner
  String get displayText => switch (this) {
    ComplianceStatus.noDetection => 'Menunggu Deteksi...',
    ComplianceStatus.compliant => '✓ APD Lengkap',
    ComplianceStatus.nonCompliant => '⚠ APD Tidak Lengkap',
  };
}

// ── Feedback Service ───────────────────────────────────────────────────────

class FeedbackService {
  DateTime? _lastVibrationAt;

  ComplianceStatus evaluate(List<MappedBox> boxes) {
    if (boxes.isEmpty) {
      return ComplianceStatus.noDetection;
    }

    final hasViolation = boxes.any((box) {
      final label = box.label.toLowerCase();

      return label == 'non-helmet' || label == 'bare-arms';
    });

    return hasViolation
        ? ComplianceStatus.nonCompliant
        : ComplianceStatus.compliant;
  }

  /// Memicu vibrasi jika status [nonCompliant] dan cooldown sudah lewat.
  /// Cooldown diambil dari [EnvConfig.vibrationCooldownMs] agar bisa
  /// dikonfigurasi via .env tanpa rebuild.
  Future<void> triggerFeedback(ComplianceStatus status) async {
    if (status != ComplianceStatus.nonCompliant) return;
    if (!_isCooldownElapsed()) return;

    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    _lastVibrationAt = DateTime.now();

    await Vibration.vibrate(
      pattern: [
        0,
        EnvConfig.vibrationDurationMs,
        100,
        EnvConfig.vibrationDurationMs,
      ],
      intensities: [0, 200, 0, 128],
    );
  }

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
