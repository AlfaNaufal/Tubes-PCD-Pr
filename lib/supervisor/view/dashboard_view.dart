// lib/supervisor/view/dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/dashboard_controller.dart';
import '../../auth/controller/auth_controller.dart';
import '../../inspection/model/report_model.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardCtrl = context.watch<DashboardController>();
    final reports = dashboardCtrl.reports;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Dashboard Laporan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E)),
            onPressed: () => context.read<AuthController>().logout(),
          ),
        ],
      ),
      body:
          reports.isEmpty
              ? const Center(
                child: Text(
                  'Belum ada laporan offline.',
                  style: TextStyle(color: Color(0xFF8B949E)),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap:
                          () => _showReportDetailDialog(
                            context,
                            report,
                          ), // Buka detail laporan saat diklik
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.memory(
                              report.imageBytes,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      report
                                          .workerName, // Tampilkan nama pekerja di baris utama kartu
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${report.timestamp.day}/${report.timestamp.month} ${report.timestamp.hour}:${report.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        color: Color(0xFF8B949E),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Site: ${report.site} · Divisi: ${report.division}',
                                  style: const TextStyle(
                                    color: Color(0xFF8B949E),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (report.detections.isEmpty)
                                      _buildBadge(
                                        '0 Deteksi (Blur/Gagal)',
                                        Colors.grey,
                                      ),
                                    if (report.noHelmetCount > 0)
                                      _buildBadge(
                                        '${report.noHelmetCount} Tanpa Helm',
                                        Colors.redAccent,
                                      ),
                                    if (report.noVestCount > 0)
                                      _buildBadge(
                                        '${report.noVestCount} Tanpa Rompi',
                                        Colors.orangeAccent,
                                      ),
                                    if (report.detections.isNotEmpty &&
                                        report.noHelmetCount == 0 &&
                                        report.noVestCount == 0)
                                      _buildBadge(
                                        'Aman Sesuai Prosedur',
                                        Colors.green,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  void _showReportDetailDialog(BuildContext context, ReportModel report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            // Gunakan constraints untuk membatasi tinggi agar tidak melampaui layar
            // dan memberikan ruang untuk scroll
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            title: const Text(
              'Detail Informasi Temuan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width, // Ambil lebar layar
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:
                      MainAxisSize
                          .min, // Penting agar Column menyesuaikan konten
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        report.imageBytes,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Nama Pekerja', report.workerName),
                    _buildDetailRow('Site Lokasi', report.site),
                    _buildDetailRow('Divisi / Vendor', report.division),
                    _buildDetailRow('HSE Inspector', report.inspectorName),
                    _buildDetailRow(
                      'Waktu Inspeksi',
                      report.timestamp.toString().substring(0, 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hasil Deteksi APD',
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (report.detections.isEmpty)
                      const Text(
                        'Tidak ada deteksi (frame blur/gagal)',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      )
                    else
                      ...report.detections.map((d) {
                        final isViolation =
                            d.label == 'no_helmet' || d.label == 'no_vest';
                        final color =
                            isViolation ? Colors.redAccent : Colors.green;
                        final labelText =
                            {
                              'helmet': 'Helm ✓',
                              'no_helmet': 'Tanpa Helm ✗',
                              'vest': 'Rompi ✓',
                              'no_vest': 'Tanpa Rompi ✗',
                            }[d.label] ??
                            d.label;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                labelText,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${(d.confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(color: color, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: Color(0xFFFFB800)),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Divider(color: Color(0xFF30363D), height: 12),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
