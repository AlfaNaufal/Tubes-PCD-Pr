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
    print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
    print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    final labelRaw = await _loadAssetString(labelPath);
    _labels = labelRaw.split('\n').where((e) => e.isNotEmpty).toList();
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
    _labels = labelContent.split('\n').where((e) => e.isNotEmpty).toList();
    print('Labels: $_labels');
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

  List<ApdResult> run(List<List<List<List<double>>>> input) {
    final output = List.generate(
      1,
      (_) => List.generate(9, (_) => List.filled(3549, 0.0)),
    );
    _interpreter!.run(input, output);
    return _parseOutput(output, 9, 3549);
  }

  List<ApdResult> _parseOutput(
    List<List<List<double>>> output,
    int rows,
    int cols,
  ) {
    final List<ApdResult> results = [];
    final data = output[0];
    final int numClasses = rows - 4;
    final int classesToCheck =
        numClasses < _labels.length ? numClasses : _labels.length;

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

      if (xCenter <= 0 || yCenter <= 0 || width <= 0 || height <= 0) continue;

      final String label =
          labelIndex < _labels.length ? _labels[labelIndex] : 'unknown';

      print(
        'DEBUG: DETEKSI -> $label | conf: $maxScore | x:$xCenter y:$yCenter',
      );

      if (label == 'gloves') continue;

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
    return results;
  }

  void dispose() {
    _interpreter?.close();
  }
}
