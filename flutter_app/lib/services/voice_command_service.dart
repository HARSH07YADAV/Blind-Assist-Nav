import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Voice command types - Week 3: Expanded vocabulary + settings control
enum VoiceCommand {
  whatsAhead,       // "What's ahead", "What do you see"
  start,            // "Start", "Begin", "Go", "Guide me"
  stop,             // "Stop", "Pause", "Wait"
  emergency,        // "Help", "Help me", "Emergency", "SOS"
  repeat,           // "Repeat", "Again"
  faster,           // "Faster", "Speed up"
  slower,           // "Slower", "Slow down"
  louder,           // "Louder", "Volume up"
  quieter,          // "Quieter", "Volume down"
  settings,         // "Settings", "Options"
  findObject,       // "Find the door", "Where is the chair"
  readText,         // "Read this", "What does it say"
  identifyCurrency, // "What note is this", "Identify currency"
  pathClear,        // "Is the path clear"
  imOkay,           // "I'm okay", "I'm fine" (for fall)
  feedbackPositive, // "Thanks", "Helpful", "Good"
  feedbackNegative, // "Too much", "Enough", "Not helpful"
  setVerbosity,     // Week 2: "Less talk", "More detail", "Normal talk"
  // Week 3: Expanded vocabulary
  howFar,           // "How far is [object]?", "Distance to [object]"
  indoorsOrOutdoors,// "Am I indoors?", "Am I outdoors?", "Where am I?"
  describeScene,    // "Describe the scene", "What's around me?"
  navigateExit,     // "Navigate to exit", "Find the exit"
  batteryStatus,    // "Battery status", "How much battery?"
  // Week 3: Voice-based settings
  toggleHighContrast,// "High contrast on/off"
  switchLanguage,    // "Switch to Hindi", "Switch to English"
  toggleVibration,   // "Vibration on/off"
  // Week 3: Conversational yes/no
  yesResponse,       // "Yes", "Sure", "Go ahead"
  noResponse,        // "No", "Cancel", "Never mind"
  // Week 4: Smarter detection & navigation
  whatScene,          // "What scene is this?", "Where am I?"
  trafficLight,       // "Any traffic lights?", "Is it safe to cross?"
  findLandmark,       // "Find the stairs", "Find the elevator"
  rememberPlace,      // "Remember this place"
  whatsUsuallyHere,   // "What's usually here?"
  // Week 5: Safety & Emergency
  addEmergencyContact,  // "Add emergency contact"
  removeEmergencyContact, // "Remove contact"
  listEmergencyContacts,  // "List my contacts"
  shareLocation,       // "Share my location"
  cancelSOS,           // "Cancel SOS", "Cancel emergency"
  // Week 6: Accessibility & Onboarding
  startTutorial,       // "Start tutorial", "Practice mode"
  setupWizard,         // "Setup wizard", "Personalize"
  moreOptions,         // "More options", "Show all controls"
  setBeginnerMode,     // "Beginner mode"
  setAdvancedMode,     // "Advanced mode"
  // Week 8: Advanced features
  rememberFace,        // "Remember this face as [name]"
  forgetFace,          // "Forget [name]"
  listFaces,           // "List saved faces", "Who do I know?"
  whereAmIIndoors,     // "Where am I indoors?"
  saveLocation,        // "Save this location as [name]"
  dailySummary,        // "Daily summary", "Today's report"
  unknown,          // Unrecognized
}

