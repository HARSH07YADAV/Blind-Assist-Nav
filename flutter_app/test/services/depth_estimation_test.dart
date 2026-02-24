/// Unit tests for the DepthEstimationService
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_mate/services/depth_estimation_service.dart';
import 'package:vision_mate/models/detection.dart';

void main() {
  late DepthEstimationService service;

  setUp(() {
    service = DepthEstimationService();
  });

  tearDown(() {
    service.dispose();
  });

  group('estimateDistance', () {
    test('person at known height estimates reasonable distance', () {
      // Person is 1.7m tall. Frame is 480px high → focal = 432px.
      // Box is 200px tall → distance = (1.7 * 432) / 200 ≈ 3.67m
      final distance = service.estimateDistance(
        className: 'person',
        boxHeightPx: 200,
        boxWidthPx: 100,
        frameHeight: 480,
        frameWidth: 640,
      );

      expect(distance, greaterThan(2.0));
      expect(distance, lessThan(6.0));
    });

    test('large box (close object) gives small distance', () {
      final distance = service.estimateDistance(
        className: 'person',
        boxHeightPx: 400,
        boxWidthPx: 150,
        frameHeight: 480,
        frameWidth: 640,
      );

      expect(distance, lessThan(3.0));
    });

    test('small box (far object) gives larger distance', () {
      final distance = service.estimateDistance(
        className: 'person',
        boxHeightPx: 50,
        boxWidthPx: 20,
        frameHeight: 480,
        frameWidth: 640,
      );

      expect(distance, greaterThan(10.0));
    });

    test('uses width-based fallback for flat objects', () {
      // dining table has width prior 1.2m but small height prior 0.75m
      // When box is wider than tall, width may dominate
      final distance = service.estimateDistance(
        className: 'dining table',
        boxHeightPx: 30,
        boxWidthPx: 300,
        frameHeight: 480,
        frameWidth: 640,
      );

      expect(distance, greaterThan(0));
      expect(distance, lessThan(25.0));
    });

    test('unknown class uses generic fallback', () {
      final distance = service.estimateDistance(
        className: 'alien_artifact',
        boxHeightPx: 100,
        boxWidthPx: 80,
        frameHeight: 480,
        frameWidth: 640,
      );

      // Uses 0.5m default height
      expect(distance, greaterThan(0));
    });

    test('very small box returns -1 (unreliable)', () {
      final distance = service.estimateDistance(
        className: 'person',
        boxHeightPx: 5,
        boxWidthPx: 3,
        frameHeight: 480,
        frameWidth: 640,
      );

      // boxHeightPx <= 10 should skip, but 5 is < 10 so it skips height
      // boxWidthPx 3 < 10 so it skips width too
      // Falls back to generic with boxHeightPx 5 < 10 → returns -1
      expect(distance, equals(-1));
    });

    test('distance is clamped to 0.2-25.0 range', () {
      // Very close (huge box)
      final closeDistance = service.estimateDistance(
        className: 'person',
        boxHeightPx: 2000,
        boxWidthPx: 500,
        frameHeight: 480,
        frameWidth: 640,
      );
      expect(closeDistance, greaterThanOrEqualTo(0.2));

      service.clearHistory();

      // Very far (tiny box)
      final farDistance = service.estimateDistance(
        className: 'person',
        boxHeightPx: 11,
        boxWidthPx: 5,
        frameHeight: 480,
        frameWidth: 640,
      );
      expect(farDistance, lessThanOrEqualTo(25.0));
    });
  });

  group('temporal smoothing', () {
    test('repeated calls smooth out jitter', () {
      // Call multiple times with varying heights
      final distances = <double>[];
      for (final height in [200.0, 210.0, 195.0, 205.0, 200.0]) {
        distances.add(service.estimateDistance(
          className: 'chair',
          boxHeightPx: height,
          boxWidthPx: 50,
          frameHeight: 480,
          frameWidth: 640,
        ));
      }

      // After 5 readings, the median should stabilize
      // All readings should be close together
      final range = distances.reduce((a, b) => a > b ? a : b) -
          distances.reduce((a, b) => a < b ? a : b);
      expect(range, lessThan(1.0)); // Within 1 meter spread
    });

    test('clearHistory resets smoothing', () {
      // Get a baseline
      service.estimateDistance(
        className: 'person',
        boxHeightPx: 200,
        boxWidthPx: 100,
        frameHeight: 480,
        frameWidth: 640,
      );

      service.clearHistory();

      // After clear, should work fresh
      final distance = service.estimateDistance(
        className: 'person',
        boxHeightPx: 200,
        boxWidthPx: 100,
        frameHeight: 480,
        frameWidth: 640,
      );
      expect(distance, greaterThan(0));
    });
  });

  group('getDistanceDescription', () {
    test('negative returns unknown', () {
      expect(service.getDistanceDescription(-1), 'unknown distance');
    });

    test('0.3m returns within arm reach', () {
      expect(service.getDistanceDescription(0.3), "within arm's reach");
    });

    test('0.8m returns about one step', () {
      expect(service.getDistanceDescription(0.8), 'about one step away');
    });

    test('1.2m returns about two steps', () {
      expect(service.getDistanceDescription(1.2), 'about two steps away');
    });

    test('1.7m returns about three steps', () {
      expect(service.getDistanceDescription(1.7), 'about three steps away');
    });

    test('2.5m returns approximately N meters', () {
      final desc = service.getDistanceDescription(2.5);
      expect(desc, contains('meters'));
    });

    test('15m returns far away', () {
      final desc = service.getDistanceDescription(15);
      expect(desc, contains('far away'));
    });
  });

  group('estimateForDetection', () {
    test('convenience method produces same result', () {
      final detection = Detection(
        className: 'chair',
        classId: 56,
        confidence: 0.9,
        boundingBox: BoundingBox(left: 100, top: 200, right: 250, bottom: 400),
        dangerLevel: DangerLevel.medium,
      );

      service.clearHistory();
      final directDistance = service.estimateDistance(
        className: 'chair',
        boxHeightPx: detection.boundingBox.height,
        boxWidthPx: detection.boundingBox.width,
        frameHeight: 480,
        frameWidth: 640,
      );

      service.clearHistory();
      final convenienceDistance = service.estimateForDetection(
        detection,
        frameHeight: 480,
        frameWidth: 640,
      );

      expect(convenienceDistance, equals(directDistance));
    });
  });

  group('objectHeights', () {
    test('contains person', () {
      expect(DepthEstimationService.objectHeights.containsKey('person'), isTrue);
    });

    test('contains 50+ entries', () {
      expect(DepthEstimationService.objectHeights.length, greaterThanOrEqualTo(50));
    });

    test('all heights are positive', () {
      for (final entry in DepthEstimationService.objectHeights.entries) {
        expect(entry.value, greaterThan(0), reason: '${entry.key} has invalid height');
      }
    });
  });
}
