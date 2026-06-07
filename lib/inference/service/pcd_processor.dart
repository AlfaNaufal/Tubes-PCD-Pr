import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class PcdProcessor {
  static img.Image? convertYUV420toRGB(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex =
            (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uPlane.bytesPerPixel!;

        final int yVal = yPlane.bytes[yIndex];
        final int uVal = uPlane.bytes[uvIndex];
        final int vVal = vPlane.bytes[uvIndex];

        int r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toInt();
        int g =
            (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
                .clamp(0, 255)
                .toInt();
        int b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  static img.Image resize(img.Image image, int size) {
    final scaleX = size / image.width;
    final scaleY = size / image.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final newW = (image.width * scale).round();
    final newH = (image.height * scale).round();

    final resized = img.copyResize(image, width: newW, height: newH);

    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));

    final offsetX = (size - newW) ~/ 2;
    final offsetY = (size - newH) ~/ 2;

    img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);
    return canvas;
  }

  static List<List<List<List<double>>>> normalize(img.Image image) {
    final int size = image.width;
    final inner = List.generate(
      size,
      (y) => List.generate(size, (x) {
        final pixel = image.getPixel(x, y);
        return [
          pixel.r.toDouble() / 255.0,
          pixel.g.toDouble() / 255.0,
          pixel.b.toDouble() / 255.0,
        ];
      }),
    );
    return [inner];
  }

  static img.Image applyPCDFilters(img.Image image) {
    return image;
  }

  static img.Image applyPCDFiltersForReport(img.Image image) {
    img.Image adjusted = img.adjustColor(image, brightness: 1.1, contrast: 1.2);
    img.Image gammaCorrected = img.adjustColor(adjusted, gamma: 1.2);
    return gammaCorrected;
  }

  static img.Image processForReport(
    img.Image rgbImage, {
    num rotationAngle = 90,
  }) {
    final rotated = img.copyRotate(rgbImage, angle: rotationAngle);

    final maxSize = 720;
    final scaleX = maxSize / rotated.width;
    final scaleY = maxSize / rotated.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final targetW = (rotated.width * scale).round();
    final targetH = (rotated.height * scale).round();

    final resized = img.copyResize(
      rotated,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.linear,
    );

    return applyPCDFiltersForReport(resized);
  }
}
