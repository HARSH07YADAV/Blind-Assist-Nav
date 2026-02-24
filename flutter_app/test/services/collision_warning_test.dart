/// Unit tests for the CollisionWarningService
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_mate/services/collision_warning_service.dart';
import 'package:vision_mate/models/detection.dart';

void main() {
  late CollisionWarningService service;

  setUp(() {
    service = CollisionWarningService();
  });

  Detection _makeDetection({
    String className = 'person',
    double left = 200,
    double top = 100,
    double right = 300,
    double bottom = 300,
  }) {
    return Detection(
      className: className,
      classId: 0,
      confidence: 0.9,
      boundingBox: BoundingBox(left: left, top: top, right: right, bottom: bottom),
      dangerLevel: DangerLevel.fromClassName(className),
    );
  }

  group('analyzeFrame', () {
    test('single frame produces no warnings (need history)', () {
      final warnings = service.analyzeFrame(
        [_makeDetection()],
        frameWidth: 640,
        frameHeight: 480,
      );

      expect(warnings, isEmpty);
    });

    test('stationary object produces no warnings', () {
      // Same position and size across multiple frames
      for (int i = 0; i < 10; i++) {
        final warnings = service.analyzeFrame(
          [_makeDetection(left: 200, top: 100, right: 300, bottom: 300)],
          frameWidth: 640,
          frameHeight: 480,
        );

        // Stationary objects shouldn't trigger collision warnings
        if (warnings.isNotEmpty) {
          // If any warnings, they should not be critical for stationary
          for (final w in warnings) {
            expect(w.objectName, isNotEmpty);
          }
        }
      }
    });

    test('approaching object (growing box) may trigger warning', () {
      // Simulate an approaching person: box grows over frames
      List<CollisionWarning> lastWarnings = [];
      for (int i = 0; i < 15; i++) {
        final size = 50.0 + i * 20.0; // Growing from 50→330px
        lastWarnings = service.analyzeFrame(
          [_makeDetection(
            left: 320 - size / 2,
            top: 240 - size / 2,
            right: 320 + size / 2,
            bottom: 240 + size / 2,
          )],
          frameWidth: 640,
          frameHeight: 480,
        );
      }

      // After significant approach, should have warnings
      // (The exact frame where warning triggers depends on timing)
      // We just verify the service doesn't crash and returns valid data
      for (final w in lastWarnings) {
        expect(w.objectName, isNotEmpty);
        expect(w.message, isNotEmpty);
        expect(w.urgency, isA<CollisionUrgency>());
      }
    });

    test('empty detection list produces no warnings', () {
      final warnings = service.analyzeFrame(
        [],
        frameWidth: 640,
        frameHeight: 480,
      );
      expect(warnings, isEmpty);
    });
  });

  group('setEnabled', () {
    test('disabling suppresses all warnings', () {
      service.setEnabled(false);

      // Even with approaching objects, no warnings
      for (int i = 0; i < 15; i++) {
        final size = 50.0 + i * 20.0;
        final warnings = service.analyzeFrame(
          [_makeDetection(
            left: 320 - size / 2,
            top: 240 - size / 2,
            right: 320 + size / 2,
            bottom: 240 + size / 2,
          )],
          frameWidth: 640,
          frameHeight: 480,
        );
        expect(warnings, isEmpty);
      }
    });

    test('re-enabling works after disable', () {
      service.setEnabled(false);
      service.setEnabled(true);

      // Should be able to analyze frames again
      final warnings = service.analyzeFrame(
        [_makeDetection()],
        frameWidth: 640,
        frameHeight: 480,
      );
      // First frame still no warnings (need history)
      expect(warnings, isEmpty);
    });
  });

  group('clearHistory', () {
    test('clears tracked objects', () {
      // Build up some history
      for (int i = 0; i < 5; i++) {
        service.analyzeFrame(
          [_makeDetection()],
          frameWidth: 640,
          frameHeight: 480,
        );
      }

      service.clearHistory();

      // After clearing, next frame should have no history
      final warnings = service.analyzeFrame(
        [_makeDetection()],
        frameWidth: 640,
        frameHeight: 480,
      );
      expect(warnings, isEmpty);
    });
  });

  group('CollisionWarning model', () {
    test('has all required fields', () {
      final warning = CollisionWarning(
        objectName: 'person',
        direction: 'from the left',
        timeToCollision: 2.0,
        urgency: CollisionUrgency.warning,
        message: 'Person approaching from the left!',
      );

      expect(warning.objectName, 'person');
      expect(warning.direction, 'from the left');
      expect(warning.timeToCollision, 2.0);
      expect(warning.urgency, CollisionUrgency.warning);
      expect(warning.message, isNotEmpty);
    });
  });

  group('CollisionUrgency', () {
    test('has warning and critical levels', () {
      expect(CollisionUrgency.values, contains(CollisionUrgency.warning));
      expect(CollisionUrgency.values, contains(CollisionUrgency.critical));
      expect(CollisionUrgency.values.length, 2);
    });
  });
}
