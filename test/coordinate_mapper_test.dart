// test/coordinate_mapper_test.dart
//
// Unit test untuk CoordinateMapper.
//
// Apa yang ditest:
//   1. Konversi cx,cy,w,h → Rect yang benar
//   2. Scaling dari model space ke widget space
//   3. Letterbox offset (preview aspect ≠ widget aspect)
//   4. Clipping box yang keluar layar
//   5. Filter box terlalu kecil
//   6. Edge case: empty list, box sepenuhnya di luar

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcd_tubes_helm/inference/model/apd_result.dart';
import 'package:pcd_tubes_helm/overlay/coordinate_mapper.dart';

// ── Helper: Buat ApdResult dengan format cx,cy,w,h ────────────────────────
//
// INGAT: ApdResult menyimpan cx→left, cy→top, w→right, h→bottom
// (field naming mengikuti struktur Hive, bukan makna geometri konvensional).
ApdResult _makeResult({
  required double cx,
  required double cy,
  required double w,
  required double h,
  String label = 'helm',
  double confidence = 0.9,
}) {
  return ApdResult(
    label: label,
    confidence: confidence,
    left: cx,
    top: cy,
    right: w,
    bottom: h,
  );
}

void main() {
  // ── Group 1: Konversi cx,cy,w,h → Rect ──────────────────────────────────

  group('cx,cy,w,h → Rect conversion', () {
    test('box di tengah (normalized) terpetakan dengan benar', () {
      // Kamera 320×320, widget 320×320 → scale=1, no offset
      final previewSize = const Size(320, 320);
      final widgetSize = const Size(320, 320);

      // cx=0.5, cy=0.5, w=0.5, h=0.5
      // Expected: left=0.25*320=80, top=0.25*320=80,
      //           right=0.75*320=240, bottom=0.75*320=240
      final result = _makeResult(cx: 0.5, cy: 0.5, w: 0.5, h: 0.5);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, hasLength(1));
      final rect = boxes.first.screenRect;

      expect(rect.left, closeTo(80.0, 1.0));
      expect(rect.top, closeTo(80.0, 1.0));
      expect(rect.right, closeTo(240.0, 1.0));
      expect(rect.bottom, closeTo(240.0, 1.0));
    });

    test('box pojok kiri atas terpetakan ke dekat 0,0', () {
      final previewSize = const Size(320, 320);
      final widgetSize = const Size(320, 320);

      // cx=0.1, cy=0.1, w=0.1, h=0.1
      // left=(0.1-0.05)*320=16, top=16, right=32, bottom=32
      final result = _makeResult(cx: 0.1, cy: 0.1, w: 0.1, h: 0.1);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, hasLength(1));
      expect(boxes.first.screenRect.left, closeTo(16.0, 1.0));
      expect(boxes.first.screenRect.top, closeTo(16.0, 1.0));
    });
  });

  // ── Group 2: Scaling ─────────────────────────────────────────────────────

  group('scaling preview → widget', () {
    test('widget 2× lebih besar dari preview → koordinat ikut di-scale 2×', () {
      final previewSize = const Size(160, 160);
      final widgetSize = const Size(320, 320);

      // cx=0.5, cy=0.5, w=0.25, h=0.25
      // Tanpa scale: left=43.75*2=87.5, right=112.5*2=225, dst.
      final result = _makeResult(cx: 0.5, cy: 0.5, w: 0.25, h: 0.25);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, hasLength(1));
      // scale = widgetH / previewH = 320/160 = 2.0
      // left_norm = cx - w/2 = 0.5 - 0.125 = 0.375
      // left_screen = left_norm * scale * widgetW = 0.375 * 2.0 * 320 = 240
      expect(boxes.first.screenRect.left, closeTo(240.0, 1.0));
    });
  });

  // ── Group 3: Letterbox (aspect ratio berbeda) ─────────────────────────────

  group('letterbox offset', () {
    test('preview landscape (wider) pada widget portrait → ada offset Y', () {
      // Preview 640×360 (16:9 landscape)
      // Widget 360×640 (9:16 portrait)
      // Fit by width: scale = 360/640 = 0.5625
      // Scaled height = 360 * 0.5625 = 202.5
      // offsetY = (640 - 202.5) / 2 = 218.75
      final previewSize = const Size(640, 360);
      final widgetSize = const Size(360, 640);

      // Box di tengah — harus digeser ke bawah oleh offsetY
      final result = _makeResult(cx: 0.5, cy: 0.5, w: 0.1, h: 0.1);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, hasLength(1));

      // Center Y box harus di atas 320 (pusat widget) karena ada letterbox
      final centerY =
          (boxes.first.screenRect.top + boxes.first.screenRect.bottom) / 2;
      // Dengan letterbox, center Y preview mapped ke widget center = widgetH/2
      // Center Y harus sekitar 320 (pusat widget 640px)
      expect(centerY, greaterThan(200));
      expect(centerY, lessThan(440));
    });

    test('preview portrait (taller) pada widget landscape → ada offset X', () {
      // Preview 360×640, Widget 640×360
      // Fit by height: scale = 360/640 = 0.5625
      // Scaled width = 360 * 0.5625 = 202.5
      // offsetX = (640 - 202.5) / 2 = 218.75
      final previewSize = const Size(360, 640);
      final widgetSize = const Size(640, 360);

      final result = _makeResult(cx: 0.5, cy: 0.5, w: 0.1, h: 0.1);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, hasLength(1));

      final centerX =
          (boxes.first.screenRect.left + boxes.first.screenRect.right) / 2;
      expect(centerX, greaterThan(200));
      expect(centerX, lessThan(440));
    });
  });

  // ── Group 4: Clipping & Filter ────────────────────────────────────────────

  group('clipping & filter', () {
    test('box sepenuhnya di luar layar → tidak muncul di hasil', () {
      final previewSize = const Size(320, 320);
      final widgetSize = const Size(320, 320);

      // cx=1.5 → sudah di luar kanan layar
      final result = _makeResult(cx: 1.5, cy: 0.5, w: 0.1, h: 0.1);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, isEmpty);
    });

    test('box sebagian di luar layar → di-clip ke batas widget', () {
      final previewSize = const Size(320, 320);
      final widgetSize = const Size(320, 320);

      // cx=0.95, w=0.2 → right = (0.95+0.1)*320 = 336 > 320 → harus di-clip
      final result = _makeResult(cx: 0.95, cy: 0.5, w: 0.2, h: 0.2);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, hasLength(1));
      expect(boxes.first.screenRect.right, lessThanOrEqualTo(320.0));
    });

    test('box terlalu kecil (< 4px) setelah clip → dibuang', () {
      final previewSize = const Size(320, 320);
      final widgetSize = const Size(320, 320);

      // Box sangat kecil: w=0.005, h=0.005 → 0.005*320 = 1.6px < 4px
      final result = _makeResult(cx: 0.5, cy: 0.5, w: 0.005, h: 0.005);
      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, isEmpty);
    });
  });

  // ── Group 5: Edge Cases ───────────────────────────────────────────────────

  group('edge cases', () {
    test('empty results → empty list tanpa error', () {
      final boxes = CoordinateMapper.mapAll(
        results: const [],
        previewSize: const Size(320, 320),
        widgetSize: const Size(320, 320),
      );
      expect(boxes, isEmpty);
    });

    test('multiple boxes → semua dimapping secara independen', () {
      final previewSize = const Size(320, 320);
      final widgetSize = const Size(320, 320);

      final results = [
        _makeResult(cx: 0.2, cy: 0.2, w: 0.2, h: 0.2, label: 'helm'),
        _makeResult(cx: 0.7, cy: 0.7, w: 0.2, h: 0.2, label: 'no_helm'),
      ];

      final boxes = CoordinateMapper.mapAll(
        results: results,
        previewSize: previewSize,
        widgetSize: widgetSize,
      );

      expect(boxes, hasLength(2));
      expect(boxes[0].label, 'helm');
      expect(boxes[1].label, 'no_helm');

      // Box pertama harus di kiri atas, kedua di kanan bawah
      expect(boxes[0].screenRect.center.dx,
          lessThan(boxes[1].screenRect.center.dx));
    });

    test('label dan confidence terbawa dengan benar ke MappedBox', () {
      final result = _makeResult(
        cx: 0.5,
        cy: 0.5,
        w: 0.3,
        h: 0.3,
        label: 'rompi',
        confidence: 0.87,
      );

      final boxes = CoordinateMapper.mapAll(
        results: [result],
        previewSize: const Size(320, 320),
        widgetSize: const Size(320, 320),
      );

      expect(boxes.first.label, 'rompi');
      expect(boxes.first.confidence, closeTo(0.87, 0.001));
    });
  });
}