/// Voice command service with natural language understanding
/// Week 3: Expanded vocabulary, Hindi support, voice settings
class VoiceCommandService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _enabled = true;
  String _lastCommand = '';
  String _lastWords = '';
  double _confidence = 0.0;
  String _listeningLocale = 'en-US';
  
  // Callbacks for commands
  Function? onWhatsAhead;
  Function? onStart;
  Function? onStop;
  Function? onEmergency;
  Function? onRepeat;
  Function? onFaster;
  Function? onSlower;
  Function? onLouder;
  Function? onQuieter;
  Function? onSettings;
  Function(String)? onFindObject;  // Pass the object name
  Function? onReadText;
  Function? onIdentifyCurrency;
  Function? onPathClear;
  Function? onImOkay;
  Function? onFeedbackPositive;  // User says "thanks", "helpful"
  Function? onFeedbackNegative;  // User says "too much", "enough"
  Function(VoiceCommand, String)? onAnyCommand;
  Function(String)? onUnknownCommand;  // For feedback on unrecognized
  Function(String)? onSetVerbosity;     // Week 2: "minimal", "normal", "detailed"
  // Week 3: Expanded vocabulary callbacks
  Function(String)? onHowFar;          // Pass object name
  Function? onIndoorsOrOutdoors;
  Function? onDescribeScene;
  Function? onNavigateExit;
  Function? onBatteryStatus;
  // Week 3: Voice-based settings callbacks
  Function(bool)? onToggleHighContrast;  // true = on, false = off
  Function(String)? onSwitchLanguage;    // "hindi" or "english"
  Function(bool)? onToggleVibration;     // true = on, false = off
  // Week 3: Conversational flow callbacks
  Function(bool)? onYesNoResponse;       // true = yes, false = no
  // Week 4: Smarter detection callbacks
  Function? onWhatScene;
  Function? onTrafficLight;
  Function(String)? onFindLandmark;       // Pass landmark type
  Function? onRememberPlace;
  Function? onWhatsUsuallyHere;
  // Week 5: Safety & Emergency callbacks
  Function(String name, String phone)? onAddContact;
  Function(String name)? onRemoveContact;
  Function? onListContacts;
  Function? onShareLocation;
  Function? onCancelSOS;
  // Week 6: Accessibility & Onboarding callbacks
  Function? onStartTutorial;
  Function? onSetupWizard;
  Function? onMoreOptions;
  Function(String mode)? onSetMode;  // 'beginner' or 'advanced'
  // Week 8: Advanced features callbacks
  Function(String name)? onRememberFace;  // Pass the name label
  Function(String name)? onForgetFace;
  Function? onListFaces;
  Function? onWhereAmIIndoors;
  Function(String name)? onSaveLocation;
  Function? onDailySummary;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get enabled => _enabled;
  String get lastCommand => _lastCommand;
  String get lastWords => _lastWords;
  double get confidence => _confidence;
  String get listeningLocale => _listeningLocale;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: kDebugMode,
      );
      
      if (_isInitialized) {
        debugPrint('[Voice] Speech recognition initialized');
      } else {
        debugPrint('[Voice] Speech recognition not available');
      }
      
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('[Voice] Initialization error: $e');
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
    } else if (status == 'notListening' || status == 'done') {
      _isListening = false;
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('[Voice] Error: ${error.errorMsg}');
    _isListening = false;
    notifyListeners();
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) stopListening();
    notifyListeners();
  }

  /// Week 3: Set the listening locale for multi-language support
  void setListeningLocale(String locale) {
    _listeningLocale = locale;
    debugPrint('[Voice] Listening locale set to: $locale');
    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_isInitialized || !_enabled || _isListening) return;

    try {
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 15), // Shorter for responsiveness
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
        localeId: _listeningLocale,
      );
      _isListening = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Voice] Error starting: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[Voice] Error stopping: $e');
    }
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    _confidence = result.confidence;
    
    if (result.finalResult && _lastWords.isNotEmpty) {
      final parsed = _parseCommand(_lastWords);
      _executeCommand(parsed.command, parsed.objectName, _lastWords);
    }
    
    notifyListeners();
  }

  /// Parse natural language command (English + Hindi)
  _ParsedCommand _parseCommand(String words) {
    final lower = words.toLowerCase().trim();
    
    // === EMERGENCY (highest priority) ===
    if (lower.contains("help me") || 
        lower == "help" ||
        lower.contains("emergency") ||
        lower.contains("sos") ||
        lower.contains("call for help") ||
        lower.contains("i need help") ||
        // Hindi emergency
        lower.contains("मदद") ||
        lower.contains("बचाओ") ||
        lower.contains("आपातकाल")) {
      return _ParsedCommand(VoiceCommand.emergency);
    }
    
    // === I'M OKAY (for fall detection response) ===
    if (lower.contains("i'm okay") || 
        lower.contains("i am okay") ||
        lower.contains("i'm fine") ||
        lower.contains("i am fine") ||
        lower.contains("i'm alright") ||
        lower.contains("no help") ||
        // Hindi
        lower.contains("मैं ठीक हूं") ||
        lower.contains("ठीक हूं")) {
      return _ParsedCommand(VoiceCommand.imOkay);
    }
    
    // === WEEK 3: YES/NO RESPONSES (for conversational flow) ===
    if (lower == "yes" ||
        lower == "yeah" ||
        lower == "sure" ||
        lower == "okay" ||
        lower == "go ahead" ||
        lower == "please" ||
        lower.contains("guide me") ||
        // Hindi yes
        lower == "हाँ" ||
        lower == "हां" ||
        lower == "ठीक है") {
      return _ParsedCommand(VoiceCommand.yesResponse);
    }
    if (lower == "no" ||
        lower == "nah" ||
        lower == "cancel" ||
        lower.contains("never mind") ||
        lower.contains("forget it") ||
        // Hindi no
        lower == "नहीं" ||
        lower.contains("रहने दो")) {
      return _ParsedCommand(VoiceCommand.noResponse);
    }
    
    // === WEEK 3: HOW FAR ===
    final howFarPatterns = [
      RegExp(r'how far is (?:the |a )?([\w\s]+)', caseSensitive: false),
      RegExp(r'distance to (?:the |a )?([\w\s]+)', caseSensitive: false),
      RegExp(r'how close is (?:the |a )?([\w\s]+)', caseSensitive: false),
      // Hindi: "[object] कितनी दूर है"
      RegExp(r'([\w\s]+)\s*कितनी दूर', caseSensitive: false),
    ];
    for (final pattern in howFarPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null && match.group(1) != null) {
        return _ParsedCommand(VoiceCommand.howFar, match.group(1)!.trim());
      }
    }
    
    // === WEEK 3: INDOORS OR OUTDOORS ===
    if (lower.contains("am i indoors") ||
        lower.contains("am i outdoors") ||
        lower.contains("am i inside") ||
        lower.contains("am i outside") ||
        lower.contains("where am i") ||
        lower.contains("indoor or outdoor") ||
        // Hindi
        lower.contains("मैं कहाँ हूं") ||
        lower.contains("अंदर हूं या बाहर")) {
      return _ParsedCommand(VoiceCommand.indoorsOrOutdoors);
    }
    
    // === WEEK 3: DESCRIBE SCENE ===
    if (lower.contains("describe the scene") ||
        lower.contains("describe scene") ||
        lower.contains("what's around me") ||
        lower.contains("what is around me") ||
        lower.contains("look around") ||
        lower.contains("tell me about surroundings") ||
        // Hindi
        lower.contains("आसपास क्या है") ||
        lower.contains("दृश्य बताओ")) {
      return _ParsedCommand(VoiceCommand.describeScene);
    }
    
    // === WEEK 3: NAVIGATE TO EXIT ===
    if (lower.contains("navigate to exit") ||
        lower.contains("find the exit") ||
        lower.contains("find exit") ||
        lower.contains("way out") ||
        lower.contains("find the door") ||
        lower.contains("where is the exit") ||
        // Hindi
        lower.contains("बाहर जाने का रास्ता") ||
        lower.contains("निकास कहाँ है")) {
      return _ParsedCommand(VoiceCommand.navigateExit);
    }
    
    // === WEEK 3: BATTERY STATUS ===
    if (lower.contains("battery status") ||
        lower.contains("how much battery") ||
        lower.contains("battery level") ||
        lower.contains("battery left") ||
        lower.contains("charge level") ||
        // Hindi
        lower.contains("बैटरी कितनी है") ||
        lower.contains("बैटरी स्तर")) {
      return _ParsedCommand(VoiceCommand.batteryStatus);
    }
    
    // === WEEK 3: VOICE-BASED SETTINGS ===
    // High contrast
    if (lower.contains("high contrast on") ||
        lower.contains("turn on high contrast") ||
        lower.contains("enable high contrast") ||
        lower.contains("हाई कंट्रास्ट चालू")) {
      return _ParsedCommand(VoiceCommand.toggleHighContrast, 'on');
    }
    if (lower.contains("high contrast off") ||
        lower.contains("turn off high contrast") ||
        lower.contains("disable high contrast") ||
        lower.contains("हाई कंट्रास्ट बंद")) {
      return _ParsedCommand(VoiceCommand.toggleHighContrast, 'off');
    }
    
    // Language switching — supports all Indian languages
    // "Switch to Bengali", "Speak in Tamil", "Hindi mode", etc.
    if (lower.contains("switch to ") ||
        lower.contains("speak in ") ||
        lower.contains("language ") ||
        lower.contains("भाषा बदलो") ||
        lower.contains("में बोलो")) {
      // Extract language name
      String? langName;
      for (final prefix in ['switch to ', 'speak in ', 'language ']) {
        if (lower.contains(prefix)) {
          final idx = lower.indexOf(prefix) + prefix.length;
          langName = words.substring(idx).trim().split(' ').first;
          break;
        }
      }
      // Also handle "[language] mode"
      if (langName == null && lower.contains(' mode')) {
        langName = lower.replaceAll(' mode', '').trim().split(' ').last;
      }
      // Handle Hindi voice commands for language names
      if (langName == null || langName.isEmpty) {
        // Try to match any language name in the input
        final allNames = [
          'english', 'hindi', 'bengali', 'bangla', 'telugu', 'marathi',
          'tamil', 'gujarati', 'kannada', 'malayalam', 'odia', 'oriya',
          'punjabi', 'assamese',
          'हिन्दी', 'बांग्ला', 'बंगाली', 'तेलुगु', 'मराठी', 'तमिल',
          'गुजराती', 'कन्नड़', 'मलयालम', 'ओडिया', 'पंजाबी', 'असमिया',
          'अंग्रेजी',
        ];
        for (final name in allNames) {
          if (lower.contains(name)) {
            langName = name;
            break;
          }
        }
      }
      if (langName != null && langName.isNotEmpty) {
        return _ParsedCommand(VoiceCommand.switchLanguage, langName);
      }
    }
    
    // Vibration toggle
    if (lower.contains("vibration on") ||
        lower.contains("turn on vibration") ||
        lower.contains("enable vibration") ||
        lower.contains("कंपन चालू")) {
      return _ParsedCommand(VoiceCommand.toggleVibration, 'on');
    }
    if (lower.contains("vibration off") ||
        lower.contains("turn off vibration") ||
        lower.contains("disable vibration") ||
        lower.contains("कंपन बंद")) {
      return _ParsedCommand(VoiceCommand.toggleVibration, 'off');
    }
    
    // === FIND OBJECT ===
    // "Find the door", "Where is the chair", "Locate the table"
    final findPatterns = [
      RegExp(r'find (?:the |a )?([\w\s]+)', caseSensitive: false),
      RegExp(r'where is (?:the |a )?([\w\s]+)', caseSensitive: false),
      RegExp(r'locate (?:the |a )?([\w\s]+)', caseSensitive: false),
      RegExp(r'look for (?:the |a )?([\w\s]+)', caseSensitive: false),
      // Hindi
      RegExp(r'([\w\s]+)\s*कहाँ है', caseSensitive: false),
      RegExp(r'([\w\s]+)\s*ढूंढो', caseSensitive: false),
    ];
    for (final pattern in findPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null && match.group(1) != null) {
        return _ParsedCommand(VoiceCommand.findObject, match.group(1)!.trim());
      }
    }
    
    // === WHAT'S AHEAD ===
    if (lower.contains("what's ahead") || 
        lower.contains("what is ahead") ||
        lower.contains("what do you see") ||
        lower.contains("what's in front") ||
        lower.contains("what is in front") ||
        lower.contains("scan") ||
        lower.contains("look ahead") ||
        // Hindi
        lower.contains("आगे क्या है") ||
        lower.contains("क्या दिख रहा है") ||
        lower.contains("सामने क्या है")) {
      return _ParsedCommand(VoiceCommand.whatsAhead);
    }
    
    // === PATH CLEAR ===
    if (lower.contains("is the path clear") ||
        lower.contains("path clear") ||
        lower.contains("is it safe") ||
        lower.contains("can i go") ||
        // Hindi
        lower.contains("रास्ता साफ है") ||
        lower.contains("जा सकता हूं")) {
      return _ParsedCommand(VoiceCommand.pathClear);
    }
    
    // === READ TEXT ===
    if (lower.contains("read this") ||
        lower.contains("read that") ||
        lower.contains("what does it say") ||
        lower.contains("read the text") ||
        lower.contains("read the sign") ||
        // Hindi
        lower.contains("पढ़ो") ||
        lower.contains("क्या लिखा है")) {
      return _ParsedCommand(VoiceCommand.readText);
    }
    
    // === IDENTIFY CURRENCY ===
    if (lower.contains("what note") ||
        lower.contains("identify money") ||
        lower.contains("identify currency") ||
        lower.contains("what rupee") ||
        lower.contains("currency") ||
        lower.contains("how much money") ||
        lower.contains("what denomination") ||
        // Hindi
        lower.contains("कितने का नोट") ||
        lower.contains("नोट पहचानो") ||
        lower.contains("पैसे")) {
      return _ParsedCommand(VoiceCommand.identifyCurrency);
    }
    
    // === STOP ===
    if (lower.contains("stop") || 
        lower.contains("pause") ||
        lower.contains("wait") ||
        lower.contains("be quiet") ||
        lower.contains("silence") ||
        lower.contains("shut up") || // Common expression
        // Hindi
        lower.contains("रुको") ||
        lower.contains("बंद करो") ||
        lower.contains("चुप")) {
      return _ParsedCommand(VoiceCommand.stop);
    }
    
    // === START ===
    if (lower.contains("start") || 
        lower.contains("begin") ||
        lower.contains("resume") ||
        lower.contains("continue") ||
        lower.contains("guide me") ||
        lower.contains("lead the way") ||
        // Hindi
        lower.contains("शुरू करो") ||
        lower.contains("चालू करो") ||
        lower.contains("आगे बढ़ो")) {
      return _ParsedCommand(VoiceCommand.start);
    }
    
    // === REPEAT ===
    if (lower.contains("repeat") || 
        lower.contains("again") ||
        lower.contains("say that again") ||
        lower.contains("what was that") ||
        lower.contains("pardon") ||
        lower.contains("come again") ||
        // Hindi
        lower.contains("दोहराओ") ||
        lower.contains("फिर से बोलो") ||
        lower.contains("क्या बोला")) {
      return _ParsedCommand(VoiceCommand.repeat);
    }
    
    // === SPEED ===
    if (lower.contains("faster") || lower.contains("speed up") || lower.contains("quicker") ||
        lower.contains("speak faster") ||
        // Hindi
        lower.contains("तेज बोलो") || lower.contains("जल्दी बोलो")) {
      return _ParsedCommand(VoiceCommand.faster);
    }
    if (lower.contains("slower") || lower.contains("slow down") ||
        lower.contains("speak slower") ||
        // Hindi
        lower.contains("धीरे बोलो") || lower.contains("आहिस्ता")) {
      return _ParsedCommand(VoiceCommand.slower);
    }
    
    // === VOLUME ===
    if (lower.contains("louder") || lower.contains("volume up") || lower.contains("speak up") ||
        // Hindi
        lower.contains("आवाज बढ़ाओ") || lower.contains("ज़ोर से")) {
      return _ParsedCommand(VoiceCommand.louder);
    }
    if (lower.contains("quieter") || lower.contains("volume down") || lower.contains("softer") ||
        // Hindi
        lower.contains("आवाज कम") || lower.contains("धीमा")) {
      return _ParsedCommand(VoiceCommand.quieter);
    }
    
    // === SETTINGS ===
    if (lower.contains("settings") || lower.contains("options") || lower.contains("preferences") ||
        // Hindi
        lower.contains("सेटिंग्स") || lower.contains("विकल्प")) {
      return _ParsedCommand(VoiceCommand.settings);
    }
    
    // === FEEDBACK POSITIVE ===
    if (lower.contains("thanks") ||
        lower.contains("thank you") ||
        lower.contains("helpful") ||
        lower.contains("good job") ||
        lower.contains("great") ||
        lower.contains("perfect") ||
        // Hindi
        lower.contains("धन्यवाद") ||
        lower.contains("शुक्रिया") ||
        lower.contains("अच्छा")) {
      return _ParsedCommand(VoiceCommand.feedbackPositive);
    }
    
    // === FEEDBACK NEGATIVE ===
    if (lower.contains("too much") ||
        lower.contains("enough") ||
        lower.contains("not helpful") ||
        lower.contains("annoying") ||
        // Hindi
        lower.contains("बहुत ज्यादा") ||
        lower.contains("बस करो")) {
      return _ParsedCommand(VoiceCommand.feedbackNegative);
    }
    
    // === WEEK 2: VERBOSITY ===
    if (lower.contains("less talk") ||
        lower.contains("less talking") ||
        lower.contains("beeps only") ||
        lower.contains("minimal") ||
        // Hindi
        lower.contains("कम बोलो")) {
      return _ParsedCommand(VoiceCommand.setVerbosity, 'minimal');
    }
    if (lower.contains("more detail") ||
        lower.contains("more details") ||
        lower.contains("tell me more") ||
        lower.contains("detailed") ||
        // Hindi
        lower.contains("ज़्यादा बताओ") ||
        lower.contains("विस्तार से")) {
      return _ParsedCommand(VoiceCommand.setVerbosity, 'detailed');
    }
    if (lower.contains("normal talk") ||
        lower.contains("normal mode") ||
        lower.contains("regular") ||
        // Hindi
        lower.contains("सामान्य")) {
      return _ParsedCommand(VoiceCommand.setVerbosity, 'normal');
    }
    
    // === WEEK 4: WHAT SCENE ===
    if (lower.contains("what scene") ||
        lower.contains("what kind of place") ||
        lower.contains("what room is this") ||
        lower.contains("identify the scene") ||
        lower.contains("what place is this") ||
        // Hindi
        lower.contains("यह कौन सी जगह है") ||
        lower.contains("कौन सा कमरा")) {
      return _ParsedCommand(VoiceCommand.whatScene);
    }
    
    // === WEEK 4: TRAFFIC LIGHT ===
    if (lower.contains("traffic light") ||
        lower.contains("any traffic lights") ||
        lower.contains("is it safe to cross") ||
        lower.contains("can i cross") ||
        lower.contains("signal") ||
        lower.contains("red or green") ||
        // Hindi
        lower.contains("ट्रैफिक लाइट") ||
        lower.contains("सिग्नल") ||
        lower.contains("पार कर सकता")) {
      return _ParsedCommand(VoiceCommand.trafficLight);
    }
    
    // === WEEK 4: FIND LANDMARK ===
    final landmarkPatterns = [
      RegExp(r'find (?:the |a )?(?:nearest )?(stairs|elevator|lift|door|sign|bench|bathroom|toilet)', caseSensitive: false),
      RegExp(r'where is (?:the |a )?(?:nearest )?(stairs|elevator|lift|door|sign|bench|bathroom|toilet)', caseSensitive: false),
      // Hindi
      RegExp(r'(सीढ़ी|लिफ्ट|दरवाज़ा|बाथरूम)\s*कहाँ', caseSensitive: false),
    ];
    for (final pattern in landmarkPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null && match.group(1) != null) {
        return _ParsedCommand(VoiceCommand.findLandmark, match.group(1)!.trim());
      }
    }
    
    // === WEEK 4: REMEMBER PLACE ===
    if (lower.contains("remember this place") ||
        lower.contains("save this location") ||
        lower.contains("mark this spot") ||
        // Hindi
        lower.contains("यह जगह याद रखो") ||
        lower.contains("जगह सेव करो")) {
      return _ParsedCommand(VoiceCommand.rememberPlace);
    }
    
    // === WEEK 4: WHAT'S USUALLY HERE ===
    if (lower.contains("what's usually here") ||
        lower.contains("what is usually here") ||
        lower.contains("what do you remember") ||
        lower.contains("familiar route") ||
        lower.contains("path memory") ||
        // Hindi
        lower.contains("यहाँ क्या होता है") ||
        lower.contains("यह रास्ता")) {
      return _ParsedCommand(VoiceCommand.whatsUsuallyHere);
    }
    
    // === WEEK 5: EMERGENCY CONTACT MANAGEMENT ===
    if (lower.contains("add emergency contact") ||
        lower.contains("add contact") ||
        lower.contains("new emergency contact") ||
        // Hindi
        lower.contains("संपर्क जोड़ो") ||
        lower.contains("आपातकालीन संपर्क")) {
      // Try to extract name and phone from the command
      final addPattern = RegExp(
        r'add (?:emergency )?contact\s+([\w]+)\s+([\d\+\-\s]+)',
        caseSensitive: false,
      );
      final match = addPattern.firstMatch(lower);
      if (match != null) {
        return _ParsedCommand(VoiceCommand.addEmergencyContact, 
            '${match.group(1)!.trim()}|${match.group(2)!.trim()}');
      }
      return _ParsedCommand(VoiceCommand.addEmergencyContact);
    }
    
    if (lower.contains("remove contact") ||
        lower.contains("delete contact") ||
        lower.contains("remove emergency contact") ||
        // Hindi
        lower.contains("संपर्क हटाओ")) {
      final removePattern = RegExp(
        r'(?:remove|delete) (?:emergency )?contact\s+([\w]+)',
        caseSensitive: false,
      );
      final match = removePattern.firstMatch(lower);
      if (match != null) {
        return _ParsedCommand(VoiceCommand.removeEmergencyContact, match.group(1)!.trim());
      }
      return _ParsedCommand(VoiceCommand.removeEmergencyContact);
    }
    
    if (lower.contains("list contacts") ||
        lower.contains("list my contacts") ||
        lower.contains("who are my contacts") ||
        lower.contains("emergency contacts") ||
        lower.contains("show contacts") ||
        // Hindi
        lower.contains("संपर्क सूची") ||
        lower.contains("संपर्क दिखाओ")) {
      return _ParsedCommand(VoiceCommand.listEmergencyContacts);
    }
    
    if (lower.contains("share my location") ||
        lower.contains("share location") ||
        lower.contains("send my location") ||
        lower.contains("live location") ||
        // Hindi
        lower.contains("मेरी लोकेशन भेजो") ||
        lower.contains("लोकेशन शेयर")) {
      return _ParsedCommand(VoiceCommand.shareLocation);
    }
    
    if (lower.contains("cancel sos") ||
        lower.contains("cancel emergency") ||
        lower.contains("stop sos") ||
        lower.contains("false alarm") ||
        // Hindi
        lower.contains("एसओएस रद्द") ||
        lower.contains("आपातकाल रद्द")) {
      return _ParsedCommand(VoiceCommand.cancelSOS);
    }
    
    // === WEEK 6: ONBOARDING & TUTORIAL ===
    if (lower.contains("start tutorial") ||
        lower.contains("tutorial mode") ||
        lower.contains("practice mode") ||
        lower.contains("practice") ||
        lower.contains("teach me") ||
        // Hindi
        lower.contains("ट्यूटोरियल शुरू") ||
        lower.contains("अभ्यास") ||
        lower.contains("सिखाओ")) {
      return _ParsedCommand(VoiceCommand.startTutorial);
    }
    
    if (lower.contains("setup wizard") ||
        lower.contains("personalize") ||
        lower.contains("set up my preferences") ||
        lower.contains("customize") ||
        // Hindi
        lower.contains("सेटअप") ||
        lower.contains("अनुकूलित")) {
      return _ParsedCommand(VoiceCommand.setupWizard);
    }
    
    if (lower.contains("more options") ||
        lower.contains("show all controls") ||
        lower.contains("advanced controls") ||
        lower.contains("all buttons") ||
        // Hindi
        lower.contains("और विकल्प") ||
        lower.contains("सभी बटन")) {
      return _ParsedCommand(VoiceCommand.moreOptions);
    }
    
    if (lower.contains("beginner mode") ||
        lower.contains("simple mode") ||
        lower.contains("easy mode") ||
        // Hindi
        lower.contains("शुरुआती मोड") ||
        lower.contains("आसान मोड")) {
      return _ParsedCommand(VoiceCommand.setBeginnerMode);
    }
    
    if (lower.contains("advanced mode") ||
        lower.contains("expert mode") ||
        lower.contains("pro mode") ||
        // Hindi
        lower.contains("उन्नत मोड") ||
        lower.contains("एडवांस मोड")) {
      return _ParsedCommand(VoiceCommand.setAdvancedMode);
    }
    
    // === WEEK 8: ADVANCED FEATURES ===
    if (lower.contains("remember this face") ||
        lower.contains("save this face") ||
        lower.contains("remember face") ||
        // Hindi
        lower.contains("यह चेहरा याद रखो") ||
        lower.contains("चेहरा सेव करो")) {
      // Extract name after "as" keyword
      String? name;
      final asIndex = lower.indexOf(' as ');
      if (asIndex >= 0) {
        name = words.substring(asIndex + 4).trim();
      }
      return _ParsedCommand(VoiceCommand.rememberFace, name);
    }
    
    if (lower.contains("forget face") ||
        lower.contains("remove face") ||
        lower.contains("delete face") ||
        // Hindi
        lower.contains("चेहरा भूल जाओ") ||
        lower.contains("चेहरा हटाओ")) {
      // Extract name after "forget" or specific keyword
      String? name;
      for (final kw in ['forget face ', 'forget ', 'remove face ', 'delete face ']) {
        if (lower.contains(kw)) {
          final idx = lower.indexOf(kw) + kw.length;
          name = words.substring(idx).trim();
          break;
        }
      }
      return _ParsedCommand(VoiceCommand.forgetFace, name);
    }
    
    if (lower.contains("list faces") ||
        lower.contains("saved faces") ||
        lower.contains("who do i know") ||
        lower.contains("list saved faces") ||
        // Hindi
        lower.contains("चेहरे दिखाओ") ||
        lower.contains("सेव किए चेहरे")) {
      return _ParsedCommand(VoiceCommand.listFaces);
    }
    
    if (lower.contains("where am i indoors") ||
        lower.contains("indoor location") ||
        lower.contains("indoor navigation") ||
        lower.contains("which room") ||
        // Hindi
        lower.contains("मैं अंदर कहाँ हूँ") ||
        lower.contains("कौन सा कमरा")) {
      return _ParsedCommand(VoiceCommand.whereAmIIndoors);
    }
    
    if (lower.contains("save this location") ||
        lower.contains("save location") ||
        lower.contains("remember this spot") ||
        // Hindi
        lower.contains("यह जगह सेव करो") ||
        lower.contains("लोकेशन सेव")) {
      String? name;
      final asIndex = lower.indexOf(' as ');
      if (asIndex >= 0) {
        name = words.substring(asIndex + 4).trim();
      }
      return _ParsedCommand(VoiceCommand.saveLocation, name);
    }
    
    if (lower.contains("daily summary") ||
        lower.contains("today's report") ||
        lower.contains("todays report") ||
        lower.contains("day summary") ||
        lower.contains("usage report") ||
        // Hindi
        lower.contains("दैनिक सारांश") ||
        lower.contains("आज की रिपोर्ट")) {
      return _ParsedCommand(VoiceCommand.dailySummary);
    }
    
    return _ParsedCommand(VoiceCommand.unknown);
  }

  void _executeCommand(VoiceCommand command, String? objectName, String rawWords) {
    _lastCommand = command.name;
    debugPrint('[Voice] Command: $command, Object: $objectName');
    
    switch (command) {
      case VoiceCommand.whatsAhead:
        onWhatsAhead?.call();
        break;
      case VoiceCommand.start:
        onStart?.call();
        break;
      case VoiceCommand.stop:
        onStop?.call();
        break;
      case VoiceCommand.emergency:
        onEmergency?.call();
        break;
      case VoiceCommand.repeat:
        onRepeat?.call();
        break;
      case VoiceCommand.faster:
        onFaster?.call();
        break;
      case VoiceCommand.slower:
        onSlower?.call();
        break;
      case VoiceCommand.louder:
        onLouder?.call();
        break;
      case VoiceCommand.quieter:
        onQuieter?.call();
        break;
      case VoiceCommand.settings:
        onSettings?.call();
        break;
      case VoiceCommand.findObject:
        if (objectName != null) {
          onFindObject?.call(objectName);
        }
        break;
      case VoiceCommand.readText:
        onReadText?.call();
        break;
      case VoiceCommand.identifyCurrency:
        onIdentifyCurrency?.call();
        break;
      case VoiceCommand.pathClear:
        onPathClear?.call();
        break;
      case VoiceCommand.imOkay:
        onImOkay?.call();
        break;
      case VoiceCommand.feedbackPositive:
        onFeedbackPositive?.call();
        break;
      case VoiceCommand.feedbackNegative:
        onFeedbackNegative?.call();
        break;
      case VoiceCommand.setVerbosity:
        if (objectName != null) {
          onSetVerbosity?.call(objectName);
        }
        break;
      // Week 3: Expanded vocabulary
      case VoiceCommand.howFar:
        if (objectName != null) {
          onHowFar?.call(objectName);
        }
        break;
      case VoiceCommand.indoorsOrOutdoors:
        onIndoorsOrOutdoors?.call();
        break;
      case VoiceCommand.describeScene:
        onDescribeScene?.call();
        break;
      case VoiceCommand.navigateExit:
        onNavigateExit?.call();
        break;
      case VoiceCommand.batteryStatus:
        onBatteryStatus?.call();
        break;
      // Week 3: Voice-based settings
      case VoiceCommand.toggleHighContrast:
        onToggleHighContrast?.call(objectName == 'on');
        break;
      case VoiceCommand.switchLanguage:
        if (objectName != null) {
          onSwitchLanguage?.call(objectName);
        }
        break;
      case VoiceCommand.toggleVibration:
        onToggleVibration?.call(objectName == 'on');
        break;
      // Week 3: Conversational yes/no
      case VoiceCommand.yesResponse:
        onYesNoResponse?.call(true);
        break;
      case VoiceCommand.noResponse:
        onYesNoResponse?.call(false);
        break;
      // Week 4: Smarter detection
      case VoiceCommand.whatScene:
        onWhatScene?.call();
        break;
      case VoiceCommand.trafficLight:
        onTrafficLight?.call();
        break;
      case VoiceCommand.findLandmark:
        if (objectName != null) {
          onFindLandmark?.call(objectName);
        }
        break;
      case VoiceCommand.rememberPlace:
        onRememberPlace?.call();
        break;
      case VoiceCommand.whatsUsuallyHere:
        onWhatsUsuallyHere?.call();
        break;
      // Week 5: Safety & Emergency
      case VoiceCommand.addEmergencyContact:
        if (objectName != null && objectName.contains('|')) {
          final parts = objectName.split('|');
          onAddContact?.call(parts[0], parts[1]);
        } else {
          onAddContact?.call('', '');
        }
        break;
      case VoiceCommand.removeEmergencyContact:
        onRemoveContact?.call(objectName ?? '');
        break;
      case VoiceCommand.listEmergencyContacts:
        onListContacts?.call();
        break;
      case VoiceCommand.shareLocation:
        onShareLocation?.call();
        break;
      case VoiceCommand.cancelSOS:
        onCancelSOS?.call();
        break;
      // Week 6: Accessibility & Onboarding
      case VoiceCommand.startTutorial:
        onStartTutorial?.call();
        break;
      case VoiceCommand.setupWizard:
        onSetupWizard?.call();
        break;
      case VoiceCommand.moreOptions:
        onMoreOptions?.call();
        break;
      case VoiceCommand.setBeginnerMode:
        onSetMode?.call('beginner');
        break;
      case VoiceCommand.setAdvancedMode:
        onSetMode?.call('advanced');
        break;
      // Week 8: Advanced features
      case VoiceCommand.rememberFace:
        onRememberFace?.call(objectName ?? '');
        break;
      case VoiceCommand.forgetFace:
        onForgetFace?.call(objectName ?? '');
        break;
      case VoiceCommand.listFaces:
        onListFaces?.call();
        break;
      case VoiceCommand.whereAmIIndoors:
        onWhereAmIIndoors?.call();
        break;
      case VoiceCommand.saveLocation:
        onSaveLocation?.call(objectName ?? '');
        break;
      case VoiceCommand.dailySummary:
        onDailySummary?.call();
        break;
      case VoiceCommand.unknown:
        onUnknownCommand?.call(rawWords);
        break;
    }
    
    onAnyCommand?.call(command, rawWords);
    notifyListeners();
  }

  Future<bool> checkAvailability() async {
    if (!_isInitialized) {
      return await initialize();
    }
    return _isInitialized;
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }
}

/// Parsed command with optional object name
class _ParsedCommand {
  final VoiceCommand command;
  final String? objectName;
  
  _ParsedCommand(this.command, [this.objectName]);
}
