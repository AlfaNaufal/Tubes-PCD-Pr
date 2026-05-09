import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

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
        int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
            .clamp(0, 255)
            .toInt();
        int b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  static img.Image resize(img.Image image, int size) {
    return img.copyResize(image, width: size, height: size);
  }

  static List<List<List<double>>> normalize(img.Image image) {
    final int size = image.width;
    return List.generate(
      size,
      (y) => List.generate(size, (x) {
        final pixel = image.getPixel(x, y);
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      }),
    );
  }
}
