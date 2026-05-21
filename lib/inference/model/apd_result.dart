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
}
