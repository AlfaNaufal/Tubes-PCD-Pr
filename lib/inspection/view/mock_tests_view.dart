import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../model/report_model.dart';
import '../controller/inspection_controller.dart';
import '../../inference/model/apd_result.dart';

class MockTestView extends StatefulWidget {
  const MockTestView({super.key});

  @override
  State<MockTestView> createState() => _MockTestViewState();
}

class _MockTestViewState extends State<MockTestView> {
  final InspectionController _controller = InspectionController();
  
  // Variabel untuk menampung data sementara sebelum di-upload
  ReportModel? _previewData;

  void _generateMockData() {
    // 1. Buat data deteksi palsu (menggunakan left, top, right, bottom)
    final dummyDetections = [
      ApdResult(
        label: 'helmet',
        confidence: 0.85,
        left: 0.1, top: 0.1, right: 0.3, bottom: 0.3,
      ),
      ApdResult(
        label: 'person',
        confidence: 0.90,
        left: 0.05, top: 0.05, right: 0.9, bottom: 0.9,
      ),
      ApdResult(
        label: 'vest', // Anggap dia juga pakai rompi
        confidence: 0.78,
        left: 0.2, top: 0.4, right: 0.8, bottom: 0.8,
      ),
    ];

    // 2. Bungkus ke dalam ReportModel
    final dummyReport = ReportModel(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      imageBytes: Uint8List(0), // Gambar kosong untuk tes
      detections: dummyDetections,
      inspectorName: 'Tester Offline',
      workerName: 'Pekerja Dummy Alpha',
      site: 'Site Tambang 1',
      division: 'Divisi Lapangan',
      isSynced: false,
    );

    // 3. Tampilkan ke layar (JANGAN di-upload dulu)
    setState(() {
      _previewData = dummyReport;
    });
  }

  void _submitData() {
    if (_previewData != null) {
      // 4. Baru jalankan upload ke controller
      _controller.onDetectionComplete(_previewData!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data dummy berhasil masuk ke antrean (Hive)!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Kembalikan layar ke kondisi awal setelah sukses
      setState(() {
        _previewData = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Sync Test Page'),
        backgroundColor: const Color(0xFFFFB800),
      ),
      // Menggunakan SingleChildScrollView agar tidak error overflow
      body: SingleChildScrollView( 
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            // JIKA DATA BELUM DIBUAT -> Tampilkan tombol Generate
            if (_previewData == null) ...[
              const SizedBox(height: 60),
              const Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Tekan tombol di bawah untuk membuat data inspeksi palsu.\nData HANYA akan ditampilkan, tidak langsung di-upload.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _generateMockData,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Buat Data Preview'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                ),
              ),
            ] 
            
            // JIKA DATA SUDAH DIBUAT -> Tampilkan kotak Preview & Tombol Upload
            else ...[
              const Text(
                'Data Siap Dikirim!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Kotak Detail Data
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('ID Report', _previewData!.id),
                    _buildDetailRow('Waktu', _previewData!.timestamp.toString().split('.')[0]),
                    _buildDetailRow('Inspektur', _previewData!.inspectorName),
                    _buildDetailRow('Pekerja', _previewData!.workerName),
                    _buildDetailRow('Lokasi', _previewData!.site),
                    const Divider(height: 24),
                    const Text('Hasil Deteksi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Looping menampilkan list APD yang terdeteksi
                    ..._previewData!.detections.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          Text('${d.label.toUpperCase()} (Conf: ${(d.confidence * 100).toStringAsFixed(1)}%)'),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Tombol Aksi (Batal / Simpan)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _previewData = null; // Batal dan hapus preview
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submitData,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Simpan & Sync Data'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget kecil bantuan agar kode lebih rapi
  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(title, style: const TextStyle(color: Colors.grey)),
          ),
          const Text(': '),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}