import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show vmTeal, vmTealDark, vmBg, vmSurface, vmBorder, vmCard, vmDim;

import '../models/detection.dart';
import '../services/camera_service.dart';
import '../services/onnx_service.dart';
import '../services/tts_service.dart';
import '../services/haptic_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import '../services/emergency_service.dart';
import '../services/voice_command_service.dart';
import '../services/tracking_service.dart';
import '../services/navigation_guidance_service.dart';
import '../services/accessibility_activation_service.dart';
import '../services/ocr_service.dart';
import '../services/context_service.dart';
import '../services/currency_service.dart';
import '../services/learning_service.dart';
import '../services/feedback_service.dart';
import '../services/earcon_service.dart';
import '../services/wake_word_service.dart';
import '../services/conversation_flow_service.dart';
import '../services/depth_estimation_service.dart';
import '../services/scene_classification_service.dart';
import '../services/traffic_detection_service.dart';
import '../services/landmark_service.dart';
import '../services/path_memory_service.dart';
// Week 5: Safety & Emergency
import '../services/fall_detection_service.dart';
import '../services/collision_warning_service.dart';
import '../services/offline_mode_service.dart';
// Week 6: Accessibility & Onboarding
import '../services/onboarding_service.dart';
import '../services/tutorial_service.dart';
import '../services/personalization_wizard_service.dart';
// Week 8: Advanced features
import '../services/face_recognition_service.dart';
import '../services/indoor_navigation_service.dart';
import '../services/daily_summary_service.dart';
import '../core/risk_calculator.dart';
import '../widgets/detection_overlay.dart';
import 'package:battery_plus/battery_plus.dart';

