import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings service for persistent user preferences
/// 
/// Features:
/// - Speech rate and volume
/// - Navigation mode (indoor/outdoor)
/// - User experience mode (beginner/advanced)
/// - Auto-adjust sensitivity
/// - Usage tracking for personalization
class SettingsService extends ChangeNotifier {
  static const String _keySpeechRate = 'speech_rate';
  static const String _keySpeechVolume = 'speech_volume';
  static const String _keyNavigationMode = 'navigation_mode';
  static const String _keyHighContrast = 'high_contrast';
  static const String _keyPathClearInterval = 'path_clear_interval';
  static const String _keyEmergencyContact = 'emergency_contact';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyVoiceCommandsEnabled = 'voice_commands_enabled';
  static const String _keyUserMode = 'user_mode';
  static const String _keyAutoAdjust = 'auto_adjust';
  static const String _keyUsageCount = 'usage_count';
  static const String _keyDetectionSensitivity = 'detection_sensitivity';
  static const String _keyAnnouncementFrequency = 'announcement_frequency';
  static const String _keyVerbosityLevel = 'verbosity_level';
  static const String _keyLanguage = 'app_language';
  // Week 5: Safety & Emergency
  static const String _keyEmergencyContactsList = 'emergency_contacts_list';
  static const String _keyLiveLocationEnabled = 'live_location_enabled';
  static const String _keyCollisionWarningEnabled = 'collision_warning_enabled';
  static const String _keyFallDetectionEnabled = 'fall_detection_enabled';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Default values
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  AppNavigationMode _navigationMode = AppNavigationMode.indoor;
  bool _highContrast = false;
  int _pathClearInterval = 5;
  String _emergencyContact = '';
  bool _vibrationEnabled = true;
  bool _voiceCommandsEnabled = false;
  
  // Personalization (Phase 7)
  UserExperienceMode _userMode = UserExperienceMode.beginner;
  bool _autoAdjust = true;
  int _usageCount = 0;
  double _detectionSensitivity = 0.5; // 0.0-1.0
  double _announcementFrequency = 1.0; // 0.5-2.0x
  VerbosityLevel _verbosityLevel = VerbosityLevel.normal;
  AppLanguage _language = AppLanguage.english;
  // Week 5
  List<String> _emergencyContactsJson = [];
  bool _liveLocationEnabled = false;
  bool _collisionWarningEnabled = true;
  bool _fallDetectionEnabled = true;

  // Getters
  bool get isInitialized => _isInitialized;
  double get speechRate => _speechRate;
  double get speechVolume => _speechVolume;
  AppNavigationMode get navigationMode => _navigationMode;
  bool get highContrast => _highContrast;
  int get pathClearInterval => _pathClearInterval;
  String get emergencyContact => _emergencyContact;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get voiceCommandsEnabled => _voiceCommandsEnabled;
  UserExperienceMode get userMode => _userMode;
  bool get autoAdjust => _autoAdjust;
  int get usageCount => _usageCount;
  double get detectionSensitivity => _detectionSensitivity;
  double get announcementFrequency => _announcementFrequency;
  VerbosityLevel get verbosityLevel => _verbosityLevel;
  AppLanguage get language => _language;
  // Week 5
  List<String> get emergencyContactsJson => _emergencyContactsJson;
  bool get liveLocationEnabled => _liveLocationEnabled;
  bool get collisionWarningEnabled => _collisionWarningEnabled;
  bool get fallDetectionEnabled => _fallDetectionEnabled;

  /// Initialize and load saved preferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      
      _speechRate = _prefs!.getDouble(_keySpeechRate) ?? 0.5;
      _speechVolume = _prefs!.getDouble(_keySpeechVolume) ?? 1.0;
      _navigationMode = AppNavigationMode.values[_prefs!.getInt(_keyNavigationMode) ?? 0];
      _highContrast = _prefs!.getBool(_keyHighContrast) ?? false;
      _pathClearInterval = _prefs!.getInt(_keyPathClearInterval) ?? 5;
      _emergencyContact = _prefs!.getString(_keyEmergencyContact) ?? '';
      _vibrationEnabled = _prefs!.getBool(_keyVibrationEnabled) ?? true;
      _voiceCommandsEnabled = _prefs!.getBool(_keyVoiceCommandsEnabled) ?? false;
      
