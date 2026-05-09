import 'package:flutter_test/flutter_test.dart';
import 'package:pcd_tubes_helm/inference/model/apd_result.dart';

void main() {
  group('ApdResult', () {
    test('objek terbuat dengan benar', () {
      final result = ApdResult(
        label: 'helmet',
        confidence: 0.92,
        left: 10.0,
        top: 20.0,
        right: 100.0,
        bottom: 150.0,
      );

      expect(result.label, 'helmet');
      expect(result.confidence, 0.92);
      expect(result.left, 10.0);
      expect(result.bottom, 150.0);
    });

    test('confidence valid range', () {
      final result = ApdResult(
        label: 'no_helmet',
        confidence: 0.75,
        left: 0,
        top: 0,
        right: 50,
        bottom: 50,
      );
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
    });
  });
}
