// lib/inspection/view/inspection_home_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../auth/controller/auth_controller.dart';
import '../../auth/model/user_model.dart';

class InspectionHomeView extends StatelessWidget {
  const InspectionHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────────
            _buildTopBar(context, auth),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Selamat datang,',
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? 'Inspector',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFFB800).withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        user?.role.displayName ?? 'HSE Inspector',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Status Cards ─────────────────────────────────────
                    _buildSectionLabel('Status Sistem'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            icon: Icons.model_training_outlined,
                            value: 'YOLOv8 Nano',
                            sub: 'TFLite · Edge',
                            color: const Color(0xFF00C853),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatusCard(
                            icon: Icons.memory_outlined,
                            value: 'On-Device',
                            sub: 'Isolate · PCD',
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // ── APD Checklist ─────────────────────────────────────
                    _buildSectionLabel('APD yang Dideteksi'),
                    const SizedBox(height: 12),
                    _buildApdChecklist(),

                    const SizedBox(height: 40),

                    // ── Petunjuk ──────────────────────────────────────────
                    _buildSectionLabel('Petunjuk Penggunaan'),
                    const SizedBox(height: 12),
                    _buildInstructionCard(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            _buildBottomCTA(context),
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, AuthController auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'APD Guard',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              bool isOffline = false;

              if (snapshot.hasData) {
                isOffline = snapshot.data!.contains(ConnectivityResult.none);
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isOffline
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isOffline
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : Colors.green.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                      size: 14,
                      color: isOffline ? Colors.redAccent : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOffline ? "Offline" : "Online",
                      style: TextStyle(
                        color: isOffline ? Colors.redAccent : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Consumer<AuthController>(
            builder:
                (ctx, authCtrl, _) => IconButton(
                  onPressed: () => _confirmLogout(ctx, authCtrl),
                  icon: const Icon(
                    Icons.logout_outlined,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  tooltip: 'Logout',
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildApdChecklist() {
    const items = [
      (Icons.safety_divider_outlined, 'Helm Keselamatan', 'Hard hat'),
      (Icons.visibility_outlined, 'Kacamata Pelindung', 'Safety goggles'),
      (Icons.back_hand_outlined, 'Sarung Tangan', 'Gloves'),
      (Icons.airline_seat_flat_angled, 'Rompi Keselamatan', 'Safety vest'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
            items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(item.$1, color: const Color(0xFFFFB800), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                item.$3,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF00C853),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  if (i < items.length - 1)
                    const Divider(
                      height: 1,
                      color: Color(0xFFE5E7EB),
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildInstructionCard() {
    const steps = [
      ('1', 'Arahkan kamera ke area kerja dengan pencahayaan cukup.'),
      ('2', 'Pastikan seluruh tubuh pekerja masuk dalam frame.'),
      ('3', 'Sistem akan otomatis mendeteksi kelengkapan APD.'),
      ('4', 'Ketuk tombol Selesai untuk menyimpan hasil inspeksi.'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
            steps.map((step) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          step.$1,
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.$2,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed:
              () => Navigator.of(context).pushNamed('/inspection/camera'),
          icon: const Icon(Icons.videocam_outlined, size: 20),
          label: const Text(
            'Mulai Deteksi APD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB800),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

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
                  Navigator.of(dialogContext).pop();
                  auth.logout();
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
}
