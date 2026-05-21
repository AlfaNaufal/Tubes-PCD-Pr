import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../inspection/model/report_model.dart';

class DashboardController extends ChangeNotifier {
  static const String boxName = 'reportsBox';
  List<ReportModel> _reports = [];

  List<ReportModel> get reports => _reports;

  Future<void> init() async {
    final box = await Hive.openBox<ReportModel>(boxName);

    _reports =
        box.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    notifyListeners();
  }

  Future<void> addReport(ReportModel report) async {
    final box = Hive.box<ReportModel>(boxName);

    await box.put(report.id, report);
    _reports.insert(0, report);

    notifyListeners();
  }
}
