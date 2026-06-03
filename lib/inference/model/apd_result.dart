import 'package:hive/hive.dart';

part 'apd_result.g.dart';

@HiveType(typeId: 1)
class ApdResult extends HiveObject {
  @HiveField(0)
  final String label;

  @HiveField(1)
  final double confidence;

  @HiveField(2)
  final double left;

  @HiveField(3)
  final double top;

  @HiveField(4)
  final double right;

  @HiveField(5)
  final double bottom;

  ApdResult({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  Map<String, dynamic> toMongoMap() {
    return {
      'label': label,
      'confidence': confidence,
      'bbox': {'left': left, 'top': top, 'right': right, 'bottom': bottom},
    };
  }

  factory ApdResult.fromMap(Map<String, dynamic> map) {
    final bbox = map['bbox'] as Map<String, dynamic>;
    return ApdResult(
      label: map['label'] ?? '',
      confidence: (map['confidence'] as num).toDouble(),
      left: (bbox['left'] as num).toDouble(),
      top: (bbox['top'] as num).toDouble(),
      right: (bbox['right'] as num).toDouble(),
      bottom: (bbox['bottom'] as num).toDouble(),
    );
  }
}
