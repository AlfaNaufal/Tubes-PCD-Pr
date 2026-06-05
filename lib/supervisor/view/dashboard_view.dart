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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Dashboard Laporan',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Pakai ctx dari Consumer, bukan context outer
          Consumer<AuthController>(
            builder:
                (ctx, auth, _) => IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
                  tooltip: 'Logout',
                  onPressed: () => _confirmLogout(ctx, auth),
                ),
          ),
        ],
      ),
      body:
          reports.isEmpty
              ? const Center(
                child: Text(
                  'Belum ada laporan offline.',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                                        color: Color(0xFF111827),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${report.timestamp.day}/${report.timestamp.month} '
                                      '${report.timestamp.hour}:${report.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Site: ${report.site} · Divisi: ${report.division}',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
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
                                    if (report.noGlovesCount > 0)
                                      _buildBadge(
                                        '${report.noGlovesCount} Tanpa Sarung Tangan',
                                        Colors.orange,
                                      ),
                                    if (report.noShoesCount > 0)
                                      _buildBadge(
                                        '${report.noShoesCount} Tanpa Sepatu',
                                        Colors.deepOrange,
                                      ),
                                    if (report.detections.isNotEmpty &&
                                        report.noHelmetCount == 0 &&
                                        report.noVestCount == 0 &&
                                        report.noGlovesCount == 0 &&
                                        report.noShoesCount == 0)
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

  // ── Logout dengan konfirmasi + clear navigation stack ────────────────────

  void _confirmLogout(BuildContext context, AuthController auth) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            title: const Text(
              'Keluar dari Akun',
              style: TextStyle(color: Color(0xFF111827), fontSize: 16),
            ),
            content: const Text(
              'Yakin ingin logout?',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              TextButton(
                onPressed: () {
                  // 1. Tutup dialog
                  Navigator.of(dialogContext).pop();
                  // 2. Ubah state auth
                  auth.logout();
                  // 3. Clear seluruh stack → paksa ke /login
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
    );
  }

  // ── Detail Dialog ──────────────────────────────────────────────────────────

  void _showReportDetailDialog(BuildContext context, ReportModel report) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            title: const Text(
              'Detail Informasi Temuan',
              style: TextStyle(
                color: Color(0xFF111827),
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
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (_) => Dialog(
                                backgroundColor: Colors.black,
                                insetPadding: EdgeInsets.zero,
                                child: InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: Image.memory(
                                    report.imageBytes,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          report.imageBytes,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
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
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (report.detections.isEmpty)
                      const Text(
                        'Tidak ada deteksi (frame blur/gagal)',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
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
                              'gloves': 'Sarung Tangan ✓',
                              'shoes': 'Sepatu ✓',
                              'person': 'Pekerja ✓',
                            }[d.label] ??
                            d.label;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: Color(0xFFFFB800)),
                ),
              ),
            ],
          ),
    );
  }

  // ── Widget Helpers ─────────────────────────────────────────────────────────

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
          ),
          const Divider(color: Color(0xFFE5E7EB), height: 12),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