      // Load personalization settings
      _userMode = UserExperienceMode.values[_prefs!.getInt(_keyUserMode) ?? 0];
      _autoAdjust = _prefs!.getBool(_keyAutoAdjust) ?? true;
      _usageCount = _prefs!.getInt(_keyUsageCount) ?? 0;
      _detectionSensitivity = _prefs!.getDouble(_keyDetectionSensitivity) ?? 0.5;
      _announcementFrequency = _prefs!.getDouble(_keyAnnouncementFrequency) ?? 1.0;
      _verbosityLevel = VerbosityLevel.values[_prefs!.getInt(_keyVerbosityLevel) ?? 1]; // default: normal
      _language = AppLanguage.values[_prefs!.getInt(_keyLanguage) ?? 0]; // default: english
      
      // Week 5 settings
      final contactsStr = _prefs!.getString(_keyEmergencyContactsList);
      if (contactsStr != null && contactsStr.isNotEmpty) {
        _emergencyContactsJson = List<String>.from(json.decode(contactsStr));
      }
      _liveLocationEnabled = _prefs!.getBool(_keyLiveLocationEnabled) ?? false;
      _collisionWarningEnabled = _prefs!.getBool(_keyCollisionWarningEnabled) ?? true;
      _fallDetectionEnabled = _prefs!.getBool(_keyFallDetectionEnabled) ?? true;
      
      // Auto-upgrade to advanced mode after 50 uses
      if (_autoAdjust && _usageCount > 50 && _userMode == UserExperienceMode.beginner) {
        _userMode = UserExperienceMode.advanced;
        await _prefs!.setInt(_keyUserMode, _userMode.index);
      }
      
