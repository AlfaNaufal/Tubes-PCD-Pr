// lib/overlay/apd_painter.dart
//
// CustomPainter yang menggambar bounding box dan label hasil deteksi APD
// di atas preview kamera.
//
// ── Tanggung jawab ──────────────────────────────────────────────────────────
//   - Menggambar rounded rectangle sebagai bounding box
//   - Menggambar chip label (background + teks) di atas box
//   - Warna bounding box & label ditentukan oleh [ApdColorScheme]
//   - Tidak menyimpan state — murni deterministik dari [boxes]
//
// ── Tidak boleh ────────────────────────────────────────────────────────────
//   - Memanggil setState / notifyListeners
//   - Mengakses stream atau Future
//   - Menyimpan instance variable yang bermutasi

import 'package:flutter/material.dart';
import 'coordinate_mapper.dart';

// ── Warna per Label ────────────────────────────────────────────────────────

/// Definisi warna visual per kategori label APD.
///
/// Konvensi penamaan label mengikuti [apd_labels.txt]:
///   - Label "compliant" (APD terpasang)  → warna hijau
///   - Label "non_compliant" (APD tidak ada) → warna merah
///   - Label tidak dikenal                → abu-abu (fallback)
class ApdColorScheme {
  ApdColorScheme._();

  /// Pemetaan label → warna. Key harus lowercase dan trimmed.
  static const Map<String, Color> _labelColors = {
    // APD Lengkap
    'helm': Color(0xFF00E676),        // hijau cerah
    'rompi': Color(0xFF00E676),
    'sepatu': Color(0xFF00E676),
    'kacamata': Color(0xFF00E676),
    'sarung_tangan': Color(0xFF00E676),
    'masker': Color(0xFF00E676),

    // APD Tidak Ada
    'no_helm': Color(0xFFFF1744),     // merah terang
    'no_rompi': Color(0xFFFF1744),
    'no_sepatu': Color(0xFFFF1744),
    'no_kacamata': Color(0xFFFF1744),
    'no_sarung_tangan': Color(0xFFFF1744),
    'no_masker': Color(0xFFFF1744),
  };

  /// Warna fallback untuk label yang tidak terdaftar.
  static const Color _fallback = Color(0xFF78909C); // blue-grey

  /// Mendapatkan warna berdasarkan label. Case-insensitive.
  static Color forLabel(String label) =>
      _labelColors[label.toLowerCase().trim()] ?? _fallback;

  /// Apakah label ini merepresentasikan ketidakpatuhan APD.
  static bool isNonCompliant(String label) =>
      label.toLowerCase().trim().startsWith('no_');
}

// ── Konfigurasi Visual ─────────────────────────────────────────────────────

/// Konstanta visual untuk rendering bounding box dan label.
/// Dipisahkan agar mudah di-tweak tanpa menyentuh logika painter.
class _PainterConfig {
  _PainterConfig._();

  static const double boxStrokeWidth = 2.5;
  static const double boxCornerRadius = 6.0;
  static const double boxAlpha = 0.85;        // opacity outline

  static const double labelPaddingH = 8.0;    // padding horizontal chip label
  static const double labelPaddingV = 4.0;    // padding vertikal chip label
  static const double labelCornerRadius = 4.0;
  static const double labelFontSize = 11.5;
  static const double labelConfidenceFontSize = 10.0;
  static const double labelOffsetY = 4.0;     // jarak chip dari atas box

  static const Color labelTextColor = Color(0xFFFFFFFF);
  static const double chipAlpha = 0.88;
}

// ── Custom Painter ──────────────────────────────────────────────────────────

/// Painter utama untuk overlay deteksi APD.
///
/// Gunakan melalui [CustomPaint]:
/// ```dart
/// CustomPaint(
///   painter: ApdPainter(boxes: mappedBoxes),
///   child: ...,
/// )
/// ```
class ApdPainter extends CustomPainter {
  /// Daftar bounding box dalam screen space dari [CoordinateMapper.mapAll].
  final List<MappedBox> boxes;

  /// Apakah confidence score ditampilkan di chip label.
  final bool showConfidence;

