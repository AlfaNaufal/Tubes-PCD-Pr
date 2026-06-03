import 'package:flutter/material.dart';
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
  }

  // 2. Taruh fungsinya di sini!
  void onDetectionComplete(ReportModel newReport) async {
    try {
      // OFFLINE FIRST: Simpan langsung ke Hive secepat mungkin
      await _localDbService.saveReport(newReport);
      
      // Update UI (misal memberi tahu View bahwa data berhasil disimpan)
      notifyListeners();

      // Lakukan sinkronisasi di background
      // Jika offline, akan gagal diam-diam. Jika online, akan terkirim.
      _syncService.syncOfflineData(); 
      
    } catch (e) {
      print("Gagal menyimpan data ke lokal: $e");
    }
  }

  // Tambahkan logic lain terkait inspeksi kamera di sini...
}