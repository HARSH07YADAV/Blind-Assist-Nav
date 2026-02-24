import 'dart:async';
import 'package:flutter/foundation.dart';

/// Week 6: Personalization Wizard Service
/// 
/// Voice-guided setup wizard that walks users through customizing
/// their VisionMate experience. Can be triggered from onboarding
/// or manually via "setup wizard" voice command.
/// 
/// Steps:
/// 1. Speech speed preference
/// 2. Verbosity level
/// 3. Emergency contact setup prompt
/// 4. Beginner/Advanced mode selection
class PersonalizationWizardService extends ChangeNotifier {
  bool _isActive = false;
  int _currentStep = 0;
  Timer? _responseTimer;
  
  // Callbacks
  Function(String message)? onSpeak;
  Function()? onCompleted;
  Function(String setting, dynamic value)? onApplySetting;
  Function()? onPromptEmergencyContact;
  
  // Getters
  bool get isActive => _isActive;
  int get currentStep => _currentStep;
  int get totalSteps => _wizardSteps.length;
  
  /// Wizard steps
  static const List<_WizardStep> _wizardSteps = [
    _WizardStep(
      title: 'Speech Speed',
      prompt: 'Let\'s set up VisionMate for you. '
          'First, how fast should I speak? '
          'Say "slower" for a calm pace, "normal" for regular speed, '
          'or "faster" for quick updates.',
      settingKey: 'speechSpeed',
      options: ['slower', 'normal', 'faster'],
    ),
    _WizardStep(
      title: 'Verbosity',
      prompt: 'How much detail do you want in announcements? '
          'Say "minimal" for just beeps and short alerts, '
          '"normal" for brief phrases, '
          'or "detailed" for full descriptions with distances and directions.',
      settingKey: 'verbosity',
      options: ['minimal', 'normal', 'detailed'],
    ),
    _WizardStep(
      title: 'Emergency Contacts',
      prompt: 'Would you like to add an emergency contact now? '
          'This person will be notified if you fall or say "Help". '
          'Say "yes" to add a contact, or "skip" to do it later.',
      settingKey: 'emergencyContact',
      options: ['yes', 'skip'],
    ),
    _WizardStep(
      title: 'Experience Mode',
      prompt: 'Finally, are you new to assistive technology? '
          'Say "beginner" for more guidance and frequent updates, '
          'or "advanced" for minimal alerts and faster speech. '
          'You can change this anytime.',
      settingKey: 'userMode',
      options: ['beginner', 'advanced'],
    ),
  ];
  
  /// Start the wizard
  void startWizard() {
    if (_isActive) return;
    
    _isActive = true;
    _currentStep = 0;
    notifyListeners();
    
    debugPrint('[Wizard] Starting personalization wizard');
    _speakCurrentStep();
  }
  
  /// Speak the current step prompt
  void _speakCurrentStep() {
    if (_currentStep >= _wizardSteps.length) return;
    
    final step = _wizardSteps[_currentStep];
    onSpeak?.call(step.prompt);
    
    // Auto-advance with default after 15 seconds
    _responseTimer?.cancel();
    _responseTimer = Timer(const Duration(seconds: 15), () {
      onSpeak?.call('No response heard. Using the default setting. Moving on.');
      _applyDefault();
      _advance();
    });
  }
  
  /// Handle user response to the current wizard step
  void handleResponse(String response) {
    if (!_isActive || _currentStep >= _wizardSteps.length) return;
    
    _responseTimer?.cancel();
    final step = _wizardSteps[_currentStep];
    final lower = response.toLowerCase().trim();
    
    switch (step.settingKey) {
      case 'speechSpeed':
        if (lower.contains('slow')) {
          onApplySetting?.call('speechRate', 0.35);
          onSpeak?.call('Speech set to slow pace.');
        } else if (lower.contains('fast') || lower.contains('quick')) {
          onApplySetting?.call('speechRate', 0.7);
          onSpeak?.call('Speech set to fast pace.');
        } else {
          onApplySetting?.call('speechRate', 0.5);
          onSpeak?.call('Speech set to normal pace.');
        }
        break;
        
      case 'verbosity':
        if (lower.contains('minimal') || lower.contains('less') || lower.contains('beep')) {
          onApplySetting?.call('verbosity', 'minimal');
          onSpeak?.call('Verbosity set to minimal. You\'ll hear mostly beeps.');
        } else if (lower.contains('detail') || lower.contains('more') || lower.contains('full')) {
          onApplySetting?.call('verbosity', 'detailed');
          onSpeak?.call('Verbosity set to detailed. Full descriptions enabled.');
        } else {
          onApplySetting?.call('verbosity', 'normal');
          onSpeak?.call('Verbosity set to normal.');
        }
        break;
        
      case 'emergencyContact':
        if (lower.contains('yes') || lower.contains('add') || lower.contains('sure')) {
          onSpeak?.call('To add a contact, say "Add emergency contact" followed by the name and phone number after the wizard.');
          onPromptEmergencyContact?.call();
        } else {
          onSpeak?.call('No problem. You can add contacts anytime by saying "Add emergency contact".');
        }
        break;
        
      case 'userMode':
        if (lower.contains('advanced') || lower.contains('expert') || lower.contains('experienced')) {
          onApplySetting?.call('userMode', 'advanced');
          onSpeak?.call('Advanced mode set. Fewer announcements, faster speech.');
        } else {
          onApplySetting?.call('userMode', 'beginner');
          onSpeak?.call('Beginner mode set. More guidance and reassurance.');
        }
        break;
    }
    
    // Short delay before next step
    Future.delayed(const Duration(seconds: 2), _advance);
  }
  
  /// Apply default value for current step
  void _applyDefault() {
    if (_currentStep >= _wizardSteps.length) return;
    
    final step = _wizardSteps[_currentStep];
    switch (step.settingKey) {
      case 'speechSpeed':
        onApplySetting?.call('speechRate', 0.5);
        break;
      case 'verbosity':
        onApplySetting?.call('verbosity', 'normal');
        break;
      case 'emergencyContact':
        // Skip — no default action
        break;
      case 'userMode':
        onApplySetting?.call('userMode', 'beginner');
        break;
    }
  }
  
  /// Advance to the next step
  void _advance() {
    _currentStep++;
    notifyListeners();
    
    if (_currentStep >= _wizardSteps.length) {
      _completeWizard();
    } else {
      _speakCurrentStep();
    }
  }
  
  /// Skip to the next step
  void skipStep() {
    if (!_isActive) return;
    _responseTimer?.cancel();
    _applyDefault();
    _advance();
  }
  
  /// Complete the wizard
  void _completeWizard() {
    _responseTimer?.cancel();
    _isActive = false;
    
    onSpeak?.call('Setup complete! Your preferences have been saved. '
        'Say "Start" to begin detection, or "Help" for a list of commands.');
    
    notifyListeners();
    onCompleted?.call();
    debugPrint('[Wizard] Personalization complete');
  }
  
  /// Cancel the wizard
  void cancelWizard() {
    _responseTimer?.cancel();
    _isActive = false;
    
    onSpeak?.call('Setup wizard cancelled. Default settings will be used. '
        'Say "setup wizard" anytime to try again.');
    
    notifyListeners();
    debugPrint('[Wizard] Cancelled');
  }
  
  @override
  void dispose() {
    _responseTimer?.cancel();
    super.dispose();
  }
}

/// A wizard step definition
class _WizardStep {
  final String title;
  final String prompt;
  final String settingKey;
  final List<String> options;
  
  const _WizardStep({
    required this.title,
    required this.prompt,
    required this.settingKey,
    required this.options,
  });
}
