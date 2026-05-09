import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import '../../core/env_config.dart';
import '../model/apd_result.dart';

class ApdInterpreter {
  Interpreter? _interpreter;
  List<String> _labels = [];

  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset(Env.modelPath);

    print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
    print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    print('Input type: ${_interpreter!.getInputTensor(0).type}');
    print('Output type: ${_interpreter!.getOutputTensor(0).type}');

    final labelData = await rootBundle.loadString(Env.labelPath);
    _labels = labelData.split('\n').where((e) => e.isNotEmpty).toList();
  }

  List<ApdResult> run(List<List<List<double>>> input) {
    // Output shape YOLOv8: [1, 8, 8400]
    var output = List.filled(1 * 8 * 8400, 0.0).reshape([1, 8, 8400]);
    _interpreter!.run([input], output);
    return _parseOutput(output);
  }

  List<ApdResult> _parseOutput(dynamic output) {
    final List<ApdResult> results = [];
    final data = output[0]; // [8, 8400]

    for (int i = 0; i < 8400; i++) {
      final confidence = (data[4][i] as double);
      if (confidence < double.parse(Env.confidenceThreshold)) continue;

      int labelIndex = 0;
      double maxScore = 0;
      for (int c = 4; c < 8; c++) {
        if ((data[c][i] as double) > maxScore) {
          maxScore = data[c][i];
          labelIndex = c - 4;
        }
      }

      results.add(
        ApdResult(
          label: _labels[labelIndex],
          confidence: confidence,
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
