// lib/overlay/apd_overlay_widget.dart
//
// Widget utama overlay deteksi APD.
//
// ── Tanggung jawab ──────────────────────────────────────────────────────────
//   - Meletakkan CustomPaint di atas CameraPreview
//   - Menampilkan status banner (compliance / no detection)
//   - Menampilkan FPS counter dan jumlah deteksi (debug mode)
//   - Meneruskan ukuran widget ke OverlayController via LayoutBuilder
//   - Menghubungkan CameraManager.previewSize ke OverlayController
//
// ── Cara pakai ──────────────────────────────────────────────────────────────
//
//   // Di widget tree, setelah CameraManager dan IsolateRunner siap:
//   ChangeNotifierProvider(
//     create: (_) => OverlayController()..startListening(),
//     child: ApdOverlayWidget(cameraManager: _cameraManager),
//   )

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../hardware/controller/camera_manager.dart';
import 'overlay_controller.dart';
import 'apd_painter.dart';
import 'feedback_service.dart';

// ── Widget Utama ───────────────────────────────────────────────────────────

class ApdOverlayWidget extends StatefulWidget {
  final CameraManager cameraManager;

  /// Tampilkan info debug (FPS, jumlah box, ukuran preview).
  final bool showDebugInfo;

  /// Tampilkan persentase confidence di tiap label chip.
  final bool showConfidence;

  const ApdOverlayWidget({
    super.key,
    required this.cameraManager,
    this.showDebugInfo = false,
    this.showConfidence = true,
  });

  @override
  State<ApdOverlayWidget> createState() => _ApdOverlayWidgetState();
}

class _ApdOverlayWidgetState extends State<ApdOverlayWidget> {
  // FPS counter
  DateTime? _lastFrameTime;
  double _fps = 0;

  @override
  void didUpdateWidget(ApdOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync preview size jika CameraManager berubah.
    if (oldWidget.cameraManager != widget.cameraManager) {
      _syncPreviewSize();
    }
  }

  void _syncPreviewSize() {
    final controller = context.read<OverlayController>();
    controller.updatePreviewSize(widget.cameraManager.previewSize);
  }

  void _updateFps() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final delta = now.difference(_lastFrameTime!).inMilliseconds;
      if (delta > 0) {
        setState(() => _fps = 1000 / delta);
      }
    }
    _lastFrameTime = now;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OverlayController>(
      builder: (context, controller, _) {
        // Sync preview size setiap kali CameraManager berubah status.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          controller.updatePreviewSize(widget.cameraManager.previewSize);
          if (controller.mappedBoxes.isNotEmpty) _updateFps();
        });

        return LayoutBuilder(
          builder: (context, constraints) {
            // Beritahu controller ukuran widget terkini.
            final widgetSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              controller.updateWidgetSize(widgetSize);
            });

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Layer 1: Bounding Box (CustomPaint) ──────────────────────
                RepaintBoundary(
                  child: CustomPaint(
                    painter: ApdPainter(
                      boxes: controller.mappedBoxes,
                      showConfidence: widget.showConfidence,
                    ),
                    size: widgetSize,
                  ),
                ),

                // ── Layer 2: Status Banner (bawah layar) ─────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _StatusBanner(status: controller.complianceStatus),
                ),

                // ── Layer 3: Debug Overlay (pojok kanan atas) ────────────────
                if (widget.showDebugInfo)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _DebugOverlay(
                      fps: _fps,
                      boxCount: controller.mappedBoxes.length,
                      previewSize: widget.cameraManager.previewSize,
                      widgetSize: widgetSize,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Status Banner ──────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final ComplianceStatus status;

  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      color: status.backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusIcon(status: status),
            const SizedBox(width: 8),
            Text(
              status.displayText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final ComplianceStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ComplianceStatus.noDetection => const Icon(
          Icons.search,
          color: Colors.white70,
          size: 18,
        ),
      ComplianceStatus.compliant => const Icon(
          Icons.check_circle_outline,
          color: Colors.white,
          size: 18,
        ),
      ComplianceStatus.nonCompliant => const Icon(
          Icons.warning_amber_rounded,
          color: Colors.white,
          size: 18,
        ),
    };
  }
}

// ── Debug Overlay ──────────────────────────────────────────────────────────

class _DebugOverlay extends StatelessWidget {
  final double fps;
  final int boxCount;
  final Size? previewSize;
  final Size widgetSize;

  const _DebugOverlay({
    required this.fps,
    required this.boxCount,
    required this.previewSize,
    required this.widgetSize,
  });

  @override
  Widget build(BuildContext context) {
    final preview = previewSize != null
        ? '${previewSize!.width.toInt()}×${previewSize!.height.toInt()}'
        : 'N/A';
    final widget =
        '${widgetSize.width.toInt()}×${widgetSize.height.toInt()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontFamily: 'monospace',
          height: 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('FPS: ${fps.toStringAsFixed(1)}'),
            Text('Box: $boxCount'),
            Text('Preview: $preview'),
            Text('Widget: $widget'),
          ],
        ),
      ),
    );
  }
}