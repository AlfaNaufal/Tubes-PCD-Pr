// Mengkonversi koordinat raw output YOLOv8 ke Rect layar (screen space).
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
import 'dart:math' as math;

class MappedBox {
  final Rect screenRect;
  final String label;
  final double confidence;

  const MappedBox({
    required this.screenRect,
    required this.label,
    required this.confidence,
  });
}

class CoordinateMapper {
  CoordinateMapper._();

  static List<MappedBox> mapAll({
    required List<ApdResult> results,
    required Size previewSize,
    required Size widgetSize,
    int modelInputSize = 640,
  }) {
    if (results.isEmpty) return const [];

    final transform = _computeTransform(previewSize, widgetSize);

    final double scaleToModel = math.min(
      modelInputSize / previewSize.width,
      modelInputSize / previewSize.height,
    );
    final double scaledW = previewSize.width * scaleToModel;
    final double scaledH = previewSize.height * scaleToModel;
    final double padX = (modelInputSize - scaledW) / 2 / modelInputSize;
    final double padY = (modelInputSize - scaledH) / 2 / modelInputSize;
    final double normScaleX = scaledW / modelInputSize;
    final double normScaleY = scaledH / modelInputSize;

    print(
      'padX=$padX padY=$padY normScaleX=$normScaleX normScaleY=$normScaleY',
    );

    return results
        .map(
          (r) => _mapSingle(
            r,
            transform,
            previewSize,
            widgetSize,
            padX,
            padY,
            normScaleX,
            normScaleY,
          ),
        )
        .whereType<MappedBox>()
        .toList(growable: false);
  }

  static _Transform _computeTransform(Size preview, Size widget) {
    final scale = math.min(
      widget.width / preview.width,
      widget.height / preview.height,
    );

    final scaledWidth = preview.width * scale;
    final scaledHeight = preview.height * scale;

    final offsetX = (widget.width - scaledWidth) / 2;
    final offsetY = (widget.height - scaledHeight) / 2;

    return _Transform(scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  // ── Private: Single Box Mapping ────────────────────────────────────────────

  static MappedBox? _mapSingle(
    ApdResult result,
    _Transform transform,
    Size previewSize,
    Size widgetSize,
    double padX,
    double padY,
    double normScaleX,
    double normScaleY,
  ) {
    final double nL = (result.left - padX) / normScaleX;
    final double nT = (result.top - padY) / normScaleY;
    final double nR = (result.right - padX) / normScaleX;
    final double nB = (result.bottom - padY) / normScaleY;

    final double left =
        nL * previewSize.width * transform.scale + transform.offsetX;
    final double top =
        nT * previewSize.height * transform.scale + transform.offsetY;
    final double right =
        nR * previewSize.width * transform.scale + transform.offsetX;
    final double bottom =
        nB * previewSize.height * transform.scale + transform.offsetY;

    final Rect rawRect = Rect.fromLTRB(left, top, right, bottom);
    final Rect widgetBounds = Offset.zero & widgetSize;
    final Rect clipped = rawRect.intersect(widgetBounds);

    if (clipped.isEmpty || clipped.width < 4 || clipped.height < 4) return null;

    print(
      '${result.label} -> '
      'L:${nL.toStringAsFixed(3)} '
      'T:${nT.toStringAsFixed(3)} '
      'R:${nR.toStringAsFixed(3)} '
      'B:${nB.toStringAsFixed(3)}',
    );

    return MappedBox(
      screenRect: clipped,
      label: result.label,
      confidence: result.confidence,
    );
  }
}

// ── Internal Value Object ──────────────────────────────────────────────────

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
