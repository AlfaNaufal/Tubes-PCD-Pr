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

  @HiveField(5)
  final String workerName;

  @HiveField(6)
  final String site;

  @HiveField(7)
  final String division;

  @HiveField(8)
  bool isSynced;

  ReportModel({
    required this.id,
    required this.timestamp,
    required this.imageBytes,
    required this.detections,
    required this.inspectorName,
    required this.workerName,
    required this.site,
    required this.division,
    this.isSynced = false,
  });

  // Dataset: boots, gloves, helmet, human, vest
  // Tidak ada kelas no_helmet/no_vest — pelanggaran = tidak terdeteksi helm/vest
  bool get helmetDetected =>
      detections.any((r) => r.label == 'helmet' && r.confidence > 0.15);

  bool get vestDetected =>
      detections.any((r) => r.label == 'vest' && r.confidence > 0.15);

  bool get humanDetected =>
      detections.any((r) => r.label == 'person' && r.confidence > 0.15);

  bool get glovesDetected =>
      detections.any((r) => r.label == 'gloves' && r.confidence > 0.15);

  bool get shoesDetected =>
      detections.any((r) => r.label == 'shoes' && r.confidence > 0.15);
  // Pelanggaran: ada manusia tapi tidak ada helm
  bool get noHelmetViolation => humanDetected && !helmetDetected;

  // Pelanggaran: ada manusia tapi tidak ada rompi
  bool get noVestViolation => humanDetected && !vestDetected;

  // Pelanggaran: ada manusia tapi tidak ada sarung tangan
  bool get noGlovesViolation => humanDetected && !glovesDetected;

  // Pelanggaran: ada manusia tapi tidak ada sepatu
  bool get noShoesViolation => humanDetected && !shoesDetected;

  int get noGlovesCount => noGlovesViolation ? 1 : 0;
  int get noShoesCount => noShoesViolation ? 1 : 0;
  int get noHelmetCount => noHelmetViolation ? 1 : 0;
  int get noVestCount => noVestViolation ? 1 : 0;

  Map<String, dynamic> toMongoMap({
    required dynamic userId,
    required String imageUrl,
  }) {
    return {
      'user_id': userId,
      'inspector_name': inspectorName,
      'worker_name': workerName,
      'site': site,
      'division': division,
      'timestamp': timestamp,
      'image_url': imageUrl,
      'total_violations':
          noHelmetCount + noVestCount + noGlovesCount + noShoesCount,
      'detections': detections.map((d) => d.toMongoMap()).toList(),
    };
  }
}
