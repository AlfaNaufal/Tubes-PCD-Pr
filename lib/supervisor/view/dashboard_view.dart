import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/dashboard_controller.dart';
import '../../auth/controller/auth_controller.dart';

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Image.memory(
                            report.imageBytes, // Gambar hasil PCD
                            width: double.infinity,
                            height: 200,
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
                                    report.inspectorName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${report.timestamp.day}/${report.timestamp.month}/${report.timestamp.year} ${report.timestamp.hour}:${report.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Color(0xFF8B949E),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (report.detections.isEmpty)
                                    _buildBadge(
                                      '0 Deteksi (Coba jepret ulang)',
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
                  );
                },
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
