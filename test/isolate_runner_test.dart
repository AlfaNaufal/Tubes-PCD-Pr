import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pcd_tubes_helm/inference/service/pcd_processor.dart';

void main() {
  group('IsolateRunner pipeline manual', () {
    test('pipeline resize + normalize tidak error', () {
      final image = img.Image(width: 640, height: 480);
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          image.setPixelRgb(x, y, 100, 150, 200);
        }
      }

      final resized = PcdProcessor.resize(image, 320);
      final normalized = PcdProcessor.normalize(resized);

      expect(resized.width, 320);
      expect(normalized.length, 320);
      expect(normalized[0][0][0], closeTo(100 / 255.0, 0.01));
      expect(normalized[0][0][1], closeTo(150 / 255.0, 0.01));
      expect(normalized[0][0][2], closeTo(200 / 255.0, 0.01));
    });
  });
}
