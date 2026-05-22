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
        _isProcessing = false; // selalu reset, termasuk capture response

        if (message.isCaptureResponse) {
          _reportStreamController.add(message);
        }

        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(message.results);
        }
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
  List<ApdResult> _lastResults = [];

  final interpreter = ApdInterpreter();
  await interpreter.initFromBytes(
    modelBytes: initData.modelBytes,
    labelContent: initData.labelContent,
    confidenceThreshold: initData.confidenceThreshold,
  );

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

      // PCD preprocessing
      final pcdProcessed = PcdProcessor.applyPCDFilters(resized);

      // FIX: normalize sekarang return 4D [1][H][W][C]
      // final normalized = PcdProcessor.normalize(pcdProcessed);
      final List<List<List<List<double>>>> normalized = PcdProcessor.normalize(
        pcdProcessed,
      );

      final rawResults = interpreter.run(normalized);
      final results =
          rawResults.where((r) {
            return r.left.isFinite &&
                r.top.isFinite &&
                r.right.isFinite &&
                r.bottom.isFinite;
          }).toList();

      _lastResults = results; // simpan hasil terakhir

      Uint8List? jpgBytes;
      bool isCapture = false;

      if (_shouldCaptureNext) {
        // Proses inference ulang di frame yang sama
        final captureResults = interpreter.run(normalized);
        final filteredCapture =
            captureResults.where((r) {
              return r.left.isFinite &&
                  r.top.isFinite &&
                  r.right.isFinite &&
                  r.bottom.isFinite;
            }).toList();

        // Gunakan hasil terbaik antara frame ini vs lastResults
        final bestResults =
            filteredCapture.isNotEmpty ? filteredCapture : _lastResults;

        final reportImage = PcdProcessor.processForReport(rgb);
        jpgBytes = Uint8List.fromList(img.encodeJpg(reportImage, quality: 85));
        isCapture = true;
        _shouldCaptureNext = false;

        initData.mainSendPort.send(
          IsolateResponse(
            results: bestResults,
            capturedImageBytes: jpgBytes,
            isCaptureResponse: true,
          ),
        );
        continue; // skip send di bawah
      }

      initData.mainSendPort.send(
        IsolateResponse(
          results: results,
          capturedImageBytes: null,
          isCaptureResponse: false,
        ),
      );
    }
  }
}
