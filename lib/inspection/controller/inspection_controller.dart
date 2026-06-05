import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/sync_service.dart';
import '../model/report_model.dart';

class InspectionController extends ChangeNotifier {
  // 1. Inisialisasi Service
  final LocalDbService _localDbService = LocalDbService();
  late final SyncService _syncService;

  InspectionController() {
    // Hubungkan Local DB dengan Sync Service
    _syncService = SyncService(_localDbService);
    _init();
    // _syncService.syncOfflineData();
    
  }

  Future<void> _init() async {
    await _localDbService.openBox();
    _syncService.syncOfflineData();

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi)) {
        print('Internet terhubung kembali! Memulai sync background...');
        _syncService.syncOfflineData();
      }
    });
  }

  // 2. Taruh fungsinya di sini!
  void onDetectionComplete(ReportModel newReport) async {
    try {
      await _localDbService.saveReport(newReport);
      
      notifyListeners();

      _syncService.syncOfflineData(); 
      
    } catch (e) {
      print("Gagal menyimpan data ke lokal: $e");
    }
  }
}