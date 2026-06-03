import 'package:hive_flutter/hive_flutter.dart';
import '../../inspection/model/report_model.dart';

class LocalDbService {
  static const String _reportBoxName = 'reports_box';

  // Dipanggil saat aplikasi dimulai
  Future<void> openBox() async {
    await Hive.openBox<ReportModel>(_reportBoxName);
  }

  // Simpan hasil deteksi APD (Offline First)
  Future<void> saveReport(ReportModel report) async {
    final box = Hive.box<ReportModel>(_reportBoxName);
    await box.put(report.id, report);
  }

  // Ambil semua data yang belum sinkron ke server
  List<ReportModel> getUnsyncedReports() {
    final box = Hive.box<ReportModel>(_reportBoxName);
    return box.values.where((report) => !report.isSynced).toList();
  }

  // Tandai laporan sudah sinkron ke MongoDB
  Future<void> markAsSynced(String reportId) async {
    final box = Hive.box<ReportModel>(_reportBoxName);
    final report = box.get(reportId);
    if (report != null) {
      report.isSynced = true;
      await report.save(); // Method save() bawaan dari extends HiveObject
    }
  }
}