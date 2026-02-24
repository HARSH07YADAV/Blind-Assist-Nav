/// Unit tests for the TutorialService
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_mate/services/tutorial_service.dart';
import 'package:vision_mate/models/detection.dart';

void main() {
  late TutorialService service;
  late List<String> spokenMessages;
  late List<List<Detection>> simulatedDetections;
  late bool completionCalled;

  setUp(() {
    service = TutorialService();
    spokenMessages = [];
    simulatedDetections = [];
    completionCalled = false;

    service.onSpeak = (msg) => spokenMessages.add(msg);
    service.onSimulateDetections = (detections) => simulatedDetections.add(detections);
    service.onCompleted = () => completionCalled = true;
  });

  tearDown(() {
    // Stop any active tutorial to cancel timers before dispose
    if (service.isActive) {
      service.stopTutorial();
    }
    service.dispose();
  });

  group('initial state', () {
    test('is not active by default', () {
      expect(service.isActive, isFalse);
    });

    test('starts at scenario 0', () {
      expect(service.currentScenario, 0);
    });

    test('has 5 total scenarios', () {
      expect(service.totalScenarios, 5);
    });

    test('no practiced commands initially', () {
      expect(service.practicedCommands, isEmpty);
    });
  });

  group('startTutorial', () {
    test('sets isActive to true', () {
      service.startTutorial();
      expect(service.isActive, isTrue);
    });

    test('speaks the first scenario prompt', () {
      service.startTutorial();
      expect(spokenMessages, hasLength(1));
      expect(spokenMessages.first, contains('practice'));
    });

    test('simulates detections for first scenario', () {
      service.startTutorial();
      expect(simulatedDetections, hasLength(1));
      // First scenario is "Basic Detection" — should have a chair
      expect(simulatedDetections.first.any((d) => d.className == 'chair'), isTrue);
    });

    test('does not start if already active', () {
      service.startTutorial();
      spokenMessages.clear();
      service.startTutorial();
      expect(spokenMessages, isEmpty);
    });

    test('clears previously practiced commands', () {
      service.startTutorial();
      service.onCommandExecuted('whatsAhead');
      expect(service.practicedCommands, isNotEmpty);
      
      service.stopTutorial();
      service.startTutorial();
      expect(service.practicedCommands, isEmpty);
    });
  });

  group('onCommandExecuted', () {
    test('tracks practiced command', () {
      service.startTutorial();
      service.onCommandExecuted('whatsAhead');
      expect(service.practicedCommands, contains('whatsAhead'));
    });

    test('non-matching command is tracked but scenario stays', () {
      service.startTutorial();
      service.onCommandExecuted('randomCommand');
      expect(service.practicedCommands, contains('randomCommand'));
      expect(service.currentScenario, 0); // Still on first scenario
    });

    test('does nothing when not active', () {
      service.onCommandExecuted('whatsAhead');
      expect(service.practicedCommands, isEmpty);
    });
  });

  group('skipToNext', () {
    test('advances to next scenario', () {
      service.startTutorial();
      spokenMessages.clear();
      simulatedDetections.clear();
      
      service.skipToNext();
      expect(service.currentScenario, 1);
      expect(spokenMessages, hasLength(1)); // New scenario prompt
    });

    test('does nothing when not active', () {
      service.skipToNext();
      expect(service.currentScenario, 0);
    });
  });

  group('stopTutorial', () {
    test('deactivates the tutorial', () {
      service.startTutorial();
      service.stopTutorial();
      expect(service.isActive, isFalse);
    });

    test('clears simulated detections', () {
      service.startTutorial();
      simulatedDetections.clear();
      service.stopTutorial();
      // Should call onSimulateDetections with empty list
      expect(simulatedDetections.last, isEmpty);
    });

    test('announces practiced count', () {
      service.startTutorial();
      service.onCommandExecuted('whatsAhead');
      spokenMessages.clear();
      service.stopTutorial();

      expect(spokenMessages.last, contains('practiced'));
      expect(spokenMessages.last, contains('1'));
    });

    test('resets scenario index', () {
      service.startTutorial();
      service.skipToNext();
      service.stopTutorial();
      expect(service.currentScenario, 0);
    });
  });

  group('tutorial completion', () {
    test('completes after all scenarios are done', () {
      service.startTutorial();

      // Skip through all 5 scenarios
      for (int i = 0; i < 5; i++) {
        service.skipToNext();
      }

      expect(service.isActive, isFalse);
      expect(completionCalled, isTrue);
    });

    test('completion message includes complete', () {
      service.startTutorial();
      service.onCommandExecuted('whatsAhead');

      // Skip through remaining
      for (int i = 0; i < 5; i++) {
        service.skipToNext();
      }

      final completionMsg = spokenMessages.last;
      expect(completionMsg, contains('complete'));
    });
  });

  group('ChangeNotifier', () {
    test('notifies listeners on startTutorial', () {
      bool notified = false;
      service.addListener(() => notified = true);
      service.startTutorial();
      expect(notified, isTrue);
    });

    test('notifies listeners on skipToNext', () {
      service.startTutorial();
      bool notified = false;
      service.addListener(() => notified = true);
      service.skipToNext();
      expect(notified, isTrue);
    });
  });
}
