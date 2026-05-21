import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../model/apd_result.dart';

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
    final modelData = await _loadAsset(modelPath);
    _interpreter = Interpreter.fromBuffer(modelData);

    print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
    print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');

    final labelRaw = await _loadAssetString(labelPath);
    _labels = labelRaw.split('\n').where((e) => e.isNotEmpty).toList();
    print('Labels loaded: $_labels');
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
    print('Labels loaded: $_labels');
  }

  static Future<Uint8List> _loadAsset(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  static Future<String> _loadAssetString(String path) async {
    return await rootBundle.loadString(path);
  }

  // FIX: terima 4D input [1][H][W][C]
  List<ApdResult> run(List<List<List<List<int>>>> input) {
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape; // [1, 30, 3549]

    final int rows = outputShape[1]; // 30 (4 coords + 26 classes)
    final int cols = outputShape[2]; // 3549 anchors

    // Alokasi output buffer
    final output = List.generate(
      1,
      (_) => List.generate(rows, (_) => List.filled(cols, 0.0)),
    );

    _interpreter!.run(input, output);
    return _parseOutput(output, rows, cols);
  }

  List<ApdResult> _parseOutput(
    List<List<List<double>>> output,
    int rows,
    int cols,
  ) {
    final List<ApdResult> results = [];
    final data = output[0]; // shape [rows][cols]

    // num_classes = rows - 4
    final int numClasses = rows - 4;

    for (int i = 0; i < cols; i++) {
      double maxScore = 0;
      int labelIndex = 0;
      if (i % 500 == 0) {
        // Print setiap 500 anchor untuk debugging
        print(
          'DEBUG: Anchor $i -> xCenter: ${data[0][i]}, yCenter: ${data[1][i]}, conf: ${data[4][i]}',
        );
      }
      // Hanya iterasi kelas yang ada di label file
      final int classesToCheck =
          numClasses < _labels.length ? numClasses : _labels.length;

      for (int c = 0; c < classesToCheck; c++) {
        final double score = data[4 + c][i];
        if (score > maxScore) {
          maxScore = score;
          labelIndex = c;
        }
      }

      if (maxScore < _confidenceThreshold) continue;
      if (maxScore > 0.5) {
        print(
          'DEBUG: Ditemukan deteksi! Score: $maxScore, Label Index: $labelIndex',
        );
      }
      final double xCenter = data[0][i];
      final double yCenter = data[1][i];
      final double width = data[2][i];
      final double height = data[3][i];

      // Validasi koordinat dalam range [0,1] — koordinat YOLOv8 sudah ternormalisasi
      if (xCenter <= 0 || yCenter <= 0 || width <= 0 || height <= 0) continue;

      results.add(
        ApdResult(
          label: labelIndex < _labels.length ? _labels[labelIndex] : 'unknown',
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
