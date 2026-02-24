/// Unit tests for the PersonalizationWizardService
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_mate/services/personalization_wizard_service.dart';

void main() {
  late PersonalizationWizardService service;
  late List<String> spokenMessages;
  late Map<String, dynamic> appliedSettings;
  late bool completionCalled;

  setUp(() {
    service = PersonalizationWizardService();
    spokenMessages = [];
    appliedSettings = {};
    completionCalled = false;

    service.onSpeak = (msg) => spokenMessages.add(msg);
    service.onApplySetting = (key, value) => appliedSettings[key] = value;
    service.onCompleted = () => completionCalled = true;
  });

  tearDown(() {
    // Cancel wizard to stop timers before dispose
    if (service.isActive) {
      service.cancelWizard();
    }
    service.dispose();
  });

  group('initial state', () {
    test('is not active by default', () {
      expect(service.isActive, isFalse);
    });

    test('starts at step 0', () {
      expect(service.currentStep, 0);
    });

    test('has 4 total steps', () {
      expect(service.totalSteps, 4);
    });
  });

  group('startWizard', () {
    test('sets isActive to true', () {
      service.startWizard();
      expect(service.isActive, isTrue);
    });

    test('speaks the first step prompt', () {
      service.startWizard();
      expect(spokenMessages, hasLength(1));
      expect(spokenMessages.first, contains('how fast should I speak'));
    });

    test('does not start if already active', () {
      service.startWizard();
      spokenMessages.clear();
      service.startWizard();
      expect(spokenMessages, isEmpty);
    });
  });

  group('handleResponse - Speech Speed (step 0)', () {
    test('slower sets speech rate to 0.35', () {
      service.startWizard();
      service.handleResponse('slower');
      expect(appliedSettings['speechRate'], 0.35);
    });

    test('faster sets speech rate to 0.7', () {
      service.startWizard();
      service.handleResponse('faster');
      expect(appliedSettings['speechRate'], 0.7);
    });

    test('normal sets speech rate to 0.5', () {
      service.startWizard();
      service.handleResponse('normal');
      expect(appliedSettings['speechRate'], 0.5);
    });

    test('unrecognized input defaults to normal', () {
      service.startWizard();
      service.handleResponse('gibberish');
      expect(appliedSettings['speechRate'], 0.5);
    });

    test('speaks confirmation after setting', () {
      service.startWizard();
      spokenMessages.clear();
      service.handleResponse('slower');
      expect(spokenMessages.any((m) => m.contains('slow')), isTrue);
    });
  });

  group('skipStep', () {
    test('applies default for speech speed (0.5)', () {
      service.startWizard();
      service.skipStep();
      expect(appliedSettings['speechRate'], 0.5);
    });

    test('does nothing when not active', () {
      service.skipStep();
      expect(appliedSettings, isEmpty);
    });
  });

  group('cancelWizard', () {
    test('deactivates the wizard', () {
      service.startWizard();
      service.cancelWizard();
      expect(service.isActive, isFalse);
    });

    test('announces cancellation', () {
      service.startWizard();
      spokenMessages.clear();
      service.cancelWizard();
      expect(spokenMessages.last, contains('cancelled'));
    });
  });

  group('wizard completion via skipStep', () {
    test('completes after skipping all steps', () async {
      service.startWizard();

      // Skip through all 4 steps synchronously (skipStep calls _advance internally)
      service.skipStep(); // Step 0 → 1
      service.skipStep(); // Step 1 → 2
      service.skipStep(); // Step 2 → 3
      service.skipStep(); // Step 3 → complete

      expect(service.isActive, isFalse);
      expect(completionCalled, isTrue);
    });

    test('applies defaults for all steps when skipping', () {
      service.startWizard();
      service.skipStep();
      service.skipStep();
      service.skipStep();
      service.skipStep();

      expect(appliedSettings['speechRate'], 0.5);
      expect(appliedSettings['verbosity'], 'normal');
      expect(appliedSettings['userMode'], 'beginner');
    });

    test('completion message mentions Setup complete', () {
      service.startWizard();
      service.skipStep();
      service.skipStep();
      service.skipStep();
      service.skipStep();

      expect(spokenMessages.any((m) => m.contains('Setup complete')), isTrue);
    });
  });

  group('ChangeNotifier', () {
    test('notifies listeners on startWizard', () {
      bool notified = false;
      service.addListener(() => notified = true);
      service.startWizard();
      expect(notified, isTrue);
    });
  });
}
