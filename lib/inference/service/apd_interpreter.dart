import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../model/apd_result.dart';
import 'package:flutter/services.dart';

class ApdInterpreter {
  Interpreter? _interpreter;
  List<String> _labels = [];
  double _confidenceThreshold = 0.35;

  Future<void> init({
    required String modelPath,
    required String labelPath,
    required double confidenceThreshold,
  }) async {
    _confidenceThreshold = confidenceThreshold;

    _interpreter = Interpreter.fromBuffer(await _loadAssetBytes(modelPath));

    final out = _interpreter!.getOutputTensor(0);

    print('OUTPUT SHAPE = ${out.shape}');
    print('OUTPUT TYPE  = ${out.type}');

    print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
    print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');

    final labelRaw = await _loadAssetString(labelPath);
    _labels =
        labelRaw
            .split('\n')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();

    print('Labels: $_labels');
  }

  Future<void> initFromBytes({
    required Uint8List modelBytes,
    required String labelContent,
    required double confidenceThreshold,
  }) async {
    _confidenceThreshold = confidenceThreshold;
    _interpreter = Interpreter.fromBuffer(modelBytes);
    print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
    print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    _labels =
        labelContent
            .split('\n')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();
    print('Labels: $_labels');
    final out = _interpreter!.getOutputTensor(0);

    print('OUTPUT SHAPE = ${out.shape}');
    print('OUTPUT TYPE  = ${out.type}');
  }

  static Future<Uint8List> _loadAssetBytes(String path) async {
    // Hanya dipanggil dari main isolate
    final byteData = await _rootBundleLoad(path);
    return byteData;
  }

  static Future<Uint8List> _rootBundleLoad(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  static Future<String> _loadAssetString(String path) async {
    return await rootBundle.loadString(path);
  }

  String _normalizeLabel(String label) {
    return label.trim().toLowerCase();
  }

  bool _isValidDetection({
    required String label,
    required double width,
    required double height,
    required double confidence,
  }) {
    switch (label) {
      case 'helmet':
        if (width > 0.45 || height > 0.45) return false;
        if (confidence < 0.50) return false; // minimum confidence
        break;

      case 'vest':
        if (height < 0.08) return false;
        if (width > 0.80) return false; // vest tidak selebar frame
        break;

      case 'person':
        if (height < 0.10) return false;
        break;

      default:
        break;
    }

    return true;
  }

  List<ApdResult> run(List<List<List<List<double>>>> input) {
    final output = List.generate(
      1,
      (_) => List.generate(11, (_) => List.filled(8400, 0.0)),
    );

    _interpreter!.run(input, output);

    return _parseOutput(output, 11, 8400);
  }

  List<ApdResult> _parseOutput(
    List<List<List<double>>> output,
    int rows,
    int cols,
  ) {
    final List<ApdResult> results = [];
    final data = output[0];

    const int bboxChannels = 4;
    final int numClasses = rows - bboxChannels;
    final int classesToCheck =
        numClasses < _labels.length ? numClasses : _labels.length;

    print('Rows=$rows');
    print('Cols=$cols');
    print('Classes=$numClasses');
    print('Labels=${_labels.length}');

    // Debug: cek nilai max confidence di seluruh anchor
    double globalMax = 0;
    int globalMaxAnchor = 0;
    for (int i = 0; i < cols; i++) {
      for (int c = 0; c < classesToCheck; c++) {
        if (data[4 + c][i] > globalMax) {
          globalMax = data[4 + c][i];
          globalMaxAnchor = i;
        }
      }
    }
    print('DEBUG: Max confidence = $globalMax at anchor $globalMaxAnchor');

    for (int i = 0; i < cols; i++) {
      if (i % 500 == 0) {
        print(
          'DEBUG: Anchor $i -> xCenter: ${data[0][i]}, yCenter: ${data[1][i]}, conf0: ${data[4][i]}, conf1: ${data[5][i]}, conf2: ${data[6][i]}',
        );
      }

      double maxScore = 0;
      int labelIndex = 0;

      for (int c = 0; c < classesToCheck; c++) {
        final double score = data[4 + c][i];
        if (score > maxScore) {
          maxScore = score;
          labelIndex = c;
        }
      }

      if (maxScore < _confidenceThreshold) continue;

      final double xCenter = data[0][i];
      final double yCenter = data[1][i];
      final double width = data[2][i];
      final double height = data[3][i];

      if (xCenter <= 0 ||
          yCenter <= 0 ||
          width <= 0 ||
          height <= 0 ||
          width > 1 ||
          height > 1) {
        continue;
      }
      final String label =
          labelIndex < _labels.length
              ? _normalizeLabel(_labels[labelIndex])
              : 'unknown';
      if (!_isValidDetection(
        label: label,
        width: width,
        height: height,
        confidence: maxScore,
      )) {
        continue;
      }

      // Filter box aneh

      print(
        '$label '
        'conf:${maxScore.toStringAsFixed(2)} '
        'x:${xCenter.toStringAsFixed(3)} '
        'y:${yCenter.toStringAsFixed(3)} '
        'w:${width.toStringAsFixed(3)} '
        'h:${height.toStringAsFixed(3)}',
      );

      results.add(
        ApdResult(
          label: label,
          confidence: maxScore,
          left: (xCenter - width / 2).clamp(0.0, 1.0),
          top: (yCenter - height / 2).clamp(0.0, 1.0),
          right: (xCenter + width / 2).clamp(0.0, 1.0),
          bottom: (yCenter + height / 2).clamp(0.0, 1.0),
        ),
      );
    }
    return _applyNms(results, 0.35);
  }

  List<ApdResult> _applyNms(List<ApdResult> detections, double iouThreshold) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<ApdResult> kept = [];

    while (detections.isNotEmpty) {
      final current = detections.removeAt(0);

      kept.add(current);

      detections.removeWhere((d) {
        if (d.label != current.label) return false;

        final iou = _calculateIou(current, d);
        final dx = (current.left + current.right) / 2 - (d.left + d.right) / 2;
        final dy = (current.top + current.bottom) / 2 - (d.top + d.bottom) / 2;
        final centerDist = dx * dx + dy * dy;
        return iou > 0.35 || centerDist < 0.002;
      });
    }

    return kept;
  }

  double _calculateIou(ApdResult a, ApdResult b) {
    final left = a.left > b.left ? a.left : b.left;
    final top = a.top > b.top ? a.top : b.top;
    final right = a.right < b.right ? a.right : b.right;
    final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;

    if (right <= left || bottom <= top) {
      return 0;
    }

    final intersection = (right - left) * (bottom - top);

    final areaA = (a.right - a.left) * (a.bottom - a.top);

    final areaB = (b.right - b.left) * (b.bottom - b.top);

    return intersection / (areaA + areaB - intersection);
  }

  void dispose() {
    _interpreter?.close();
  }
}
