import 'package:envied/envied.dart';

part 'env_config.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'CONFIDENCE_THRESHOLD')
  static final String confidenceThreshold = _Env.confidenceThreshold;

  @EnviedField(varName: 'MODEL_INPUT_SIZE')
  static final String modelInputSize = _Env.modelInputSize;

  @EnviedField(varName: 'MODEL_PATH')
  static final String modelPath = _Env.modelPath;

  @EnviedField(varName: 'LABEL_PATH')
  static final String labelPath = _Env.labelPath;

  @EnviedField(varName: 'IOU_THRESHOLD')
  static final String iouThreshold = _Env.iouThreshold;
}
