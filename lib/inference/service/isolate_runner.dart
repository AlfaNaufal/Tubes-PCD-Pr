// lib/inference/service/isolate_runner.dart

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'pcd_processor.dart';
import 'apd_interpreter.dart';
import '../model/apd_result.dart';

enum IsolateCommand { captureNextFrame }

// ── Wrapper Data Komunikasi Bolak-Balik ────────────────────────────────
class IsolateResponse {
  final List<ApdResult> results;
  final Uint8List? capturedImageBytes;
  final bool isCaptureResponse;

  IsolateResponse({
    required this.results,
    this.capturedImageBytes,
    this.isCaptureResponse = false,
  });
}

// ── Payload Inisialisasi ────────────────────────────────────────────────
class IsolateInitPayload {
  final SendPort mainSendPort;
  final Uint8List modelBytes;
  final String labelContent;
  final int modelInputSize;
  final double confidenceThreshold;

  IsolateInitPayload({
    required this.mainSendPort,
    required this.modelBytes,
    required this.labelContent,
    required this.modelInputSize,
    required this.confidenceThreshold,
  });
}

class FramePayload {
  final CameraImage cameraImage;
  FramePayload(this.cameraImage);
}

// ── Isolate Runner (Main Thread) ────────────────────────────────────────
class IsolateRunner {
  static Isolate? _isolate;
  static SendPort? _isolateSendPort;
  static ReceivePort? _mainReceivePort;

  static bool _isProcessing = false;

  // Stream Controller untuk mengirim laporan
  static final StreamController<IsolateResponse> _reportStreamController =
      StreamController<IsolateResponse>.broadcast();
  static Stream<IsolateResponse> get reportStream =>
      _reportStreamController.stream;

  static Future<void> init({
    required String modelPath,
    required String labelPath,
    required int modelInputSize,
    required double confidenceThreshold,
  }) async {
    if (_isolate != null) return;

    _mainReceivePort = ReceivePort();
    final modelBytes = (await rootBundle.load(modelPath)).buffer.asUint8List();
    final labelContent = await rootBundle.loadString(labelPath);

    final initPayload = IsolateInitPayload(
      mainSendPort: _mainReceivePort!.sendPort,
      modelBytes: modelBytes,
      labelContent: labelContent,
      modelInputSize: modelInputSize,
      confidenceThreshold: confidenceThreshold,
    );

    _isolate = await Isolate.spawn(_isolateEntryPoint, initPayload);

    _mainReceivePort!.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
      } else if (message is IsolateResponse) {
        if (message.isCaptureResponse) {
          _reportStreamController.add(message);
        }

        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(message.results);
        }
        _isProcessing = false;
      }
    });
  }

  static Completer<List<ApdResult>>? _completer;

  static Future<List<ApdResult>> process(CameraImage image) async {
    if (_isolateSendPort == null || _isProcessing) return [];
    _isProcessing = true;
    _completer = Completer<List<ApdResult>>();

    _isolateSendPort!.send(FramePayload(image));
    return _completer!.future;
  }

  static void captureForReport() {
    if (_isolateSendPort != null) {
      _isolateSendPort!.send(IsolateCommand.captureNextFrame);
    }
  }

  static void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _mainReceivePort?.close();
    _isolate = null;
    _isolateSendPort = null;
    _isProcessing = false;
  }
}

// ── Isolate Entry Point (Background Thread) ─────────────────────────────
void _isolateEntryPoint(IsolateInitPayload initData) async {
  final isolateReceivePort = ReceivePort();
  initData.mainSendPort.send(isolateReceivePort.sendPort);
  bool _shouldCaptureNext = false;

  // Inisialisasi TFLite harus di ATAS await for
  final interpreter = ApdInterpreter();
  await interpreter.initFromBytes(
    modelBytes: initData.modelBytes,
    labelContent: initData.labelContent,
    confidenceThreshold: initData.confidenceThreshold,
  );

  // Hanya ada SATU loop await for
  await for (final message in isolateReceivePort) {
    if (message == IsolateCommand.captureNextFrame) {
      _shouldCaptureNext = true;
      continue;
    }

    if (message is FramePayload) {
      final rgb = PcdProcessor.convertYUV420toRGB(message.cameraImage);
      if (rgb == null) {
        initData.mainSendPort.send(IsolateResponse(results: <ApdResult>[]));
        continue;
      }

      final resized = PcdProcessor.resize(rgb, initData.modelInputSize);

      // 1. Proses PCD
      final pcdProcessed = PcdProcessor.applyPCDFilters(resized);

      // 2. Normalisasi & Deteksi AI
      final normalized = PcdProcessor.normalize(pcdProcessed);
      final results = interpreter.run(normalized);

      // 3. Logika Capture Laporan
      Uint8List? jpgBytes;
      bool isCapture = false;

      if (_shouldCaptureNext) {
        final reportResized = PcdProcessor.resize(rgb, 720);
        final reportPcd = PcdProcessor.applyPCDFilters(reportResized);
        jpgBytes = Uint8List.fromList(img.encodeJpg(reportPcd, quality: 85));
        isCapture = true;
        _shouldCaptureNext = false; // Reset flag
      }

      initData.mainSendPort.send(
        IsolateResponse(
          results: results,
          capturedImageBytes: jpgBytes,
          isCaptureResponse: isCapture,
        ),
      );
    }
  }
}
