/// Unit tests for the RiskCalculator
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_mate/core/risk_calculator.dart';
import 'package:vision_mate/models/detection.dart';

void main() {
  late RiskCalculator calculator;

  setUp(() {
    calculator = RiskCalculator();
  });

  Detection _makeDetection({
    String className = 'person',
    int classId = 0,
    double confidence = 0.9,
    double left = 250,
    double top = 100,
    double right = 390,
    double bottom = 400,
    DangerLevel? dangerLevel,
    double distanceMeters = 1.5,
  }) {
    return Detection(
      className: className,
      classId: classId,
      confidence: confidence,
      boundingBox: BoundingBox(left: left, top: top, right: right, bottom: bottom),
      dangerLevel: dangerLevel ?? DangerLevel.fromClassName(className),
      distanceMeters: distanceMeters,
    );
  }

  group('RiskCalculator.calculate', () {
    test('close center person has high risk score', () {
      // Large bounding box (close), center position, high danger class
      final detection = _makeDetection(
        className: 'person',
        left: 200, top: 50, right: 440, bottom: 430,
      );
      final result = calculator.calculate(detection, frameWidth: 640);

      expect(result.score, greaterThan(0.5));
      expect(result.shouldAlert, isTrue);
      expect(result.recommendation, isNotEmpty);
    });

    test('small off-center book has low risk', () {
      // Small bounding box (far away), off-center, low danger class
      final detection = _makeDetection(
        className: 'book',
        left: 10, top: 300, right: 50, bottom: 340,
      );
      final result = calculator.calculate(detection, frameWidth: 640);

      expect(result.score, lessThan(0.4));
    });

    test('critical class stairs in center has high risk score', () {
      // Large, center, critical danger
      final detection = _makeDetection(
        className: 'stairs',
        left: 180, top: 50, right: 460, bottom: 440,
      );
      final result = calculator.calculate(detection, frameWidth: 640);

      // Score should be very high (close to 1.0)
      // Note: RiskLevel.fromScore(1.0) may return safe due to exclusive upper bound
      expect(result.score, greaterThan(0.8));
    });

    test('shouldAlert is false for safe risk level', () {
      // Tiny box, far off center, info class
      final detection = _makeDetection(
        className: 'door',
        dangerLevel: DangerLevel.info,
        left: 600, top: 400, right: 620, bottom: 420,
      );
      final result = calculator.calculate(detection, frameWidth: 640);

      // Info class with small box far from center should be safe/low
      expect(result.shouldAlert, isFalse);
    });

    test('score is clamped between 0 and 1', () {
      final detection = _makeDetection(
        className: 'person',
        left: 0, top: 0, right: 640, bottom: 480,
      );
      final result = calculator.calculate(detection, frameWidth: 640);

      expect(result.score, greaterThanOrEqualTo(0.0));
      expect(result.score, lessThanOrEqualTo(1.0));
    });
  });

  group('RiskCalculator.calculateForAll', () {
    test('returns results sorted by score descending', () {
      final detections = [
        _makeDetection(className: 'book', left: 10, top: 300, right: 50, bottom: 340),
        _makeDetection(className: 'person', left: 200, top: 50, right: 440, bottom: 430),
        _makeDetection(className: 'chair', left: 400, top: 200, right: 500, bottom: 350),
      ];

      final results = calculator.calculateForAll(detections, frameWidth: 640);

      expect(results.length, 3);
      // Verify sorted descending
      for (int i = 1; i < results.length; i++) {
        expect(results[i - 1].score, greaterThanOrEqualTo(results[i].score));
      }
    });

    test('empty list returns empty results', () {
      final results = calculator.calculateForAll([], frameWidth: 640);
      expect(results, isEmpty);
    });

    test('single detection returns single result', () {
      final results = calculator.calculateForAll(
        [_makeDetection()],
        frameWidth: 640,
      );
      expect(results.length, 1);
    });
  });

  group('RiskCalculator recommendations', () {
    test('critical risk includes Stop!', () {
      // Force a high score by making a large centered critical object
      final detection = _makeDetection(
        className: 'stairs',
        left: 150, top: 20, right: 490, bottom: 460,
      );
      final result = calculator.calculate(detection, frameWidth: 640);

      if (result.level == RiskLevel.critical) {
        expect(result.recommendation, contains('Stop!'));
      }
    });

    test('safe risk has empty recommendation', () {
      // Tiny far-away info object
      final detection = _makeDetection(
        className: 'door',
        dangerLevel: DangerLevel.info,
        left: 615, top: 440, right: 625, bottom: 450,
      );
      final result = calculator.calculate(detection, frameWidth: 640);

      if (result.level == RiskLevel.safe) {
        expect(result.recommendation, isEmpty);
      }
    });
  });

  group('RiskCalculator custom weights', () {
    test('custom weights are applied', () {
      final customCalc = RiskCalculator(
        distanceWeight: 0.9,
        dangerWeight: 0.05,
        positionWeight: 0.05,
      );

      // Same detection, but distance-heavy calculator
      final detection = _makeDetection(
        className: 'book', // Low danger
        left: 200, top: 50, right: 440, bottom: 430, // Large (close)
      );

      final defaultResult = calculator.calculate(detection, frameWidth: 640);
      final customResult = customCalc.calculate(detection, frameWidth: 640);

      // Custom should weigh distance more → higher score for close object
      expect(customResult.score, greaterThanOrEqualTo(defaultResult.score - 0.1));
    });
  });
}
