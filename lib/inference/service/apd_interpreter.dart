import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../model/apd_result.dart';

class ApdInterpreter {
  Interpreter? _interpreter;
  List<String> _labels = [];
  double _confidenceThreshold = 0.5;

  Future<void> init({
    required String modelPath,
    required String labelPath,
    required double confidenceThreshold,
  }) async {
    _confidenceThreshold = confidenceThreshold;

    // Load model sebagai bytes — kompatibel dengan isolate
    final modelData = await _loadAsset(modelPath);
    _interpreter = Interpreter.fromBuffer(modelData);

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

  static Future<Uint8List> _loadAsset(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  static Future<String> _loadAssetString(String path) async {
    return await rootBundle.loadString(path);
  }

  List<ApdResult> run(List<List<List<double>>> input) {
    final int rows = 30;
    final int columns = 3549;

    var output = List.filled(
      1 * rows * columns,
      0.0,
    ).reshape([1, rows, columns]);
    _interpreter!.run([input], output);
    return _parseOutput(output, rows, columns);
  }

  List<ApdResult> _parseOutput(dynamic output, int rows, int columns) {
    final List<ApdResult> results = [];
    final data = output[0]; // Akses dimensi pertama

    // Loop sebanyak jumlah anchor box (3549)
    for (int i = 0; i < columns; i++) {
      // Di YOLOv8, index 0-3 adalah bounding box (x, y, w, h)
      // Index 4 ke atas adalah score untuk setiap kelas.
      // Kita cari score tertinggi dari kelas-kelas yang ada.
      double maxScore = 0;
      int labelIndex = 0;

      // Loop untuk mencari kelas dengan confidence tertinggi
      // Karena kita hanya punya 4 label, pastikan kita mengecek index 4 sampai 4 + _labels.length
      int classCount = _labels.length;
      for (int c = 4; c < 4 + classCount; c++) {
        double score = data[c][i] as double;
        if (score > maxScore) {
          maxScore = score;
          labelIndex = c - 4;
        }
      }

      if (maxScore < _confidenceThreshold) continue;

      results.add(
        ApdResult(
          label: _labels[labelIndex],
          confidence: maxScore,
          left: data[0][i],
          top: data[1][i],
          right: data[2][i],
          bottom: data[3][i],
        ),
      );
    }
    return results;
  }

  void dispose() {
    _interpreter?.close();
  }
}
