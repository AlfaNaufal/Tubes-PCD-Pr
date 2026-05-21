import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static double get confidenceThreshold =>
      double.parse(dotenv.env['CONFIDENCE_THRESHOLD'] ?? '0.35');

  static int get modelInputSize =>
      int.parse(dotenv.env['MODEL_INPUT_SIZE'] ?? '416');

  static double get iouThreshold =>
      double.parse(dotenv.env['IOU_THRESHOLD'] ?? '0.45');

  static String get modelPath =>
      dotenv.env['MODEL_PATH'] ?? 'assets/models/apd_yolov8n.tflite';

  static String get labelPath =>
      dotenv.env['LABEL_PATH'] ?? 'assets/labels/apd_labels.txt';

  static String get mongoUrl => dotenv.env['MONGO_URL'] ?? '';
}
