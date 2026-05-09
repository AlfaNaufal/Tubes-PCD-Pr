import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'pcd_processor.dart';
import 'apd_interpreter.dart';
import '../model/apd_result.dart';
import '../../core/env_config.dart';

class IsolatePayload {
  final CameraImage cameraImage;
  IsolatePayload(this.cameraImage);
}

Future<List<ApdResult>> runInference(IsolatePayload payload) async {
  final interpreter = ApdInterpreter();
  await interpreter.init();

  final rgb = PcdProcessor.convertYUV420toRGB(payload.cameraImage);
  if (rgb == null) return [];

  final resized = PcdProcessor.resize(rgb, int.parse(Env.modelInputSize));
  final normalized = PcdProcessor.normalize(resized);

  final results = interpreter.run(normalized);
  interpreter.dispose();
  return results;
}

class IsolateRunner {
  static Future<List<ApdResult>> process(CameraImage image) async {
    return await compute(runInference, IsolatePayload(image));
  }
}
