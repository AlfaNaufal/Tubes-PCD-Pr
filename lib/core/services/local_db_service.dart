import 'package:hive_flutter/hive_flutter.dart';
import '../../inspection/model/report_model.dart';

class LocalDbService {
  static const String _reportBoxName = 'reports_box';

  Future<void> openBox() async {
    await Hive.openBox<ReportModel>(_reportBoxName);
  }

  Future<void> saveReport(ReportModel report) async {
    final box = Hive.box<ReportModel>(_reportBoxName);
    await box.put(report.id, report);
  }

  List<ReportModel> getUnsyncedReports() {
    final box = Hive.box<ReportModel>(_reportBoxName);
    return box.values.where((report) => !report.isSynced).toList();
  }

  Future<void> markAsSynced(String reportId) async {
    final box = Hive.box<ReportModel>(_reportBoxName);
    final report = box.get(reportId);
    if (report != null) {
      report.isSynced = true;
      await report.save();
    }
  }
}