  const ApdPainter({
    required this.boxes,
    this.showConfidence = true,
  });

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final color = ApdColorScheme.forLabel(box.label);
      _drawBoundingBox(canvas, box.screenRect, color);
      _drawLabelChip(canvas, box, color);
    }
  }

  // ── Bounding Box ───────────────────────────────────────────────────────────

  void _drawBoundingBox(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(_PainterConfig.boxAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _PainterConfig.boxStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(_PainterConfig.boxCornerRadius),
    );

    // Glow effect: gambar outline yang lebih tebal dan transparan di belakang.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _PainterConfig.boxStrokeWidth * 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawRRect(rrect, paint);
  }

  // ── Label Chip ─────────────────────────────────────────────────────────────

  void _drawLabelChip(Canvas canvas, MappedBox box, Color color) {
    final labelText = _formatLabel(box.label);
    final confidenceText = '${(box.confidence * 100).toStringAsFixed(0)}%';

    // ── Ukur teks agar chip pas ─────────────────────────────────────────────
    final labelPainter = _buildTextPainter(
      labelText,
      _PainterConfig.labelFontSize,
      FontWeight.w600,
    )..layout();

    final confPainter = showConfidence
        ? (_buildTextPainter(
            confidenceText,
            _PainterConfig.labelConfidenceFontSize,
            FontWeight.w400,
          )..layout())
        : null;

    final chipWidth = _PainterConfig.labelPaddingH * 2 +
        labelPainter.width +
        (confPainter != null ? confPainter.width + 6 : 0);
    final chipHeight = _PainterConfig.labelPaddingV * 2 +
        labelPainter.height;

    // ── Posisi chip: di atas kiri bounding box ──────────────────────────────
    final chipTop = box.screenRect.top - chipHeight - _PainterConfig.labelOffsetY;
    final chipLeft = box.screenRect.left;

    // Jika chip melampaui batas atas layar, pindah ke dalam box.
    final adjustedTop = chipTop < 0 ? box.screenRect.top + 2 : chipTop;

    final chipRect = Rect.fromLTWH(chipLeft, adjustedTop, chipWidth, chipHeight);
    final chipRRect = RRect.fromRectAndRadius(
      chipRect,
      const Radius.circular(_PainterConfig.labelCornerRadius),
    );

    // ── Gambar background chip ──────────────────────────────────────────────
    canvas.drawRRect(
      chipRRect,
      Paint()..color = color.withOpacity(_PainterConfig.chipAlpha),
    );

    // ── Gambar teks label ───────────────────────────────────────────────────
    labelPainter.paint(
      canvas,
      Offset(
        chipLeft + _PainterConfig.labelPaddingH,
        adjustedTop + _PainterConfig.labelPaddingV,
      ),
    );

    // ── Gambar teks confidence (jika aktif) ─────────────────────────────────
    if (confPainter != null) {
      confPainter.paint(
        canvas,
        Offset(
          chipLeft + _PainterConfig.labelPaddingH + labelPainter.width + 6,
          adjustedTop + _PainterConfig.labelPaddingV + 1.5,
        ),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  TextPainter _buildTextPainter(
    String text,
    double fontSize,
    FontWeight weight,
  ) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _PainterConfig.labelTextColor,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
  }

  /// Mengubah snake_case label menjadi Title Case yang lebih readable.
  /// Contoh: "no_helm" → "No Helm", "sarung_tangan" → "Sarung Tangan"
  String _formatLabel(String raw) {
    return raw
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // ── Repaint Optimization ───────────────────────────────────────────────────

  @override
  bool shouldRepaint(ApdPainter oldDelegate) {
    if (oldDelegate.boxes.length != boxes.length) return true;
    if (oldDelegate.showConfidence != showConfidence) return true;

    for (int i = 0; i < boxes.length; i++) {
      final a = oldDelegate.boxes[i];
      final b = boxes[i];
      if (a.label != b.label ||
          a.confidence != b.confidence ||
          a.screenRect != b.screenRect) {
        return true;
      }
    }
    return false;
  }
}