/// Enhanced home screen with all 20 improvements:
/// - Large touch buttons (Feature 10)
/// - Screen reader support (Feature 12)
/// - Path clear guidance (Feature 7)
/// - Emergency SOS (Feature 17)
/// - Voice commands integration (Feature 11)
/// - Navigation mode filtering (Feature 18)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isDetecting = false;
  bool _isLoading = true;
  List<Detection> _detections = [];
  List<RiskAssessment> _risks = [];
  String _statusMessage = 'Initializing...';
  int _fps = 0;
  DateTime _lastFrameTime = DateTime.now();

  // Path clear timer (Feature 7)
  Timer? _pathClearTimer;
  DateTime _lastDetectionTime = DateTime.now();

  final RiskCalculator _riskCalculator = RiskCalculator();

  // Week 6: Track simplified/advanced UI mode
  bool _showAdvancedControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final cameraService = context.read<CameraService>();
    final onnxService = context.read<OnnxService>();
    final ttsService = context.read<TTSService>();
    final hapticService = context.read<HapticService>();
    final settingsService = context.read<SettingsService>();

    // === PHASE 1: Critical services (camera + detection ready ASAP) ===
    await settingsService.initialize();
    
    // Initialize camera and ONNX model in parallel for faster startup
    await Future.wait([
      cameraService.initialize(),
      onnxService.initialize(),
      ttsService.initialize(settings: settingsService),
      hapticService.initialize(),
      context.read<EarconService>().initialize(),
    ]);

    // Apply haptic setting
    hapticService.setEnabled(settingsService.vibrationEnabled);

    setState(() {
      _isLoading = false;
      if (onnxService.error != null) {
        _statusMessage = 'Model error: ${onnxService.error}';
      } else {
        _statusMessage = 'Ready. Tap Start to begin.';
      }
    });

    // Calm, reassuring startup message
    if (onnxService.isInitialized) {
      ttsService.speak('VisionMate ready. Shake phone, press volume up, or double tap to speak. I\'m here with you.');
    } else {
      ttsService.speak('Warning: Detection model failed to load.');
    }

    // === PHASE 2: Non-critical services (load in background, don't block UI) ===
    _initializeNonCriticalServices();
  }

  /// Initialize non-critical services without blocking the main UI
  Future<void> _initializeNonCriticalServices() async {
    final historyService = context.read<HistoryService>();
    final emergencyService = context.read<EmergencyService>();
    final voiceService = context.read<VoiceCommandService>();
    final settingsService = context.read<SettingsService>();

    // Initialize all non-critical services in parallel
    await Future.wait([
      historyService.initialize(),
      emergencyService.initialize(),
      voiceService.initialize(),
    ]);

    // Set up voice commands
    _setupVoiceCommands(voiceService);
    
    // Set up hands-free activation (shake, volume button, etc.)
    _setupAccessibilityActivation();

    // Set emergency contact from settings
    emergencyService.setEmergencyContact(settingsService.emergencyContact);
    
    // Week 3: Initialize wake word service
    final wakeWordService = context.read<WakeWordService>();
    await wakeWordService.initialize();
    wakeWordService.onWakeWordDetected = () {
      voiceService.startListening();
    };
    wakeWordService.onFeedback = (String message) {
      context.read<TTSService>().speakImmediately(message);
    };
    // Enable wake word if voice commands are enabled
    if (settingsService.voiceCommandsEnabled) {
      wakeWordService.setEnabled(true);
    }
    
    // Week 3: Initialize conversation flow
    final conversationFlow = context.read<ConversationFlowService>();
    conversationFlow.onFollowUpSpeak = (String message) {
      context.read<TTSService>().speakImmediately(message);
    };
    conversationFlow.onStartGuiding = () {
      _startDetection();
    };
    
    // Week 4: Initialize smarter detection services
    final depthService = context.read<DepthEstimationService>();
    await depthService.initialize();
    final pathMemory = context.read<PathMemoryService>();
    await pathMemory.initialize();
    
    // Week 5: Initialize fall detection, collision warning, and offline mode
    final fallDetection = context.read<FallDetectionService>();
    final offlineMode = context.read<OfflineModeService>();
    
    await Future.wait([
      fallDetection.initialize(),
      offlineMode.initialize(),
    ]);
    
    // Wire fall detection callbacks
    final ttsServiceRef = context.read<TTSService>();
    final hapticRef = context.read<HapticService>();
    
    fallDetection.onFallDetected = () {
      hapticRef.vibrateEmergency();
      ttsServiceRef.askAreYouOkay();
    };
    
    fallDetection.onCountdownTick = (int seconds) {
      ttsServiceRef.speakEmergency('SOS in $seconds seconds. Say I\'m okay to cancel.');
    };
    
    fallDetection.onAutoSOS = () async {
      ttsServiceRef.speakEmergency('No response. Sending emergency alert to all contacts.');
      await _triggerEmergency();
    };
    
    fallDetection.onFallCancelled = () {
      ttsServiceRef.confirmSafe();
    };
    
    fallDetection.onFeedback = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    
    // Wire offline mode connectivity announcements
    offlineMode.onConnectivityChanged = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    
    // Apply settings for Week 5 toggles
    fallDetection.setEnabled(settingsService.fallDetectionEnabled);
    context.read<CollisionWarningService>().setEnabled(settingsService.collisionWarningEnabled);
    
    // Week 6: Initialize onboarding, tutorial, and personalization wizard
    final onboarding = context.read<OnboardingService>();
    final tutorial = context.read<TutorialService>();
    final wizard = context.read<PersonalizationWizardService>();
    
    await onboarding.initialize();
    
    // Wire onboarding callbacks
    onboarding.onSpeak = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    onboarding.onCompleted = () {
      ttsServiceRef.speakImmediately('Onboarding complete. You\'re ready to go!');
    };
    onboarding.onStartPersonalization = () {
      wizard.startWizard();
    };
    
    // Wire tutorial callbacks
    tutorial.onSpeak = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    tutorial.onSimulateDetections = (List<Detection> detections) {
      if (mounted) {
        setState(() {
          _detections = detections;
        });
      }
    };
    tutorial.onCompleted = () {
      debugPrint('[Tutorial] Completed');
    };
    
    // Wire personalization wizard callbacks
    wizard.onSpeak = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    wizard.onApplySetting = (String setting, dynamic value) {
      switch (setting) {
        case 'speechRate':
          settingsService.setSpeechRate(value as double);
          break;
        case 'verbosity':
          final level = switch (value as String) {
            'minimal' => VerbosityLevel.minimal,
            'detailed' => VerbosityLevel.detailed,
            _ => VerbosityLevel.normal,
          };
          settingsService.setVerbosityLevel(level);
          break;
        case 'userMode':
          final mode = (value as String) == 'advanced'
              ? UserExperienceMode.advanced
              : UserExperienceMode.beginner;
          settingsService.setUserMode(mode);
          break;
      }
    };
    wizard.onCompleted = () {
      debugPrint('[Wizard] Personalization completed');
    };
    
    // Auto-trigger onboarding on first launch
    if (!onboarding.hasCompletedOnboarding) {
      // Small delay to let services settle
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          onboarding.startTour();
        }
      });
    }
    
    // Week 8: Initialize face recognition, indoor nav, daily summary
    final faceRecService = context.read<FaceRecognitionService>();
    final indoorNavService = context.read<IndoorNavigationService>();
    final dailySummaryService = context.read<DailySummaryService>();
    
    await Future.wait([
      faceRecService.initialize(),
      indoorNavService.initialize(),
      dailySummaryService.initialize(),
    ]);
    
    // Wire face recognition callbacks
    faceRecService.onSpeak = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    faceRecService.onFaceRecognized = (String name, String position) {
      debugPrint('[FaceRec] $name detected $position');
    };
    
    // Wire indoor navigation callbacks
    indoorNavService.onSpeak = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    
    // Wire daily summary callbacks
    dailySummaryService.onSpeak = (String message) {
      ttsServiceRef.speakImmediately(message);
    };
    
    debugPrint('[Startup] Non-critical services initialized (including Week 4, 5, 6 & 8)');
  }

  /// Set up hands-free voice activation for blind users
  void _setupAccessibilityActivation() {
    final activationService = context.read<AccessibilityActivationService>();
    final voiceService = context.read<VoiceCommandService>();
    final ttsService = context.read<TTSService>();
    final hapticService = context.read<HapticService>();
    
    // Initialize activation service
    activationService.initialize();
    
    // When activated, start voice recognition
    activationService.onActivate = () async {
      await hapticService.vibrateTap();
      await voiceService.startListening();
    };
    
    // Provide TTS feedback for activation
    activationService.onFeedback = (String message) {
      ttsService.speakImmediately(message);
    };
    
    // Fall detection: Ask "Are you okay?"
    activationService.onFallDetected = () {
      hapticService.vibrateEmergency();
      ttsService.askAreYouOkay();
    };
    
    // Fall confirmed (no response) - Trigger SOS
    activationService.onFallConfirmed = () async {
      ttsService.speakEmergency('No response detected. Sending emergency alert.');
      await _triggerEmergency();
    };
    
    // Fall cancelled (user is okay)
    activationService.onFallCancelled = () {
      ttsService.confirmSafe();
    };
  }

  void _setupVoiceCommands(VoiceCommandService voiceService) {
    final tts = context.read<TTSService>();
    final activationService = context.read<AccessibilityActivationService>();
    final conversationFlow = context.read<ConversationFlowService>();
    
    voiceService.onWhatsAhead = _announceCurrentDetections;
    voiceService.onStart = _startDetection;
    voiceService.onStop = _stopDetection;
    voiceService.onEmergency = _triggerEmergency;
    voiceService.onRepeat = () => tts.repeatLast();
    voiceService.onFaster = () => tts.increaseSpeed();
    voiceService.onSlower = () => tts.decreaseSpeed();
    voiceService.onLouder = () => tts.increaseVolume();
    voiceService.onQuieter = () => tts.decreaseVolume();
    voiceService.onSettings = () => Navigator.pushNamed(context, '/settings');
    
    // Find object command (Week 3: with conversational follow-up)
    voiceService.onFindObject = (String objectName) {
      _findObjectWithFollowUp(objectName);
    };
    
    // New: Path clear check
    voiceService.onPathClear = _announcePathStatus;
    
    // New: I'm okay response (for fall detection — Week 5 enhanced)
    voiceService.onImOkay = () {
      // Cancel both old and new fall detection
      activationService.confirmUserOkay();
      context.read<FallDetectionService>().confirmUserOkay();
    };
    
    // New: Read text command
    voiceService.onReadText = _readTextFromCamera;
    
    // New: Identify currency command
    voiceService.onIdentifyCurrency = _identifyCurrency;
    
    // New: Feedback for learning
    voiceService.onFeedbackPositive = () => _provideFeedback(true);
    voiceService.onFeedbackNegative = () => _provideFeedback(false);
    
    // New: Unknown command feedback
    voiceService.onUnknownCommand = (String words) {
      tts.speak("I didn't understand. Try 'what's ahead' or 'help'.");
    };
    
    // Week 2: Verbosity voice commands
    voiceService.onSetVerbosity = (String level) {
      final settings = context.read<SettingsService>();
      final VerbosityLevel verbosity;
      switch (level) {
        case 'minimal':
          verbosity = VerbosityLevel.minimal;
          break;
        case 'detailed':
          verbosity = VerbosityLevel.detailed;
          break;
        default:
          verbosity = VerbosityLevel.normal;
      }
      settings.setVerbosityLevel(verbosity);
      tts.speakImmediately('Switched to \${verbosity.displayName} mode.');
    };
    
    // === Week 3: Expanded vocabulary ===
    voiceService.onHowFar = (String objectName) => _howFarIsObject(objectName);
    voiceService.onIndoorsOrOutdoors = _announceEnvironment;
    voiceService.onDescribeScene = () => _describeSceneWithFollowUp();
    voiceService.onNavigateExit = _navigateToExit;
    voiceService.onBatteryStatus = _announceBatteryStatus;
    
    // === Week 3: Voice-based settings ===
    voiceService.onToggleHighContrast = (bool on) {
      final settings = context.read<SettingsService>();
      settings.setHighContrast(on);
      tts.speakImmediately(on ? 'High contrast mode on.' : 'High contrast mode off.');
    };
    
    voiceService.onSwitchLanguage = (String language) {
      final lang = AppLanguage.fromName(language);
      if (lang == null) {
        tts.speakImmediately(
          'Language "$language" not found. Available: English, Hindi, '
          'Bengali, Telugu, Marathi, Tamil, Gujarati, Kannada, '
          'Malayalam, Odia, Punjabi, Assamese.');
        return;
      }
      final settings = context.read<SettingsService>();
      settings.setLanguage(lang);
      tts.setLanguage(lang);
      voiceService.setListeningLocale(lang.localeCode);
      // Pause wake word briefly for language switch
      final wakeWord = context.read<WakeWordService>();
      wakeWord.pause();
      tts.speakImmediately(lang.switchConfirmation);
      // Resume wake word after TTS finishes
      Future.delayed(const Duration(seconds: 3), () => wakeWord.resume());
    };
    
    voiceService.onToggleVibration = (bool on) {
      final settings = context.read<SettingsService>();
      settings.setVibrationEnabled(on);
      context.read<HapticService>().setEnabled(on);
      tts.speakImmediately(on ? 'Vibration on.' : 'Vibration off.');
    };
    
    // === Week 3: Conversational yes/no ===
    voiceService.onYesNoResponse = (bool isYes) {
      if (conversationFlow.isActive) {
        conversationFlow.handleResponse(isYes);
      }
    };
    
    // === Week 4: Smarter detection commands ===
    voiceService.onWhatScene = () {
      final sceneService = context.read<SceneClassificationService>();
      tts.speakImmediately(sceneService.sceneDescription);
    };
    
    voiceService.onTrafficLight = () {
      final trafficService = context.read<TrafficDetectionService>();
      final state = trafficService.currentLightState;
      switch (state) {
        case TrafficLightState.red:
          tts.speakImmediately('Red light detected. Do not cross.');
          break;
        case TrafficLightState.green:
          tts.speakImmediately('Green light detected. May be safe to cross.');
          break;
        case TrafficLightState.yellow:
          tts.speakImmediately('Yellow light detected. Prepare to stop.');
          break;
        case TrafficLightState.unknown:
          tts.speakImmediately('No traffic light detected currently.');
          break;
      }
    };
    
    voiceService.onFindLandmark = (String type) {
      final landmarkService = context.read<LandmarkService>();
      final results = landmarkService.findByKeyword(type);
      if (results.isNotEmpty) {
        final desc = results.map((l) => l.description).join('. ');
        tts.speakImmediately(desc);
      } else {
        tts.speakImmediately('No $type detected nearby. Keep looking.');
      }
    };
    
    voiceService.onRememberPlace = () async {
      final pathMemory = context.read<PathMemoryService>();
      try {
        await pathMemory.recordLocation(_detections);
        tts.speakImmediately('Location remembered. I\'ll recognize this place next time.');
      } catch (e) {
        tts.speakImmediately('Could not save location. Check GPS permissions.');
      }
    };
    
    voiceService.onWhatsUsuallyHere = () async {
      final pathMemory = context.read<PathMemoryService>();
      final announcement = await pathMemory.getFamiliarRouteAnnouncement();
      if (announcement != null) {
        tts.speakImmediately(announcement);
      } else {
        tts.speakImmediately('I don\'t have memories for this location yet.');
      }
    };
    
    // === Week 5: Safety & Emergency voice commands ===
    voiceService.onAddContact = (String name, String phone) {
      final emergency = context.read<EmergencyService>();
      if (name.isEmpty || phone.isEmpty) {
        tts.speakImmediately('To add a contact, say: add contact, followed by name and phone number.');
        return;
      }
      emergency.addContact(name, phone).then((success) {
        if (success) {
          tts.speakImmediately('Added $name as emergency contact.');
        } else {
          tts.speakImmediately('Could not add contact. You may have reached the maximum of 5.');
        }
      });
    };
    
    voiceService.onRemoveContact = (String name) {
      final emergency = context.read<EmergencyService>();
      if (name.isEmpty) {
        tts.speakImmediately('Say remove contact followed by the contact name.');
        return;
      }
      emergency.removeContact(name).then((success) {
        if (success) {
          tts.speakImmediately('Removed $name from emergency contacts.');
        } else {
          tts.speakImmediately('Contact $name not found.');
        }
      });
    };
    
    voiceService.onListContacts = () {
      final emergency = context.read<EmergencyService>();
      tts.speakImmediately(emergency.listContactsDescription());
    };
    
    voiceService.onShareLocation = () {
      final emergency = context.read<EmergencyService>();
      if (!emergency.hasContacts) {
        tts.speakImmediately('No emergency contacts set. Add a contact first.');
        return;
      }
      if (emergency.isLiveSharing) {
        emergency.stopLiveLocationSharing();
        tts.speakImmediately('Live location sharing stopped.');
      } else {
        emergency.startLiveLocationSharing();
        tts.speakImmediately('Live location sharing started. Your contacts will receive updates every 30 seconds.');
      }
    };
    
    voiceService.onCancelSOS = () {
      context.read<FallDetectionService>().confirmUserOkay();
      activationService.confirmUserOkay();
      tts.speakImmediately('SOS cancelled.');
    };
    
    // Week 6: Onboarding, Tutorial, and Mode voice commands
    voiceService.onStartTutorial = () {
      context.read<TutorialService>().startTutorial();
    };
    
    voiceService.onSetupWizard = () {
      context.read<PersonalizationWizardService>().startWizard();
    };
    
    voiceService.onMoreOptions = () {
      if (mounted) {
        setState(() {
          _showAdvancedControls = true;
        });
        tts.speakImmediately('Showing all controls.');
      }
    };
    
    voiceService.onSetMode = (String mode) {
      final settingsRef = context.read<SettingsService>();
      if (mode == 'advanced') {
        settingsRef.setUserMode(UserExperienceMode.advanced);
        tts.speakImmediately('Advanced mode activated. Fewer announcements, faster responses.');
      } else {
        settingsRef.setUserMode(UserExperienceMode.beginner);
        if (mounted) setState(() { _showAdvancedControls = false; });
        tts.speakImmediately('Beginner mode activated. More guidance and reassurance.');
      }
    };
    
    // Handle onboarding/tutorial responses via yes/no
    final existingYesNoHandler = voiceService.onYesNoResponse;
    voiceService.onYesNoResponse = (bool isYes) {
      final onboardingRef = context.read<OnboardingService>();
      final wizardRef = context.read<PersonalizationWizardService>();
      
      if (onboardingRef.isActive) {
        if (isYes) {
          onboardingRef.nextStep();
        } else {
          onboardingRef.handleResponse(false);
        }
      } else if (wizardRef.isActive) {
        wizardRef.handleResponse(isYes ? 'yes' : 'no');
      } else {
        existingYesNoHandler?.call(isYes);
      }
    };
    
    // Handle "next" during onboarding/tutorial
    voiceService.onRepeat = () {
      final onboardingRef = context.read<OnboardingService>();
      final tutorialRef = context.read<TutorialService>();
      if (onboardingRef.isActive) {
        onboardingRef.nextStep();
      } else if (tutorialRef.isActive) {
        tutorialRef.skipToNext();
      } else {
        tts.speakImmediately('Repeating last update.');
        _announceCurrentDetections();
      }
    };
    
    // Track tutorial command practice
    voiceService.onAnyCommand = (VoiceCommand cmd, String raw) {
      final tutorialRef = context.read<TutorialService>();
      if (tutorialRef.isActive) {
        tutorialRef.onCommandExecuted(cmd.name);
      }
    };
    
    // Initialize learning services
    final learningService = context.read<LearningService>();
    final feedbackService = context.read<FeedbackService>();
    learningService.initialize();
    feedbackService.initialize();
    learningService.startSession();
    feedbackService.startSession();
    
    // Week 8: Face recognition voice commands
    voiceService.onRememberFace = (String name) async {
      if (name.isEmpty) {
        tts.speakImmediately('Please say "remember this face as" followed by the person\'s name.');
        return;
      }
      final faceRec = context.read<FaceRecognitionService>();
      final camera = context.read<CameraService>();
      if (camera.controller != null) {
        final image = await camera.captureInputImage();
        if (image != null) {
          await faceRec.saveFace(name, image);
        } else {
          tts.speakImmediately('Could not capture image. Please try again.');
        }
      }
    };
    
    voiceService.onForgetFace = (String name) {
      if (name.isEmpty) {
        tts.speakImmediately('Please say "forget" followed by the person\'s name.');
        return;
      }
      context.read<FaceRecognitionService>().forgetFace(name);
    };
    
    voiceService.onListFaces = () {
      context.read<FaceRecognitionService>().listFaces();
    };
    
    // Week 8: Indoor navigation voice commands
    voiceService.onWhereAmIIndoors = () {
      context.read<IndoorNavigationService>().whereAmI();
    };
    
    voiceService.onSaveLocation = (String name) {
      if (name.isEmpty) {
        tts.speakImmediately('Please say "save this location as" followed by the location name.');
        return;
      }
      context.read<IndoorNavigationService>().saveLocation(name);
    };
    
    // Week 8: Daily summary voice command
    voiceService.onDailySummary = () {
      context.read<DailySummaryService>().generateAndSpeak();
    };
    
    // Enable if setting is on
    final settings = context.read<SettingsService>();
    if (settings.voiceCommandsEnabled) {
      voiceService.setEnabled(true);
    }
  }
  
  /// Find a specific object in detections (Week 3: with conversational follow-up)
  void _findObjectWithFollowUp(String objectName) {
    final tts = context.read<TTSService>();
    final conversationFlow = context.read<ConversationFlowService>();
    final lower = objectName.toLowerCase();
    
    final found = _detections.where(
      (d) => d.className.toLowerCase().contains(lower)
    ).toList();
    
    if (found.isEmpty) {
      tts.speakImmediately('\$objectName not found. Try scanning around.');
    } else {
      final obj = found.first;
      final distance = obj.distanceDescription;
      final direction = obj.relativePosition?.description ?? 'ahead';
      
      // Week 3: Conversational follow-up
      final followUp = conversationFlow.buildFindObjectFollowUp(
        objectName: objectName,
        distance: distance,
        direction: direction,
      );
      conversationFlow.startFollowUp(
        type: ConversationType.findObject,
        message: followUp,
        contextData: objectName,
      );
    }
  }
  
  /// Week 3: How far is a specific object
  void _howFarIsObject(String objectName) {
    final tts = context.read<TTSService>();
    final lower = objectName.toLowerCase();
    
    final found = _detections.where(
      (d) => d.className.toLowerCase().contains(lower)
    ).toList();
    
    if (found.isEmpty) {
      tts.speakImmediately('\$objectName is not visible right now.');
    } else {
      final obj = found.first;
      tts.speakImmediately('\$objectName is \${obj.distanceDescription}, \${obj.relativePosition?.description ?? "ahead"}.');
    }
  }
  
  /// Week 3: Announce indoor/outdoor environment
  void _announceEnvironment() {
    final tts = context.read<TTSService>();
    final contextService = context.read<ContextService>();
    
    final env = contextService.environment;
    final envStr = env.name;
    tts.speakImmediately('You appear to be \$envStr.');
  }
  
  /// Week 3: Describe scene with conversational follow-up
  void _describeSceneWithFollowUp() {
    final tts = context.read<TTSService>();
    final conversationFlow = context.read<ConversationFlowService>();
    
    if (_detections.isEmpty) {
      tts.speakImmediately('No objects detected around you. The area seems clear.');
    } else {
      final descriptions = _detections.take(5).map((d) =>
        '\${d.className}, \${d.distanceDescription}, \${d.relativePosition?.description ?? "ahead"}'
      ).join('. ');
      tts.speakImmediately(descriptions);
      
      // Week 3: Follow-up
      final followUp = conversationFlow.buildDescribeSceneFollowUp(_detections.length);
      Future.delayed(const Duration(seconds: 3), () {
        conversationFlow.startFollowUp(
          type: ConversationType.describeScene,
          message: followUp,
        );
      });
    }
  }
  
  /// Week 3: Navigate to exit (find doors)
  void _navigateToExit() {
    final tts = context.read<TTSService>();
    final conversationFlow = context.read<ConversationFlowService>();
    
    final doors = _detections.where(
      (d) => d.className.toLowerCase().contains('door')
    ).toList();
    
    if (doors.isEmpty) {
      tts.speakImmediately('No exit or door visible. Try turning around slowly.');
    } else {
      final door = doors.first;
      final direction = door.relativePosition?.description ?? 'ahead';
      final distance = door.distanceDescription;
      
      final followUp = conversationFlow.buildNavigateExitFollowUp(
        exitFound: true,
        direction: direction,
        distance: distance,
      );
      conversationFlow.startFollowUp(
        type: ConversationType.navigateExit,
        message: followUp,
        contextData: 'door',
      );
    }
  }
  
  /// Week 3: Announce battery status
  Future<void> _announceBatteryStatus() async {
    final tts = context.read<TTSService>();
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      tts.speakImmediately('Battery is at \$level percent.');
    } catch (e) {
      debugPrint('[Battery] Error: \$e');
      tts.speakImmediately('Could not read battery level.');
    }
  }
  
  /// Announce if path is clear or blocked
  void _announcePathStatus() {
    final tts = context.read<TTSService>();
    if (_detections.isEmpty) {
      tts.speakImmediately('Path ahead is clear. You can go.');
    } else {
      final nearest = _detections.first;
      tts.speakImmediately('Path has obstacles. \${nearest.className} \${nearest.distanceDescription}.');
    }
  }
  
  /// Read text from camera using OCR
  Future<void> _readTextFromCamera() async {
    final tts = context.read<TTSService>();
    final ocrService = context.read<OcrService>();
    final cameraService = context.read<CameraService>();
    
    if (!ocrService.isInitialized) {
      await ocrService.initialize();
    }
    
    tts.speakImmediately('Scanning for text. Hold the phone steady.');
    
    // Capture current frame
    if (cameraService.controller == null) {
      tts.speakImmediately('Camera not available.');
      return;
    }
    
    try {
      // Take a picture and read text
      final image = await cameraService.controller!.takePicture();
      final text = await ocrService.recognizeFromFile(image.path);
      
      if (text.isEmpty) {
        tts.speakImmediately('No text found. Try moving the camera closer.');
      } else {
        // Format and read the text
        final formatted = ocrService.summarizeText(text);
        
        if (ocrService.isMedicineLabel(text)) {
          tts.speakImmediately('Medicine label detected. $formatted');
        } else {
          tts.speakImmediately(formatted);
        }
      }
    } catch (e) {
      debugPrint('[OCR] Error: $e');
      tts.speakImmediately('Could not read text. Please try again.');
    }
  }
  
  /// Identify Indian currency note
  Future<void> _identifyCurrency() async {
    final tts = context.read<TTSService>();
    final currencyService = context.read<CurrencyService>();
    final cameraService = context.read<CameraService>();
    
    if (!currencyService.isInitialized) {
      await currencyService.initialize();
    }
    
    tts.speakImmediately('Scanning currency note. Hold it steady.');
    
    if (cameraService.controller == null) {
      tts.speakImmediately('Camera not available.');
      return;
    }
    
    try {
      final image = await cameraService.controller!.takePicture();
      final result = await currencyService.identifyFromFile(image.path);
      
      final announcement = currencyService.getAnnouncement(result);
      tts.speakImmediately(announcement);
    } catch (e) {
      debugPrint('[Currency] Error: $e');
      tts.speakImmediately('Could not identify note. Please try again.');
    }
  }
  
  /// Provide feedback to learning system
  void _provideFeedback(bool isPositive) {
    final tts = context.read<TTSService>();
    final learningService = context.read<LearningService>();
    final feedbackService = context.read<FeedbackService>();
    
    // Get last announced object type if any
    String? lastObjectType;
    if (_detections.isNotEmpty) {
      lastObjectType = _detections.first.className;
    }
    
    // Update learning service
    learningService.provideFeedback(
      isPositive ? FeedbackType.positive : FeedbackType.negative,
      objectType: lastObjectType,
    );
    
    // Update feedback service
    feedbackService.recordImplicitFeedback(
      isPositive ? ImplicitFeedback.positive : ImplicitFeedback.tooMuch,
      context: lastObjectType,
    );
    
    // Acknowledge
    if (isPositive) {
      tts.speak('Thank you for the feedback. I\'ll remember that.');
    } else {
      tts.speak('Got it. I\'ll announce less often.');
    }
    
    debugPrint('[Learning] Feedback: positive=$isPositive, object=$lastObjectType');
  }

  void _announceCurrentDetections() {
    final tts = context.read<TTSService>();
    if (_detections.isEmpty) {
      tts.speakImmediately('Path ahead is clear.');
    } else {
      // Announce only top 2, in calm format
      final desc = _detections.take(2).map((d) => 
        '${d.className}, ${d.distanceDescription}'
      ).join('. ');
      tts.speakImmediately(desc);
    }
  }

  Future<void> _triggerEmergency() async {
    final emergency = context.read<EmergencyService>();
    final tts = context.read<TTSService>();
    final haptic = context.read<HapticService>();

    await haptic.vibrateEmergency();
    
    if (!emergency.hasContacts) {
      tts.speakEmergency('No emergency contacts set. Please add contacts in settings or say add emergency contact.');
      return;
    }
    
    tts.speakEmergency('Sending SOS to ${emergency.contactCount} emergency contacts.');
    
    final success = await emergency.triggerSOS();
    if (success) {
      tts.speakEmergency('SOS sent successfully. Help is on the way.');
    } else {
      tts.speakEmergency('Could not send emergency messages. Please try again.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopDetection();
    }
  }

  void _toggleDetection() {
    if (_isDetecting) {
      _stopDetection();
    } else {
      _startDetection();
    }
  }

  Future<void> _startDetection() async {
    final cameraService = context.read<CameraService>();
    final onnxService = context.read<OnnxService>();
    final ttsService = context.read<TTSService>();
    final trackingService = context.read<TrackingService>();
    final settings = context.read<SettingsService>();

    if (!cameraService.isInitialized) {
      ttsService.speak('Camera not available');
      return;
    }

    if (!onnxService.isInitialized) {
      ttsService.speak('Detection model not available');
      return;
    }

    // Clear tracking
    trackingService.clearTracks();

    setState(() {
      _isDetecting = true;
      _statusMessage = 'Detection active';
    });

    ttsService.speak('Detection started. Point camera forward.');

    // Start path clear timer (Feature 7)
    _startPathClearTimer(settings.pathClearInterval);

    // Start processing frames
    await cameraService.startImageStream(_processFrame);
  }

  void _startPathClearTimer(int intervalSeconds) {
    _pathClearTimer?.cancel();
    _pathClearTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      final timeSinceDetection = DateTime.now().difference(_lastDetectionTime);
      if (timeSinceDetection.inSeconds > 3 && _isDetecting) {
        // Week 2: Play earcon for path clear
        context.read<EarconService>().playPathClear();
        context.read<TTSService>().speakPathClear();
      }
    });
  }

  void _stopDetection() {
    final cameraService = context.read<CameraService>();
    final ttsService = context.read<TTSService>();
    final trackingService = context.read<TrackingService>();

    cameraService.stopImageStream();
    _pathClearTimer?.cancel();
    trackingService.clearTracks();

    setState(() {
      _isDetecting = false;
      _detections = [];
      _risks = [];
      _statusMessage = 'Detection stopped';
    });

    ttsService.speak('Detection stopped.');
  }

  /// Process a camera frame
  Future<void> _processFrame(CameraImage image) async {
    if (!_isDetecting) return;

    final onnxService = context.read<OnnxService>();
    final ttsService = context.read<TTSService>();
    final hapticService = context.read<HapticService>();
    final historyService = context.read<HistoryService>();
    final trackingService = context.read<TrackingService>();
    final cameraService = context.read<CameraService>();
    final settings = context.read<SettingsService>();

    try {
      // Calculate FPS
      final now = DateTime.now();
      final frameDuration = now.difference(_lastFrameTime);
      _lastFrameTime = now;
      if (frameDuration.inMilliseconds > 0) {
        _fps = (1000 / frameDuration.inMilliseconds).round();
      }

      // Run detection
      var detections = await onnxService.detectObjects(image);

      // Notify camera service for battery optimization
      cameraService.notifyDetectionResult(detections.length);

      // Sort by navigation mode priority (Feature 18)
      // Priority objects come first, but ALL objects are kept
      detections.sort((a, b) {
        final aPriority = settings.navigationMode.isRelevant(a.className) ? 0 : 1;
        final bPriority = settings.navigationMode.isRelevant(b.className) ? 0 : 1;
        return aPriority.compareTo(bPriority);
      });

      // Calculate risks
      final risks = _riskCalculator.calculateForAll(
        detections,
        frameWidth: image.width,
      );

      setState(() {
        _detections = detections;
        _risks = risks;
        _statusMessage = 'Detecting: ${detections.length} objects | ${onnxService.lastInferenceMs}ms | FPS: $_fps';
      });

      if (detections.isNotEmpty) {
        _lastDetectionTime = now;
        
        // Log to history (Feature 20)
        await historyService.logDetections(detections);

        // Use tracking to find NEW detections (Feature 3)
        final newDetections = trackingService.updateTrackers(detections);

        // Announce and vibrate for new detections (Week 2: with verbosity)
        final verbosity = settings.verbosityLevel;
        
        // Week 2: Group detections to reduce noise
        final grouped = trackingService.groupDetections(newDetections);

        for (final detection in grouped.take(2)) {
          // Haptic with proximity (Feature 9)
          if (settings.vibrationEnabled) {
            await hapticService.vibrateForDetection(detection);
          }

          // Week 2: Earcon for spatial audio cue
          final earconService = context.read<EarconService>();
          await earconService.playForDetection(detection);

          // TTS with priority and verbosity (Feature 4 + Week 2)
          await ttsService.speakDetectionWithVerbosity(detection, verbosity);
        }
        
        // Provide directional guidance (move left/right/back)
        final navGuidance = context.read<NavigationGuidanceService>();
        final guidance = navGuidance.analyzeAndGuide(
          detections,
          frameWidth: image.width,
          frameHeight: image.height,
        );
        
        // Announce guidance if urgent or medium+ and cooldown passed
        if (guidance.urgency != GuidanceUrgency.low && navGuidance.shouldAnnounce()) {
          final priority = guidance.urgency == GuidanceUrgency.urgent 
              ? SpeechPriority.interrupt 
              : SpeechPriority.high;
          await ttsService.speak(guidance.message, priority: priority);
        }
        
        // === Week 4: Smarter Detection ===
        
        // Scene classification
        final sceneService = context.read<SceneClassificationService>();
        sceneService.classifyScene(detections);
        
        // Traffic light analysis
        final trafficService = context.read<TrafficDetectionService>();
        final trafficLight = trafficService.findTrafficLight(detections);
        if (trafficLight != null) {
          trafficService.analyzeTrafficLight(trafficLight, image);
          final trafficMsg = trafficService.getTrafficAnnouncement();
          if (trafficMsg != null) {
            await ttsService.speak(trafficMsg, priority: SpeechPriority.interrupt);
          }
        }
        // Crosswalk detection
        trafficService.detectCrosswalk(image);
        final crosswalkMsg = trafficService.getCrosswalkAnnouncement();
        if (crosswalkMsg != null) {
          await ttsService.speak(crosswalkMsg, priority: SpeechPriority.high);
        }
        
        // Landmark analysis
        final landmarkService = context.read<LandmarkService>();
        landmarkService.analyzeLandmarks(
          detections,
          frameWidth: image.width,
          frameHeight: image.height,
        );
        final landmarkMsg = landmarkService.getTopLandmarkAnnouncement();
        if (landmarkMsg != null) {
          await ttsService.speak(landmarkMsg);
        }
        
        // Path memory: record location periodically
        final pathMemory = context.read<PathMemoryService>();
        pathMemory.recordLocation(detections);
        
        // === Week 5: Collision Warning ===
        final collisionService = context.read<CollisionWarningService>();
        if (settings.collisionWarningEnabled) {
          final warnings = collisionService.analyzeFrame(
            detections,
            frameWidth: image.width,
            frameHeight: image.height,
          );
          
          // Announce the most urgent collision warning
          if (warnings.isNotEmpty) {
            final topWarning = warnings.first;
            final priority = topWarning.urgency == CollisionUrgency.critical
                ? SpeechPriority.interrupt
                : SpeechPriority.high;
            await ttsService.speak(topWarning.message, priority: priority);
            
            // Haptic feedback for collision warnings
            if (settings.vibrationEnabled) {
              await hapticService.vibrateEmergency();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final cameraService = context.read<CameraService>();
    final ttsService = context.read<TTSService>();

    await cameraService.toggleFlash();
    ttsService.speak(cameraService.isFlashOn ? 'Flashlight on' : 'Flashlight off');
  }

  @override
  Widget build(BuildContext context) {
    final activationService = context.watch<AccessibilityActivationService>();

    return GestureDetector(
      onDoubleTap: () {
        activationService.onDoubleTap();
        _announceCurrentDetections();
      },
      onLongPress: () {
        activationService.onLongPress();
      },
      child: Scaffold(
        backgroundColor: vmBg,
        body: Column(
          children: [
            // ── Brand header bar ──────────────────────────────────────────
            _buildHeader(),

            // ── Camera preview (fills remaining space) ───────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _isLoading
                      ? _buildLoadingPlaceholder()
                      : _buildCameraPreview(),

                  // Floating obstacle banner (above control panel)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: _buildObstacleBanner(),
                  ),
                ],
              ),
            ),

            // ── Control panel ────────────────────────────────────────────
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  // ── Branded header ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final highestRisk = _risks.isNotEmpty ? _risks.first : null;

    return Semantics(
      liveRegion: true,
      label: _statusMessage,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16, right: 16, bottom: 12,
        ),
        decoration: BoxDecoration(
          color: vmSurface,
          border: const Border(
            bottom: BorderSide(color: vmBorder, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Logo icon
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: vmCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: vmBorder, width: 1),
              ),
              child: const Icon(Icons.remove_red_eye_outlined, color: vmTeal, size: 20),
            ),
            const SizedBox(width: 10),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VisionMate',
                    style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                    ),
                  ),
                  Text(
                    'AI Navigation',
                    style: GoogleFonts.inter(fontSize: 11, color: vmDim, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            // Status pill
            _buildStatusPill(highestRisk),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(RiskAssessment? highestRisk) {
    Color pillColor;
    String pillText;
    IconData pillIcon;

    if (_isLoading) {
      pillColor = Colors.grey;
      pillText  = 'LOADING';
      pillIcon  = Icons.hourglass_top_rounded;
    } else if (_isDetecting) {
      if (highestRisk != null && (highestRisk.level == RiskLevel.critical || highestRisk.level == RiskLevel.high)) {
        pillColor = const Color(0xFFFF4F4F);
        pillText  = highestRisk.level.name.toUpperCase();
        pillIcon  = Icons.warning_amber_rounded;
      } else {
        pillColor = vmTeal;
        pillText  = 'DETECTING';
        pillIcon  = Icons.radar;
      }
    } else {
      pillColor = Colors.grey.shade600;
      pillText  = 'PAUSED';
      pillIcon  = Icons.pause_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pillColor.withAlpha(30),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: pillColor.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pillIcon, size: 13, color: pillColor),
          const SizedBox(width: 5),
          Text(
            pillText,
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: pillColor, letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading placeholder ─────────────────────────────────────────────────────
  Widget _buildLoadingPlaceholder() {
    return Container(
      color: vmBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(color: vmTeal, strokeWidth: 2.5),
            ),
            const SizedBox(height: 20),
            Text(
              'Starting camera...',
              style: GoogleFonts.inter(fontSize: 14, color: vmDim),
            ),
          ],
        ),
      ),
    );
  }

  // ── Floating obstacle announcement banner ─────────────────────────────────
  Widget _buildObstacleBanner() {
    final highestRisk = _risks.isNotEmpty ? _risks.first : null;

    if (!_isDetecting || highestRisk == null) {
      // Path clear strip
      if (_isDetecting) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xCC0A1A26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00E57A).withAlpha(120), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF00E57A), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Path clear — no obstacles detected',
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: const Color(0xFF00E57A),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final color = _getRiskColor(highestRisk.level);
    final isUrgent = highestRisk.level == RiskLevel.critical || highestRisk.level == RiskLevel.high;
    final icon = isUrgent ? Icons.volume_up_rounded : Icons.info_outline_rounded;
    final prefix = isUrgent ? '⚠ OBSTACLE DETECTED:' : '🔊 Detected:';
    final message =
        '${highestRisk.detection.className}, ${highestRisk.detection.distanceDescription}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xDD0A1A26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(180), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(60),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prefix,
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: color, letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // _buildStatusBar() replaced by _buildHeader() and _buildObstacleBanner() above.

  Color _getRiskColor(RiskLevel? level) {
    return switch (level) {
      RiskLevel.critical => Colors.red.shade800,
      RiskLevel.high => Colors.orange.shade800,
      RiskLevel.medium => Colors.amber.shade800,
      RiskLevel.low => Colors.green.shade800,
      _ => Colors.grey.shade800,
    };
  }

  Widget _buildCameraPreview() {
    final cameraService = context.watch<CameraService>();

    if (!cameraService.isInitialized || cameraService.controller == null) {
      return Semantics(
        label: 'Camera not available',
        child: const Center(
          child: Text(
            'Camera not available',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: CameraPreview(cameraService.controller!),
          ),
        ),

        // Detection overlay with bounding boxes
        if (_detections.isNotEmpty)
          DetectionOverlay(
            detections: _detections,
            risks: _risks,
            previewSize: cameraService.controller!.value.previewSize!,
          ),
      ],
    );
  }

  Widget _buildControlPanel() {
    final settings = context.watch<SettingsService>();
    final isBeginner = settings.userMode == UserExperienceMode.beginner && !_showAdvancedControls;
    
    if (isBeginner) {
      return _buildSimplifiedControlPanel();
    }
    return _buildFullControlPanel();
  }

  /// Week 6: Simplified 3-button layout for beginner users
  Widget _buildSimplifiedControlPanel() {
    return _VmControlPanel(
      children: [
        // ── START / STOP ──────────────────────────────────────────────────
        Semantics(
          button: true,
          label: _isDetecting
              ? 'Stop detection. Double tap to stop.'
              : 'Start detection. Double tap to start.',
          hint: 'Main detection control',
          sortKey: const OrdinalSortKey(0),
          child: _VmPrimaryButton(
            label: _isDetecting ? 'STOP DETECTION' : 'START DETECTION',
            icon: _isDetecting ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
            active: _isDetecting,
            onPressed: _toggleDetection,
            height: 120,
          ),
        ),
        const SizedBox(height: 10),
        // ── SOS ───────────────────────────────────────────────────────────
        Semantics(
          button: true,
          label: 'Emergency SOS. Double tap to send distress signal.',
          hint: 'Emergency button',
          sortKey: const OrdinalSortKey(1),
          child: _VmSosButton(onPressed: _triggerEmergency),
        ),
        const SizedBox(height: 10),
        // ── SETTINGS + MORE row ───────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Open settings',
                sortKey: const OrdinalSortKey(2),
                child: _VmSecondaryButton(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Show more controls',
                hint: 'Reveals flash, voice, and other buttons',
                sortKey: const OrdinalSortKey(3),
                child: _VmSecondaryButton(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  onPressed: () {
                    setState(() { _showAdvancedControls = true; });
                    context.read<TTSService>().speakImmediately('Showing all controls.');
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Full control panel: compact icon row + main START/SOS row
  Widget _buildFullControlPanel() {
    return _VmControlPanel(
      children: [
        // ── Row 1: START + SOS ────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Semantics(
                button: true,
                label: _isDetecting ? 'Stop detection' : 'Start detection',
                hint: 'Main detection control',
                sortKey: const OrdinalSortKey(0),
                child: _VmPrimaryButton(
                  label: _isDetecting ? 'STOP' : 'START',
                  icon: _isDetecting
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline_rounded,
                  active: _isDetecting,
                  onPressed: _toggleDetection,
                  height: 100,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: Semantics(
                button: true,
                label: 'Emergency SOS',
                hint: 'Send distress signal to emergency contacts',
                sortKey: const OrdinalSortKey(1),
                child: _VmSosButton(onPressed: _triggerEmergency, height: 100),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Row 2: Icon tiles ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Toggle flashlight',
                sortKey: const OrdinalSortKey(2),
                child: _VmIconTile(
                  icon: Icons.flashlight_on_outlined,
                  label: 'Torch',
                  onPressed: _toggleFlash,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                label: 'What is ahead. Announces detected objects.',
                sortKey: const OrdinalSortKey(3),
                child: _VmIconTile(
                  icon: Icons.remove_red_eye_outlined,
                  label: 'Ahead?',
                  onPressed: _announceCurrentDetections,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Open settings',
                sortKey: const OrdinalSortKey(4),
                child: _VmIconTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Consumer<VoiceCommandService>(
                builder: (context, voiceService, _) => Semantics(
                  button: true,
                  label: 'Voice commands. Tap to start listening.',
                  sortKey: const OrdinalSortKey(5),
                  child: _VmIconTile(
                    icon: voiceService.isListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    label: voiceService.isListening ? 'Listening' : 'Voice',
                    active: voiceService.isListening,
                    onPressed: voiceService.isInitialized
                        ? () => voiceService.toggleListening()
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Simplify link for beginner mode
        if (_showAdvancedControls &&
            context.read<SettingsService>().userMode == UserExperienceMode.beginner)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() { _showAdvancedControls = false; }),
              child: Text(
                '← Simplify',
                style: GoogleFonts.inter(color: vmDim, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pathClearTimer?.cancel();
    super.dispose();
  }
}

// ── Shared VisionMate UI primitives ──────────────────────────────────────────

/// Dark glassmorphism control panel container
class _VmControlPanel extends StatelessWidget {
  final List<Widget> children;
  const _VmControlPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1A26),
        border: Border(top: BorderSide(color: Color(0x3D00E5CC), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Primary full-width START / STOP button
class _VmPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;          // true = detecting (teal glow)
  final VoidCallback onPressed;
  final double height;

  const _VmPrimaryButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onPressed,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    const teal        = Color(0xFF00E5CC);
    const activeColor = teal;
    const stopColor   = Color(0xFFFF4F4F);
    final btnColor    = active ? stopColor : activeColor;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: btnColor.withAlpha(active ? 90 : 60),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          label: Text(
            label,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: active ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

/// Red pulsing SOS button
class _VmSosButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double height;

  const _VmSosButton({
    required this.onPressed,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF4F4F);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: red.withAlpha(100),
              blurRadius: 20,
              spreadRadius: 3,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.emergency_rounded, size: 30),
          label: Text(
            'SOS',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B0000),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: red, width: 1.5),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

/// Secondary glassmorphism button (Settings / More)
class _VmSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _VmSecondaryButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0x0DFFFFFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0x3D00E5CC), width: 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: const Color(0xFF00E5CC)),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small icon tile for the advanced toolbar row
class _VmIconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  const _VmIconTile({
    required this.icon,
    required this.label,
    this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00E5CC);
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: active
              ? teal.withAlpha(40)
              : const Color(0x0DFFFFFF),
          foregroundColor: active ? teal : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: active ? teal.withAlpha(180) : const Color(0x3D00E5CC),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: active ? teal : Colors.white70),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: active ? teal : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

