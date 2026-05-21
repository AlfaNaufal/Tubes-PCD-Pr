import 'dart:typed_data';
import 'package:hive/hive.dart';
import '../../inference/model/apd_result.dart';

part 'report_model.g.dart';

@HiveType(typeId: 2)
class ReportModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final Uint8List imageBytes;

  @HiveField(3)
  final List<ApdResult> detections;

  @HiveField(4)
  final String inspectorName;

  ReportModel({
    required this.id,
    required this.timestamp,
    required this.imageBytes,
    required this.detections,
    required this.inspectorName,
  });

  // Helper getters
  int get noHelmetCount =>
      detections.where((r) => r.label == 'no_helmet').length;
  int get noVestCount => detections.where((r) => r.label == 'no_vest').length;
}
