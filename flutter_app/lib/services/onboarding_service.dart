import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Week 6: Guided Onboarding Tour Service
/// 
/// Voice-driven first-launch experience that introduces VisionMate's
/// features step-by-step. No visual UI needed — purely audio-guided.
/// 
/// Steps:
/// 1. Welcome & overview
/// 2. Voice command basics
/// 3. Detection & navigation
/// 4. Emergency SOS
/// 5. Reading & currency
/// 6. Smart features (scene, traffic, landmarks)
/// 7. Settings & personalization
/// 8. Completion & next steps
class OnboardingService extends ChangeNotifier {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const int _autoAdvanceSeconds = 12;
  
  bool _isInitialized = false;
  bool _hasCompletedOnboarding = false;
  bool _isActive = false;
  int _currentStep = 0;
  Timer? _autoAdvanceTimer;
  
  // Callbacks
  Function(String message)? onSpeak;
  Function()? onCompleted;
  Function()? onStartPersonalization;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isActive => _isActive;
  int get currentStep => _currentStep;
  int get totalSteps => _steps.length;
  
  /// Onboarding steps with TTS messages
  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      title: 'Welcome',
      message: 'Welcome to VisionMate! I\'m your personal navigation assistant. '
          'I use your phone\'s camera to detect obstacles and guide you safely. '
          'Let me walk you through the main features. Say "next" to continue, '
          'or I\'ll move on automatically.',
    ),
    _OnboardingStep(
      title: 'Voice Commands',
      message: 'You can control everything by voice. Just say "Hey Vision" to wake me up, '
          'then give a command. For example: "What\'s ahead", "Find the door", '
          '"Read this", or "Help" for emergencies. Say "next" to continue.',
    ),
    _OnboardingStep(
      title: 'Detection',
      message: 'When detection is active, I continuously scan for obstacles using your camera. '
          'I\'ll tell you what\'s ahead and how far away it is, like "chair, about two steps away". '
          'I also vibrate to warn you of nearby dangers. Say "next" to continue.',
    ),
    _OnboardingStep(
      title: 'Emergency',
      message: 'For emergencies, say "Help" or "SOS" anytime. I can also detect falls automatically '
          'and send alerts to your emergency contacts. You can add up to 5 contacts by saying '
          '"Add emergency contact". Say "next" to continue.',
    ),
    _OnboardingStep(
      title: 'Reading',
      message: 'I can read text for you. Point your camera at a sign or label and say "Read this". '
          'I can also identify Indian currency notes — just say "What note is this". '
          'Say "next" to continue.',
    ),
    _OnboardingStep(
      title: 'Smart Features',
      message: 'I understand your environment. I can tell you if you\'re in a kitchen, office, or near a road. '
          'I detect traffic lights, crosswalks, doors, and stairs. '
          'I even remember places you visit often. Say "next" to continue.',
    ),
    _OnboardingStep(
      title: 'Settings',
      message: 'You can customize everything by voice. Say "less talk" for fewer announcements, '
          '"more detail" for more information, "switch to Hindi" for Hindi mode, '
          'or "vibration off" to disable vibration. Say "next" to continue.',
    ),
    _OnboardingStep(
      title: 'Complete',
      message: 'That\'s everything! You\'re ready to use VisionMate. '
          'Tap the big Start button or say "Start" to begin detection. '
          'Say "Help" anytime if you need assistance. '
          'Would you like to set up your preferences now? Say "yes" to start the setup wizard.',
    ),
  ];
  
  /// Initialize and check if onboarding has been completed
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedOnboarding = prefs.getBool(_keyOnboardingCompleted) ?? false;
      _isInitialized = true;
      debugPrint('[Onboarding] Initialized — completed: $_hasCompletedOnboarding');
      notifyListeners();
    } catch (e) {
      debugPrint('[Onboarding] Init error: $e');
      _isInitialized = true;
      _hasCompletedOnboarding = true; // Don't block on error
    }
  }
  
  /// Start the onboarding tour
  void startTour() {
    if (_isActive) return;
    
    _isActive = true;
    _currentStep = 0;
    notifyListeners();
    
    debugPrint('[Onboarding] Starting tour');
    _speakCurrentStep();
  }
  
  /// Advance to the next step
  void nextStep() {
    _autoAdvanceTimer?.cancel();
    
    if (_currentStep >= _steps.length - 1) {
      // Last step: complete the tour
      _completeTour();
      return;
    }
    
    _currentStep++;
    notifyListeners();
    _speakCurrentStep();
  }
  
  /// Go back to the previous step
  void previousStep() {
    _autoAdvanceTimer?.cancel();
    
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
      _speakCurrentStep();
    }
  }
  
  /// Skip the entire onboarding
  void skipTour() {
    _autoAdvanceTimer?.cancel();
    _completeTour();
  }
  
  /// Speak the current step and set up auto-advance
  void _speakCurrentStep() {
    if (_currentStep >= _steps.length) return;
    
    final step = _steps[_currentStep];
    onSpeak?.call(step.message);
    
    // Auto-advance after timeout (except last step)
    if (_currentStep < _steps.length - 1) {
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(
        const Duration(seconds: _autoAdvanceSeconds),
        nextStep,
      );
    }
  }
  
  /// Complete the onboarding tour
  Future<void> _completeTour() async {
    _isActive = false;
    _hasCompletedOnboarding = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, true);
    } catch (e) {
      debugPrint('[Onboarding] Save error: $e');
    }
    
    notifyListeners();
    onCompleted?.call();
    debugPrint('[Onboarding] Tour completed');
  }
  
  /// Handle user response during onboarding (for last step yes/no)
  void handleResponse(bool isYes) {
    if (_currentStep == _steps.length - 1 && isYes) {
      // User wants personalization wizard
      _completeTour().then((_) {
        onStartPersonalization?.call();
      });
    } else if (_currentStep == _steps.length - 1 && !isYes) {
      _completeTour();
    }
  }
  
  /// Reset onboarding (for testing or re-triggering)
  Future<void> resetOnboarding() async {
    _hasCompletedOnboarding = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, false);
    } catch (e) {
      debugPrint('[Onboarding] Reset error: $e');
    }
    notifyListeners();
  }
  
  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }
}

/// A single step in the onboarding tour
class _OnboardingStep {
  final String title;
  final String message;
  
  const _OnboardingStep({
    required this.title,
    required this.message,
  });
}
