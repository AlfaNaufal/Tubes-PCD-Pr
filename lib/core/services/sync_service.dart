import 'local_db_service.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SyncService {
  final LocalDbService _localDb;

  SyncService(this._localDb);

  Future<void> syncOfflineData() async {
    print('=== Menjalankan pengecekan Sync ===');
    final unsyncedReports = _localDb.getUnsyncedReports();
    print('Jumlah data belum sinkron di Hive: ${unsyncedReports.length}');

    if (unsyncedReports.isEmpty) {
      print('Sync Dibatalkan: Tidak ada data baru untuk dikirim.');
      return;
    }

    try {
      print('Mencoba konek ke MongoDB...');
      final db = await Db.create(dotenv.get('MONGO_URL'));
      await db.open();
      final collection = db.collection('reports');

      for (var report in unsyncedReports) {
        String imageUrl = "url_gambar_sementara";

        await collection.insertOne(
          report.toMongoMap(userId: report.inspectorName, imageUrl: imageUrl),
        );

        await _localDb.markAsSynced(report.id);
      }

      await db.close();
      print('Sinkronisasi ${unsyncedReports.length} data berhasil!');
    } catch (e) {
      print('Gagal sync, akan dicoba lagi nanti: $e');
    }
  }
}
