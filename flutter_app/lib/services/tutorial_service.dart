import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/detection.dart';

/// Week 6: Tutorial Mode Service
/// 
/// Practice mode where users can explore and learn app responses
/// without needing to be in a real environment. Simulates detections
/// and guides users through voice commands step-by-step.
/// 
/// Features:
/// - Simulated fake detections (chair, person, door, etc.)
/// - Guided practice scenarios with prompts
/// - Tracks which commands the user has practiced
/// - Auto-exits after all steps or on "stop tutorial"
class TutorialService extends ChangeNotifier {
  bool _isActive = false;
  int _currentScenario = 0;
  Timer? _scenarioTimer;
  final Set<String> _practicedCommands = {};
  
  // Callbacks
  Function(String message)? onSpeak;
  Function(List<Detection> detections)? onSimulateDetections;
  Function()? onCompleted;
  
  // Getters
  bool get isActive => _isActive;
  int get currentScenario => _currentScenario;
  int get totalScenarios => _scenarios.length;
  Set<String> get practicedCommands => _practicedCommands;
  
  /// Tutorial scenarios
  static final List<_TutorialScenario> _scenarios = [
    _TutorialScenario(
      title: 'Basic Detection',
      prompt: 'Let\'s practice! I\'m simulating a chair about two steps ahead. '
          'Try saying "What\'s ahead" to hear about it.',
      expectedCommand: 'whatsAhead',
      simulatedDetections: [
        Detection(
          className: 'chair',
          classId: 56,
          confidence: 0.92,
          boundingBox: BoundingBox(left: 192, top: 256, right: 320, bottom: 448),
          dangerLevel: DangerLevel.medium,
          distanceMeters: 1.5,
        ),
      ],
    ),
    _TutorialScenario(
      title: 'Find Object',
      prompt: 'Good! Now I\'m simulating a door on your left. '
          'Try saying "Find the door" to locate it.',
      expectedCommand: 'findObject',
      simulatedDetections: [
        Detection(
          className: 'door',
          classId: 0,
          confidence: 0.88,
          boundingBox: BoundingBox(left: 32, top: 64, right: 128, bottom: 448),
          dangerLevel: DangerLevel.info,
          distanceMeters: 2.5,
        ),
      ],
    ),
    _TutorialScenario(
      title: 'Multiple Objects',
      prompt: 'Now there are multiple objects ahead: a person and a chair. '
          'Try saying "Describe the scene" to hear about everything around you.',
      expectedCommand: 'describeScene',
      simulatedDetections: [
        Detection(
          className: 'person',
          classId: 0,
          confidence: 0.95,
          boundingBox: BoundingBox(left: 256, top: 128, right: 384, bottom: 448),
          dangerLevel: DangerLevel.high,
          distanceMeters: 0.8,
        ),
        Detection(
          className: 'chair',
          classId: 56,
          confidence: 0.85,
          boundingBox: BoundingBox(left: 448, top: 320, right: 544, bottom: 448),
          dangerLevel: DangerLevel.medium,
          distanceMeters: 2.5,
        ),
      ],
    ),
    _TutorialScenario(
      title: 'Path Check',
      prompt: 'Great work! Now the path is clear — no obstacles detected. '
          'Try saying "Is the path clear" to check.',
      expectedCommand: 'pathClear',
      simulatedDetections: [],
    ),
    _TutorialScenario(
      title: 'Emergency',
      prompt: 'Last practice: In an emergency, say "Help" or "SOS". '
          'You can also say "I\'m okay" if you fall and the phone asks. '
          'For now, try saying "Battery status" to check your battery level.',
      expectedCommand: 'batteryStatus',
      simulatedDetections: [],
    ),
  ];
  
  /// Start the tutorial
  void startTutorial() {
    if (_isActive) return;
    
    _isActive = true;
    _currentScenario = 0;
    _practicedCommands.clear();
    notifyListeners();
    
    debugPrint('[Tutorial] Starting tutorial mode');
    _runCurrentScenario();
  }
  
  /// Stop the tutorial
  void stopTutorial() {
    _scenarioTimer?.cancel();
    _isActive = false;
    _currentScenario = 0;
    
    // Clear simulated detections
    onSimulateDetections?.call([]);
    
    onSpeak?.call('Tutorial stopped. You practiced ${_practicedCommands.length} '
        'out of ${_scenarios.length} commands. Say "start tutorial" anytime to try again.');
    
    notifyListeners();
    debugPrint('[Tutorial] Stopped');
  }
  
  /// Run the current scenario
  void _runCurrentScenario() {
    if (_currentScenario >= _scenarios.length) {
      _completeTutorial();
      return;
    }
    
    final scenario = _scenarios[_currentScenario];
    
    // Inject simulated detections
    onSimulateDetections?.call(scenario.simulatedDetections);
    
    // Speak the prompt
    onSpeak?.call(scenario.prompt);
    
    // Auto-advance after 20 seconds if user doesn't respond
    _scenarioTimer?.cancel();
    _scenarioTimer = Timer(const Duration(seconds: 20), () {
      onSpeak?.call('Let\'s move to the next practice. Say "next" anytime to skip ahead.');
      _advanceScenario();
    });
  }
  
  /// Called when the user executes a command during tutorial
  void onCommandExecuted(String commandName) {
    if (!_isActive) return;
    
    _practicedCommands.add(commandName);
    
    final scenario = _scenarios[_currentScenario];
    if (commandName == scenario.expectedCommand || 
        _practicedCommands.contains(scenario.expectedCommand)) {
      // Correct command! Advance
      _scenarioTimer?.cancel();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (_isActive) {
          _advanceScenario();
        }
      });
    }
  }
  
  /// Advance to the next scenario
  void _advanceScenario() {
    _currentScenario++;
    notifyListeners();
    
    if (_currentScenario >= _scenarios.length) {
      _completeTutorial();
    } else {
      _runCurrentScenario();
    }
  }
  
  /// Called when user says "next" during tutorial
  void skipToNext() {
    if (!_isActive) return;
    _scenarioTimer?.cancel();
    _advanceScenario();
  }
  
  /// Complete the tutorial
  void _completeTutorial() {
    _scenarioTimer?.cancel();
    _isActive = false;
    
    // Clear simulated detections
    onSimulateDetections?.call([]);
    
    final practiced = _practicedCommands.length;
    final total = _scenarios.length;
    
    onSpeak?.call(
      'Tutorial complete! You practiced $practiced out of $total commands. '
      'You\'re ready to use VisionMate. Tap Start or say "Start" to begin '
      'real detection. Remember, say "Help" anytime for emergencies.'
    );
    
    notifyListeners();
    onCompleted?.call();
    debugPrint('[Tutorial] Completed — practiced: $practiced/$total');
  }
  
  @override
  void dispose() {
    _scenarioTimer?.cancel();
    super.dispose();
  }
}

/// A tutorial practice scenario
class _TutorialScenario {
  final String title;
  final String prompt;
  final String expectedCommand;
  final List<Detection> simulatedDetections;
  
  const _TutorialScenario({
    required this.title,
    required this.prompt,
    required this.expectedCommand,
    required this.simulatedDetections,
  });
}
