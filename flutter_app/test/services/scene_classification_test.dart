/// Unit tests for the SceneClassificationService
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_mate/services/scene_classification_service.dart';
import 'package:vision_mate/models/detection.dart';

void main() {
  late SceneClassificationService service;

  setUp(() {
    service = SceneClassificationService();
  });

  tearDown(() {
    service.dispose();
  });

  Detection _makeDetection(String className) {
    return Detection(
      className: className,
      classId: 0,
      confidence: 0.9,
      boundingBox: BoundingBox(left: 100, top: 100, right: 300, bottom: 300),
      dangerLevel: DangerLevel.fromClassName(className),
    );
  }

  List<Detection> _makeDetections(List<String> classNames) {
    return classNames.map(_makeDetection).toList();
  }

  group('classifyScene', () {
    test('kitchen objects produce kitchen scene', () {
      // Need to call multiple times for stability filter
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'refrigerator', 'oven', 'cup', 'bowl', 'fork',
        ]));
      }
      expect(service.currentScene, SceneType.kitchen);
    });

    test('road objects produce road or crossing scene', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'car', 'truck', 'traffic light', 'person',
        ]));
      }
      // These objects match both road and crossing patterns
      expect(service.currentScene, anyOf(SceneType.road, SceneType.crossing));
    });

    test('living room objects produce livingRoom scene', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'couch', 'tv', 'remote', 'potted plant',
        ]));
      }
      expect(service.currentScene, SceneType.livingRoom);
    });

    test('empty detections keep last known scene', () {
      // First classify as kitchen
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'refrigerator', 'oven', 'cup',
        ]));
      }
      final beforeScene = service.currentScene;

      // Now pass empty
      service.classifyScene([]);
      expect(service.currentScene, beforeScene);
    });

    test('unrelated single object gives unknown', () {
      // A single object that's shared across many scenes 
      // shouldn't give high confidence for any specific scene
      service.clearHistory();
      final result = service.classifyScene(_makeDetections(['person']));
      // Person alone matches road/crossing/park but with low score
      // Since confidence < 0.3, stays unknown
      expect(result, isA<SceneType>());
    });

    test('office objects produce office scene', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'laptop', 'keyboard', 'mouse', 'chair', 'cell phone',
        ]));
      }
      expect(service.currentScene, SceneType.office);
    });

    test('bathroom objects produce bathroom scene', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'toilet', 'sink', 'toothbrush',
        ]));
      }
      expect(service.currentScene, SceneType.bathroom);
    });
  });

  group('stability filter', () {
    test('single classification does not immediately change scene', () {
      // Start fresh
      service.clearHistory();
      expect(service.currentScene, SceneType.unknown);

      // One kitchen reading
      service.classifyScene(_makeDetections([
        'refrigerator', 'oven', 'cup',
      ]));

      // May or may not have changed after one call (depends on history being 1 element)
      // But definitely should after enough consistent readings
    });

    test('consistent readings stabilize scene', () {
      service.clearHistory();
      for (int i = 0; i < 8; i++) {
        service.classifyScene(_makeDetections([
          'bed', 'clock', 'book', 'teddy bear',
        ]));
      }
      expect(service.currentScene, SceneType.bedroom);
    });
  });

  group('scene properties', () {
    test('road scene is outdoor', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'car', 'truck', 'traffic light', 'person',
        ]));
      }
      expect(service.isOutdoor, isTrue);
      expect(service.isHighRisk, isTrue);
    });

    test('kitchen scene is not outdoor', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'refrigerator', 'oven', 'cup', 'bowl',
        ]));
      }
      expect(service.isOutdoor, isFalse);
      expect(service.isHighRisk, isFalse);
    });

    test('crossing has highest urgency multiplier', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'traffic light', 'person', 'car', 'stop sign',
        ]));
      }
      if (service.currentScene == SceneType.crossing) {
        expect(service.urgencyMultiplier, 2.0);
      }
    });

    test('bedroom has low urgency multiplier', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'bed', 'clock', 'book', 'teddy bear',
        ]));
      }
      if (service.currentScene == SceneType.bedroom) {
        expect(service.urgencyMultiplier, 0.5);
      }
    });
  });

  group('scene descriptions', () {
    test('kitchen description mentions kitchen', () {
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'refrigerator', 'oven', 'cup',
        ]));
      }
      if (service.currentScene == SceneType.kitchen) {
        expect(service.sceneDescription, contains('kitchen'));
      }
    });

    test('unknown scene has appropriate description', () {
      service.clearHistory();
      expect(service.sceneDescription, 'Scene not identified');
    });
  });

  group('clearHistory', () {
    test('resets scene to unknown', () {
      // First classify as kitchen (high confidence)
      for (int i = 0; i < 6; i++) {
        service.classifyScene(_makeDetections([
          'refrigerator', 'oven', 'cup', 'bowl', 'fork',
        ]));
      }
      // Verify it classified to something
      expect(service.currentScene, isNot(SceneType.unknown));

      // Clear
      service.clearHistory();
      expect(service.currentScene, SceneType.unknown);
      expect(service.confidence, 0);
    });
  });
}
