/// Unit tests for the OnboardingService
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_mate/services/onboarding_service.dart';

void main() {
  late OnboardingService service;
  late List<String> spokenMessages;
  late bool completionCalled;
  late bool personalizationCalled;

  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = OnboardingService();
    spokenMessages = [];
    completionCalled = false;
    personalizationCalled = false;

    service.onSpeak = (msg) => spokenMessages.add(msg);
    service.onCompleted = () => completionCalled = true;
    service.onStartPersonalization = () => personalizationCalled = true;
  });

  tearDown(() async {
    // Dispose cancels the auto-advance timer via _autoAdvanceTimer?.cancel()
    service.dispose();
    // Allow any pending async operations to settle
    await Future.delayed(const Duration(milliseconds: 50));
  });

  group('initial state', () {
    test('is not active by default', () {
      expect(service.isActive, isFalse);
    });

    test('starts at step 0', () {
      expect(service.currentStep, 0);
    });

    test('has 8 total steps', () {
      expect(service.totalSteps, 8);
    });
  });

  group('startTour', () {
    test('sets isActive to true', () {
      service.startTour();
      expect(service.isActive, isTrue);
    });

    test('sets currentStep to 0', () {
      service.startTour();
      expect(service.currentStep, 0);
    });

    test('speaks the first step message', () {
      service.startTour();
      expect(spokenMessages, hasLength(1));
      expect(spokenMessages.first, contains('Welcome to VisionMate'));
    });

    test('does not start if already active', () {
      service.startTour();
      spokenMessages.clear();
      service.startTour(); // Second call should be no-op
      expect(spokenMessages, isEmpty);
    });
  });

  group('nextStep', () {
    test('advances to next step', () {
      service.startTour();
      service.nextStep();
      expect(service.currentStep, 1);
    });

    test('speaks the new step message', () {
      service.startTour();
      spokenMessages.clear();
      service.nextStep();
      expect(spokenMessages, hasLength(1));
      // Step 1 message: "You can control everything by voice..."
      expect(spokenMessages.first, contains('voice'));
    });

    test('can advance through all steps', () {
      service.startTour();
      for (int i = 0; i < 7; i++) {
        service.nextStep();
      }
      // After advancing 7 times from 0, we're at step 7 (last)
      expect(service.currentStep, 7);
    });

    test('completing last step calls completeTour', () async {
      service.startTour();
      // Advance to last step (index 7)
      for (int i = 0; i < 7; i++) {
        service.nextStep();
      }
      // Now on last step, calling nextStep should complete
      service.nextStep();
      
      // Allow async SharedPreferences operation to complete
      await Future.delayed(const Duration(milliseconds: 200));
      expect(service.isActive, isFalse);
      expect(service.hasCompletedOnboarding, isTrue);
      expect(completionCalled, isTrue);
    });
  });

  group('previousStep', () {
    test('goes back one step', () {
      service.startTour();
      service.nextStep();
      expect(service.currentStep, 1);
      service.previousStep();
      expect(service.currentStep, 0);
    });

    test('does not go below 0', () {
      service.startTour();
      service.previousStep();
      expect(service.currentStep, 0);
    });
  });

  group('skipTour', () {
    test('completes the tour immediately', () async {
      service.startTour();
      service.skipTour();

      await Future.delayed(const Duration(milliseconds: 200));
      expect(service.isActive, isFalse);
      expect(service.hasCompletedOnboarding, isTrue);
      expect(completionCalled, isTrue);
    });
  });

  group('handleResponse', () {
    test('yes on last step triggers personalization', () async {
      service.startTour();
      // Go to last step
      for (int i = 0; i < 7; i++) {
        service.nextStep();
      }
      expect(service.currentStep, 7);

      service.handleResponse(true);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(personalizationCalled, isTrue);
      expect(service.hasCompletedOnboarding, isTrue);
    });

    test('no on last step completes without personalization', () async {
      service.startTour();
      for (int i = 0; i < 7; i++) {
        service.nextStep();
      }

      service.handleResponse(false);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(personalizationCalled, isFalse);
      expect(service.hasCompletedOnboarding, isTrue);
    });

    test('response on non-last step is ignored', () {
      service.startTour();
      // On step 0, not last step
      service.handleResponse(true);
      expect(personalizationCalled, isFalse);
      expect(service.isActive, isTrue); // Still active
    });
  });

  group('resetOnboarding', () {
    test('resets completion flag', () async {
      service.startTour();
      service.skipTour();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(service.hasCompletedOnboarding, isTrue);

      await service.resetOnboarding();
      expect(service.hasCompletedOnboarding, isFalse);
    });
  });

  group('ChangeNotifier', () {
    test('notifies listeners on startTour', () {
      bool notified = false;
      service.addListener(() => notified = true);
      service.startTour();
      expect(notified, isTrue);
    });

    test('notifies listeners on nextStep', () {
      service.startTour();
      bool notified = false;
      service.addListener(() => notified = true);
      service.nextStep();
      expect(notified, isTrue);
    });
  });
}