      _isInitialized = true;
      debugPrint('[Settings] Loaded - Mode: $_userMode, Uses: $_usageCount');
      notifyListeners();
    } catch (e) {
      debugPrint('[Settings] Error loading: $e');
    }
  }

  /// Track app usage (call on each session start)
  Future<void> trackUsage() async {
    _usageCount++;
    await _prefs?.setInt(_keyUsageCount, _usageCount);
    
    // Auto-adjust based on usage
    if (_autoAdjust) {
      _autoAdjustSettings();
    }
    
    notifyListeners();
  }

  /// Auto-adjust settings based on usage patterns
  void _autoAdjustSettings() {
    // After 10 uses, reduce announcement frequency slightly
    if (_usageCount >= 10 && _announcementFrequency > 0.8) {
      _announcementFrequency = 0.8;
      _prefs?.setDouble(_keyAnnouncementFrequency, _announcementFrequency);
    }
    
    // After 30 uses, user is more experienced
    if (_usageCount >= 30) {
      _speechRate = (_speechRate + 0.6) / 2; // Slightly faster
    }
    
    // After 50 uses, switch to advanced mode
    if (_usageCount >= 50 && _userMode == UserExperienceMode.beginner) {
      _userMode = UserExperienceMode.advanced;
      _prefs?.setInt(_keyUserMode, _userMode.index);
    }
  }

  /// Set user experience mode
  Future<void> setUserMode(UserExperienceMode mode) async {
    _userMode = mode;
    await _prefs?.setInt(_keyUserMode, mode.index);
    
    // Apply mode defaults
    if (mode == UserExperienceMode.beginner) {
      _speechRate = 0.4; // Slower speech
      _announcementFrequency = 1.2; // More announcements
      _pathClearInterval = 3; // Frequent reassurance
    } else {
      _speechRate = 0.6; // Faster speech
      _announcementFrequency = 0.7; // Less announcements
      _pathClearInterval = 8; // Less frequent
    }
    
    await _prefs?.setDouble(_keySpeechRate, _speechRate);
    await _prefs?.setDouble(_keyAnnouncementFrequency, _announcementFrequency);
    await _prefs?.setInt(_keyPathClearInterval, _pathClearInterval);
    
    notifyListeners();
  }

  /// Set auto-adjust enabled
  Future<void> setAutoAdjust(bool enabled) async {
    _autoAdjust = enabled;
    await _prefs?.setBool(_keyAutoAdjust, enabled);
    notifyListeners();
  }

  /// Set detection sensitivity (0.0-1.0)
  Future<void> setDetectionSensitivity(double sensitivity) async {
    _detectionSensitivity = sensitivity.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keyDetectionSensitivity, _detectionSensitivity);
    notifyListeners();
  }

  /// Set announcement frequency multiplier
  Future<void> setAnnouncementFrequency(double frequency) async {
    _announcementFrequency = frequency.clamp(0.5, 2.0);
    await _prefs?.setDouble(_keyAnnouncementFrequency, _announcementFrequency);
    notifyListeners();
  }

  /// Week 2: Set verbosity level
  Future<void> setVerbosityLevel(VerbosityLevel level) async {
    _verbosityLevel = level;
    await _prefs?.setInt(_keyVerbosityLevel, level.index);
    debugPrint('[Settings] Verbosity set to: ${level.name}');
    notifyListeners();
  }

  /// Week 3: Set app language
  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _prefs?.setInt(_keyLanguage, language.index);
    debugPrint('[Settings] Language set to: ${language.name}');
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    await _prefs?.setDouble(_keySpeechRate, _speechRate);
    notifyListeners();
  }

  Future<void> setSpeechVolume(double volume) async {
    _speechVolume = volume.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keySpeechVolume, _speechVolume);
    notifyListeners();
  }

  Future<void> setNavigationMode(AppNavigationMode mode) async {
    _navigationMode = mode;
    await _prefs?.setInt(_keyNavigationMode, mode.index);
    notifyListeners();
  }

  Future<void> setHighContrast(bool enabled) async {
    _highContrast = enabled;
    await _prefs?.setBool(_keyHighContrast, enabled);
    notifyListeners();
  }

  Future<void> setPathClearInterval(int seconds) async {
    _pathClearInterval = seconds.clamp(3, 30);
    await _prefs?.setInt(_keyPathClearInterval, _pathClearInterval);
    notifyListeners();
  }

  Future<void> setEmergencyContact(String contact) async {
    _emergencyContact = contact;
    await _prefs?.setString(_keyEmergencyContact, contact);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _prefs?.setBool(_keyVibrationEnabled, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCommandsEnabled(bool enabled) async {
    _voiceCommandsEnabled = enabled;
    await _prefs?.setBool(_keyVoiceCommandsEnabled, enabled);
    notifyListeners();
  }

  // ==================== Week 5: Safety Settings ====================

  Future<void> setEmergencyContactsList(List<String> contactsJson) async {
    _emergencyContactsJson = contactsJson;
    await _prefs?.setString(_keyEmergencyContactsList, json.encode(contactsJson));
    notifyListeners();
  }

  Future<void> setLiveLocationEnabled(bool enabled) async {
    _liveLocationEnabled = enabled;
    await _prefs?.setBool(_keyLiveLocationEnabled, enabled);
    notifyListeners();
  }

  Future<void> setCollisionWarningEnabled(bool enabled) async {
    _collisionWarningEnabled = enabled;
    await _prefs?.setBool(_keyCollisionWarningEnabled, enabled);
    notifyListeners();
  }

  Future<void> setFallDetectionEnabled(bool enabled) async {
    _fallDetectionEnabled = enabled;
    await _prefs?.setBool(_keyFallDetectionEnabled, enabled);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await setSpeechRate(0.5);
    await setSpeechVolume(1.0);
    await setNavigationMode(AppNavigationMode.indoor);
    await setHighContrast(false);
    await setPathClearInterval(5);
    await setVibrationEnabled(true);
    await setVoiceCommandsEnabled(false);
    await setUserMode(UserExperienceMode.beginner);
    await setAutoAdjust(true);
    await setDetectionSensitivity(0.5);
    await setAnnouncementFrequency(1.0);
    await setVerbosityLevel(VerbosityLevel.normal);
    await setLanguage(AppLanguage.english);
    await setLiveLocationEnabled(false);
    await setCollisionWarningEnabled(true);
    await setFallDetectionEnabled(true);
  }
}

/// User experience mode
enum UserExperienceMode {
  beginner,  // More guidance, slower speech, frequent announcements
  advanced;  // Minimal alerts, faster speech, key obstacles only

  String get displayName {
    switch (this) {
      case UserExperienceMode.beginner:
        return 'Beginner (More Guidance)';
      case UserExperienceMode.advanced:
        return 'Advanced (Minimal Alerts)';
    }
  }

  String get description {
    switch (this) {
      case UserExperienceMode.beginner:
        return 'Slower speech, frequent updates, more reassurance';
      case UserExperienceMode.advanced:
        return 'Faster speech, only critical alerts, less interruption';
    }
  }
}

/// Navigation mode for filtering detections
enum AppNavigationMode {
  indoor,
  outdoor;

  String get displayName {
    switch (this) {
      case AppNavigationMode.indoor:
        return 'Indoor';
      case AppNavigationMode.outdoor:
        return 'Outdoor';
    }
  }

  List<String> get priorityClasses {
    switch (this) {
      case AppNavigationMode.indoor:
        return [
          'person', 'chair', 'couch', 'dining table', 'bed', 
          'door', 'tv', 'laptop', 'potted plant', 'bottle',
          'cup', 'book', 'clock', 'vase'
        ];
      case AppNavigationMode.outdoor:
        return [
          'person', 'car', 'motorcycle', 'bicycle', 'bus', 
          'truck', 'traffic light', 'stop sign', 'fire hydrant',
          'dog', 'cat', 'bench'
        ];
    }
  }

  bool isRelevant(String className) {
    return priorityClasses.contains(className.toLowerCase());
  }
}

/// Week 2: Verbosity levels for announcements
enum VerbosityLevel {
  minimal,   // Earcons/beeps only, no TTS for detections
  normal,    // Brief phrases (default)
  detailed;  // Full sentences with confidence + direction

  String get displayName {
    switch (this) {
      case VerbosityLevel.minimal:
        return 'Minimal (Beeps Only)';
      case VerbosityLevel.normal:
        return 'Normal';
      case VerbosityLevel.detailed:
        return 'Detailed';
    }
  }

  String get description {
    switch (this) {
      case VerbosityLevel.minimal:
        return 'Sound effects only, less talking';
      case VerbosityLevel.normal:
        return 'Brief spoken phrases';
      case VerbosityLevel.detailed:
        return 'Full sentences with confidence';
    }
  }
}

/// Week 3 + Week 8: App language — all major Indian languages
enum AppLanguage {
  english,
  hindi,
  bengali,
  telugu,
  marathi,
  tamil,
  gujarati,
  kannada,
  malayalam,
  odia,
  punjabi,
  assamese;

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.hindi:
        return 'हिन्दी (Hindi)';
      case AppLanguage.bengali:
        return 'বাংলা (Bengali)';
      case AppLanguage.telugu:
        return 'తెలుగు (Telugu)';
      case AppLanguage.marathi:
        return 'मराठी (Marathi)';
      case AppLanguage.tamil:
        return 'தமிழ் (Tamil)';
      case AppLanguage.gujarati:
        return 'ગુજરાતી (Gujarati)';
      case AppLanguage.kannada:
        return 'ಕನ್ನಡ (Kannada)';
      case AppLanguage.malayalam:
        return 'മലയാളം (Malayalam)';
      case AppLanguage.odia:
        return 'ଓଡ଼ିଆ (Odia)';
      case AppLanguage.punjabi:
        return 'ਪੰਜਾਬੀ (Punjabi)';
      case AppLanguage.assamese:
        return 'অসমীয়া (Assamese)';
    }
  }

  String get localeCode {
    switch (this) {
      case AppLanguage.english:
        return 'en-US';
      case AppLanguage.hindi:
        return 'hi-IN';
      case AppLanguage.bengali:
        return 'bn-IN';
      case AppLanguage.telugu:
        return 'te-IN';
      case AppLanguage.marathi:
        return 'mr-IN';
      case AppLanguage.tamil:
        return 'ta-IN';
      case AppLanguage.gujarati:
        return 'gu-IN';
      case AppLanguage.kannada:
        return 'kn-IN';
      case AppLanguage.malayalam:
        return 'ml-IN';
      case AppLanguage.odia:
        return 'or-IN';
      case AppLanguage.punjabi:
        return 'pa-IN';
      case AppLanguage.assamese:
        return 'as-IN';
    }
  }

  String get ttsLanguage {
    switch (this) {
      case AppLanguage.english:
        return 'en-US';
      case AppLanguage.hindi:
        return 'hi-IN';
      case AppLanguage.bengali:
        return 'bn-IN';
      case AppLanguage.telugu:
        return 'te-IN';
      case AppLanguage.marathi:
        return 'mr-IN';
      case AppLanguage.tamil:
        return 'ta-IN';
      case AppLanguage.gujarati:
        return 'gu-IN';
      case AppLanguage.kannada:
        return 'kn-IN';
      case AppLanguage.malayalam:
        return 'ml-IN';
      case AppLanguage.odia:
        return 'or-IN';
      case AppLanguage.punjabi:
        return 'pa-IN';
      case AppLanguage.assamese:
        return 'as-IN';
    }
  }

  /// Helper: language confirmation message in the target language
  String get switchConfirmation {
    switch (this) {
      case AppLanguage.english:
        return 'Language switched to English.';
      case AppLanguage.hindi:
        return 'भाषा हिन्दी में बदल दी गयी है।';
      case AppLanguage.bengali:
        return 'ভাষা বাংলায় পরিবর্তন করা হয়েছে।';
      case AppLanguage.telugu:
        return 'భాష తెలుగులోకి మార్చబడింది.';
      case AppLanguage.marathi:
        return 'भाषा मराठीत बदलली आहे.';
      case AppLanguage.tamil:
        return 'மொழி தமிழுக்கு மாற்றப்பட்டது.';
      case AppLanguage.gujarati:
        return 'ભાષા ગુજરાતીમાં બદલાઈ ગઈ છે.';
      case AppLanguage.kannada:
        return 'ಭಾಷೆ ಕನ್ನಡಕ್ಕೆ ಬದಲಾಗಿದೆ.';
      case AppLanguage.malayalam:
        return 'ഭാഷ മലയാളത്തിലേക്ക് മാറ്റി.';
      case AppLanguage.odia:
        return 'ଭାଷା ଓଡ଼ିଆକୁ ବଦଳାଯାଇଛି।';
      case AppLanguage.punjabi:
        return 'ਭਾਸ਼ਾ ਪੰਜਾਬੀ ਵਿੱਚ ਬਦਲ ਦਿੱਤੀ ਗਈ ਹੈ।';
      case AppLanguage.assamese:
        return 'ভাষা অসমীয়ালৈ সলনি কৰা হৈছে।';
    }
  }

  /// Parse language name string to AppLanguage
  static AppLanguage? fromName(String name) {
    final lower = name.toLowerCase().trim();
    const languageMap = {
      'english': AppLanguage.english,
      'hindi': AppLanguage.hindi,
      'bengali': AppLanguage.bengali,
      'bangla': AppLanguage.bengali,
      'telugu': AppLanguage.telugu,
      'marathi': AppLanguage.marathi,
      'tamil': AppLanguage.tamil,
      'gujarati': AppLanguage.gujarati,
      'kannada': AppLanguage.kannada,
      'malayalam': AppLanguage.malayalam,
      'odia': AppLanguage.odia,
      'oriya': AppLanguage.odia,
      'punjabi': AppLanguage.punjabi,
      'assamese': AppLanguage.assamese,
      // Hindi names for languages
      'हिन्दी': AppLanguage.hindi,
      'बांग्ला': AppLanguage.bengali,
      'बंगाली': AppLanguage.bengali,
      'तेलुगु': AppLanguage.telugu,
      'मराठी': AppLanguage.marathi,
      'तमिल': AppLanguage.tamil,
      'गुजराती': AppLanguage.gujarati,
      'कन्नड़': AppLanguage.kannada,
      'मलयालम': AppLanguage.malayalam,
      'ओडिया': AppLanguage.odia,
      'पंजाबी': AppLanguage.punjabi,
      'असमिया': AppLanguage.assamese,
      'अंग्रेजी': AppLanguage.english,
    };
    return languageMap[lower];
  }
}

