/// Unit tests for the Detection model, BoundingBox, DangerLevel, and RiskLevel
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_mate/models/detection.dart';

void main() {
  group('BoundingBox', () {
    test('computes width and height correctly', () {
      final box = BoundingBox(left: 10, top: 20, right: 110, bottom: 120);
      expect(box.width, 100);
      expect(box.height, 100);
    });

    test('computes center coordinates', () {
      final box = BoundingBox(left: 0, top: 0, right: 200, bottom: 100);
      expect(box.centerX, 100);
      expect(box.centerY, 50);
    });

    test('computes area', () {
      final box = BoundingBox(left: 0, top: 0, right: 50, bottom: 80);
      expect(box.area, 4000);
    });

    test('handles zero-size box', () {
      final box = BoundingBox(left: 50, top: 50, right: 50, bottom: 50);
      expect(box.width, 0);
      expect(box.height, 0);
      expect(box.area, 0);
    });
  });

  group('Detection.relativePosition', () {
    Detection _makeDetection(double left, double right) {
      return Detection(
        className: 'chair',
        classId: 56,
        confidence: 0.9,
        boundingBox: BoundingBox(left: left, top: 100, right: right, bottom: 300),
        dangerLevel: DangerLevel.medium,
      );
    }

    test('left third returns RelativePosition.left', () {
      // centerX = (0 + 100) / 2 = 50 → normalized = 50/640 = 0.078 < 0.33
      final d = _makeDetection(0, 100);
      expect(d.relativePosition, RelativePosition.left);
    });

    test('center third returns RelativePosition.center', () {
      // centerX = (250 + 390) / 2 = 320 → normalized = 320/640 = 0.5
      final d = _makeDetection(250, 390);
      expect(d.relativePosition, RelativePosition.center);
    });

    test('right third returns RelativePosition.right', () {
      // centerX = (500 + 640) / 2 = 570 → normalized = 570/640 = 0.89 > 0.67
      final d = _makeDetection(500, 640);
      expect(d.relativePosition, RelativePosition.right);
    });
  });

  group('Detection.distanceDescription', () {
    Detection _makeWithDistance(double meters) {
      return Detection(
        className: 'person',
        classId: 0,
        confidence: 0.9,
        boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
        dangerLevel: DangerLevel.high,
        distanceMeters: meters,
      );
    }

    test('negative distance returns unknown', () {
      expect(_makeWithDistance(-1).distanceDescription, 'unknown distance');
    });

    test('0.5m returns very close', () {
      expect(_makeWithDistance(0.5).distanceDescription, 'very close');
    });

    test('1.5m returns nearby', () {
      expect(_makeWithDistance(1.5).distanceDescription, 'nearby');
    });

    test('3.0m returns ahead', () {
      expect(_makeWithDistance(3.0).distanceDescription, 'ahead');
    });

    test('10.0m returns in the distance', () {
      expect(_makeWithDistance(10.0).distanceDescription, 'in the distance');
    });
  });

  group('DangerLevel.fromClassName', () {
    test('stairs returns critical', () {
      expect(DangerLevel.fromClassName('stairs'), DangerLevel.critical);
    });

    test('crosswalk returns critical', () {
      expect(DangerLevel.fromClassName('crosswalk'), DangerLevel.critical);
    });

    test('person returns high', () {
      expect(DangerLevel.fromClassName('person'), DangerLevel.high);
    });

    test('traffic light returns high', () {
      expect(DangerLevel.fromClassName('traffic light'), DangerLevel.high);
    });

    test('chair returns medium', () {
      expect(DangerLevel.fromClassName('chair'), DangerLevel.medium);
    });

    test('book returns low', () {
      expect(DangerLevel.fromClassName('book'), DangerLevel.low);
    });

    test('door returns info', () {
      expect(DangerLevel.fromClassName('door'), DangerLevel.info);
    });

    test('unknown class returns unknown', () {
      expect(DangerLevel.fromClassName('spaceship'), DangerLevel.unknown);
    });

    test('case insensitive', () {
      expect(DangerLevel.fromClassName('Person'), DangerLevel.high);
      expect(DangerLevel.fromClassName('CHAIR'), DangerLevel.medium);
    });
  });

  group('RiskLevel.fromScore', () {
    test('score 0.9 returns critical', () {
      expect(RiskLevel.fromScore(0.9), RiskLevel.critical);
    });

    test('score 0.7 returns high', () {
      expect(RiskLevel.fromScore(0.7), RiskLevel.high);
    });

    test('score 0.5 returns medium', () {
      expect(RiskLevel.fromScore(0.5), RiskLevel.medium);
    });

    test('score 0.3 returns low', () {
      expect(RiskLevel.fromScore(0.3), RiskLevel.low);
    });

    test('score 0.1 returns safe', () {
      expect(RiskLevel.fromScore(0.1), RiskLevel.safe);
    });

    test('boundary: 0.85 returns critical', () {
      expect(RiskLevel.fromScore(0.85), RiskLevel.critical);
    });

    test('boundary: 0.65 returns high', () {
      expect(RiskLevel.fromScore(0.65), RiskLevel.high);
    });

    test('boundary: 0.40 returns medium', () {
      expect(RiskLevel.fromScore(0.40), RiskLevel.medium);
    });

    test('boundary: 0.20 returns low', () {
      expect(RiskLevel.fromScore(0.20), RiskLevel.low);
    });

    test('score 0.0 returns safe', () {
      expect(RiskLevel.fromScore(0.0), RiskLevel.safe);
    });
  });

  group('RiskAssessment', () {
    test('alertKey combines class, position, and level', () {
      final detection = Detection(
        className: 'person',
        classId: 0,
        confidence: 0.95,
        boundingBox: BoundingBox(left: 250, top: 100, right: 390, bottom: 300),
        dangerLevel: DangerLevel.high,
      );
      final assessment = RiskAssessment(
        detection: detection,
        score: 0.8,
        level: RiskLevel.high,
        recommendation: 'Caution!',
        shouldAlert: true,
      );
      expect(assessment.alertKey, 'person_RelativePosition.center_RiskLevel.high');
    });
  });

  group('DangerLevel properties', () {
    test('critical has highest weight', () {
      expect(DangerLevel.critical.weight, 1.0);
    });

    test('info has lowest weight', () {
      expect(DangerLevel.info.weight, 0.1);
    });

    test('alert priority ordering: critical < high < medium < low < info', () {
      expect(DangerLevel.critical.alertPriority, 0);
      expect(DangerLevel.high.alertPriority, 1);
      expect(DangerLevel.medium.alertPriority, 2);
      expect(DangerLevel.low.alertPriority, 3);
      expect(DangerLevel.info.alertPriority, 4);
    });
  });
}
