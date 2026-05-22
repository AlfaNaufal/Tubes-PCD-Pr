// lib/supervisor/view/dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/dashboard_controller.dart';
import '../../auth/controller/auth_controller.dart';
import '../../inspection/model/report_model.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  Map<String, dynamic> _getApdStatus(ReportModel report) {
    final helmet = report.helmetDetected;
    final vest = report.vestDetected;
    final human = report.humanDetected;

    if (!human) {
      return {'label': 'Tidak Ada Pekerja', 'color': Colors.grey};
    }
    if (helmet && vest) {
      return {'label': '✅ Helm + Rompi Lengkap', 'color': Colors.green};
    } else if (helmet && !vest) {
      return {
        'label': '⚠️ Pakai Helm, Tanpa Rompi',
        'color': Colors.orangeAccent,
      };
    } else if (!helmet && vest) {
      return {'label': '⚠️ Pakai Rompi, Tanpa Helm', 'color': Colors.orange};
    } else {
      return {
        'label': '🚨 Tanpa Helm & Tanpa Rompi',
        'color': Colors.redAccent,
      };
    }
  }

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
                  final apdStatus = _getApdStatus(report);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showReportDetailDialog(context, report),
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
                                      report.workerName,
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
                                _buildBadge(
                                  apdStatus['label']!,
                                  apdStatus['color'] as Color,
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
    final apdStatus = _getApdStatus(report);
    final helmet = report.helmetDetected;
    final vest = report.vestDetected;
    final human = report.humanDetected;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
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
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                      'Status APD Pekerja',
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!human)
                      _buildStatusRow(
                        Icons.person_off,
                        'Tidak ada pekerja terdeteksi',
                        Colors.grey,
                      )
                    else ...[
                      _buildStatusRow(
                        helmet ? Icons.check_circle : Icons.cancel,
                        helmet
                            ? 'Helm terdeteksi ✓'
                            : 'Helm tidak terdeteksi ✗',
                        helmet ? Colors.green : Colors.redAccent,
                      ),
                      const SizedBox(height: 6),
                      _buildStatusRow(
                        vest ? Icons.check_circle : Icons.cancel,
                        vest
                            ? 'Rompi terdeteksi ✓'
                            : 'Rompi tidak terdeteksi ✗',
                        vest ? Colors.green : Colors.orangeAccent,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (apdStatus['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (apdStatus['color'] as Color).withOpacity(
                              0.4,
                            ),
                          ),
                        ),
                        child: Text(
                          apdStatus['label']!,
                          style: TextStyle(
                            color: apdStatus['color'] as Color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildStatusRow(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
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
