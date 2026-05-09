import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pcd_tubes_helm/inference/service/pcd_processor.dart';

void main() {
  group('PcdProcessor', () {
    test('resize menghasilkan 320x320', () {
      final image = img.Image(width: 640, height: 480);
      final resized = PcdProcessor.resize(image, 320);
      expect(resized.width, 320);
      expect(resized.height, 320);
    });

    test('normalize nilai antara 0.0-1.0', () {
      final image = img.Image(width: 2, height: 2);
      image.setPixelRgb(0, 0, 255, 0, 0);
      image.setPixelRgb(1, 0, 0, 255, 0);
      image.setPixelRgb(0, 1, 0, 0, 255);
      image.setPixelRgb(1, 1, 128, 128, 128);

      final result = PcdProcessor.normalize(image);

      for (var row in result) {
        for (var pixel in row) {
          for (var channel in pixel) {
            expect(channel, greaterThanOrEqualTo(0.0));
            expect(channel, lessThanOrEqualTo(1.0));
          }
        }
      }
    });

    test('normalize output shape benar', () {
      final image = img.Image(width: 320, height: 320);
      final result = PcdProcessor.normalize(image);
      expect(result.length, 320);
      expect(result[0].length, 320);
      expect(result[0][0].length, 3);
    });
  });
}
