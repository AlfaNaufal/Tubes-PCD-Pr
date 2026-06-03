// lib/overlay/coordinate_mapper.dart
//
// Mengkonversi koordinat raw output YOLOv8 ke Rect layar (screen space).
//
// ── Mengapa class ini kritis ────────────────────────────────────────────────
//
// YOLOv8 output format (dari ApdInterpreter._parseOutput):
//   data[0][i] → x_center  (disimpan di ApdResult.left)
//   data[1][i] → y_center  (disimpan di ApdResult.top)
//   data[2][i] → width     (disimpan di ApdResult.right)
//   data[3][i] → height    (disimpan di ApdResult.bottom)
//
// Nilai-nilai tersebut adalah koordinat NORMALIZED [0.0 – 1.0] relatif
// terhadap dimensi input model (modelInputSize × modelInputSize).
//
// Untuk menampilkan bounding box di layar, kita perlu:
//   1. Konversi cx,cy,w,h → left,top,right,bottom (format Rect standar)
//   2. Scale dari model space → camera preview space
//   3. Terapkan letterbox offset jika preview & layar berbeda rasio
//
// ── Asumsi portrait mode ────────────────────────────────────────────────────
//
// CameraManager.previewSize mengembalikan Size(height, width) karena rotasi
// sensor kamera. CoordinateMapper menerima nilai tersebut apa adanya.

import 'package:flutter/widgets.dart';
import '../inference/model/apd_result.dart';

/// Hasil konversi: bounding box dalam koordinat layar + metadata asli.
class MappedBox {
  /// Rect dalam screen space (unit: logical pixel).
  final Rect screenRect;

  /// Label APD, misalnya "helm", "rompi", "no_helm".
  final String label;

  /// Confidence score [0.0 – 1.0].
  final double confidence;

  const MappedBox({
    required this.screenRect,
    required this.label,
    required this.confidence,
  });
}

/// Mapper stateless — semua fungsi adalah pure function tanpa side effect.
class CoordinateMapper {
  // Konstruktor privat — gunakan factory method [mapAll].
  CoordinateMapper._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Mengkonversi semua [ApdResult] menjadi [MappedBox] yang siap digambar.
  ///
  /// Parameters:
  /// - [results]        : output mentah dari IsolateRunner.
  /// - [previewSize]    : ukuran preview kamera dari CameraManager.previewSize.
  /// - [widgetSize]     : ukuran widget Stack tempat CustomPainter menggambar.
  ///
  /// Returns daftar [MappedBox] yang sudah di-clip agar tidak keluar layar.
  static List<MappedBox> mapAll({
    required List<ApdResult> results,
    required Size previewSize,
    required Size widgetSize,
  }) {
    if (results.isEmpty) return const [];

    // Hitung scale & offset untuk letterboxing sekali saja (efisien).
    final transform = _computeTransform(previewSize, widgetSize);

    return results
        .map((r) => _mapSingle(r, transform, widgetSize))
        .whereType<MappedBox>() // buang null (box di luar layar)
        .toList(growable: false);
  }

  // ── Private: Transform Computation ────────────────────────────────────────

  /// Menghitung scale factor dan offset letterbox.
  ///
  /// Strategi: BoxFit.contain — preview kamera di-fit ke dalam widget
  /// dengan mempertahankan aspect ratio (tidak crop, tidak stretch).
  static _Transform _computeTransform(Size preview, Size widget) {
    final previewAspect = preview.width / preview.height;
    final widgetAspect = widget.width / widget.height;

    double scale;
    double offsetX;
    double offsetY;

    if (previewAspect > widgetAspect) {
      // Preview lebih lebar → letterbox atas-bawah (pillar box vertikal)
      scale = widget.width / preview.width;
      offsetX = 0;
      offsetY = (widget.height - preview.height * scale) / 2;
    } else {
      // Preview lebih tinggi → letterbox kiri-kanan
      scale = widget.height / preview.height;
      offsetX = (widget.width - preview.width * scale) / 2;
      offsetY = 0;
    }

    return _Transform(scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  // ── Private: Single Box Mapping ────────────────────────────────────────────

  /// Konversi satu [ApdResult] ke [MappedBox].
  /// Mengembalikan null jika box sepenuhnya di luar area widget.
  static MappedBox? _mapSingle(
    ApdResult result,
    _Transform transform,
    Size widgetSize,
  ) {
    // ── Step 1: Denormalize dari [0,1] ke preview space ──────────────────────
    //
    // YOLOv8 output sudah normalized terhadap modelInputSize.
    // Karena input model adalah square, nilai [0,1] langsung merepresentasikan
    // proporsi dari lebar/tinggi model. Kita gunakan previewSize untuk
    // denormalisasi ke pixel kamera.
    //
    // CATATAN: ApdResult menyimpan cx,cy,w,h pada field left,top,right,bottom.
    final double cxNorm = result.left;
    final double cyNorm = result.top;
    final double wNorm = result.right;
    final double hNorm = result.bottom;

    // ── Step 2: Konversi cx,cy,w,h → left,top,right,bottom (preview space) ──
    final double halfW = wNorm / 2;
    final double halfH = hNorm / 2;

    final double leftNorm = cxNorm - halfW;
    final double topNorm = cyNorm - halfH;
    final double rightNorm = cxNorm + halfW;
    final double bottomNorm = cyNorm + halfH;

    // ── Step 3: Scale ke widget space + tambahkan letterbox offset ───────────
    final double left =
        leftNorm * transform.scale * widgetSize.width + transform.offsetX;
    final double top =
        topNorm * transform.scale * widgetSize.height + transform.offsetY;
    final double right =
        rightNorm * transform.scale * widgetSize.width + transform.offsetX;
    final double bottom =
        bottomNorm * transform.scale * widgetSize.height + transform.offsetY;

    final Rect rawRect = Rect.fromLTRB(left, top, right, bottom);

    // ── Step 4: Clip agar tidak melebihi batas widget ────────────────────────
    final Rect widgetBounds = Offset.zero & widgetSize;
    final Rect clipped = rawRect.intersect(widgetBounds);

    // Buang box yang sepenuhnya di luar layar atau terlalu kecil.
    if (clipped.isEmpty || clipped.width < 4 || clipped.height < 4) {
      return null;
    }

    return MappedBox(
      screenRect: clipped,
      label: result.label,
      confidence: result.confidence,
    );
  }
}

// ── Internal Value Object ──────────────────────────────────────────────────

/// Menyimpan hasil komputasi transform agar tidak dihitung ulang per-box.
class _Transform {
  final double scale;
  final double offsetX;
  final double offsetY;

  const _Transform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });
}