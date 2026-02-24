import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Emergency contact model
class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'relationship': relationship,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? '',
    );
  }
}

/// Week 5: Enhanced emergency service
/// 
/// Features:
/// - Multiple emergency contacts (up to 5)
/// - Send SOS to ALL contacts simultaneously
/// - Live location sharing with web link
/// - Voice-based contact management
class EmergencyService extends ChangeNotifier {
  static const String _contactsKey = 'emergency_contacts_list';
  static const int _maxContacts = 5;
  
  bool _isInitialized = false;
  Position? _lastPosition;
  List<EmergencyContact> _contacts = [];
  
  // Live location sharing
  bool _isLiveSharing = false;
  Timer? _liveLocationTimer;
  static const Duration _liveLocationInterval = Duration(seconds: 30);
  
  bool get isInitialized => _isInitialized;
  Position? get lastPosition => _lastPosition;
  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);
  int get contactCount => _contacts.length;
  bool get hasContacts => _contacts.isNotEmpty;
  bool get isLiveSharing => _isLiveSharing;

  /// Initialize and request location permission
  Future<void> initialize() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      // Get initial position
      await _updateLocation();
      
      // Load saved contacts
      await _loadContacts();
      
      _isInitialized = true;
      debugPrint('[Emergency] Initialized with ${_contacts.length} contacts');
    } catch (e) {
      debugPrint('[Emergency] Init error: $e');
    }
  }

  // ==================== Contact Management ====================

  /// Add an emergency contact (max 5)
  Future<bool> addContact(String name, String phone, {String relationship = ''}) async {
    if (_contacts.length >= _maxContacts) {
      debugPrint('[Emergency] Max contacts reached ($_maxContacts)');
      return false;
    }
    
    // Check for duplicate phone
    if (_contacts.any((c) => c.phone == phone)) {
      debugPrint('[Emergency] Duplicate contact: $phone');
      return false;
    }
    
    _contacts.add(EmergencyContact(
      name: name,
      phone: phone,
      relationship: relationship,
    ));
    
    await _saveContacts();
    notifyListeners();
    debugPrint('[Emergency] Added contact: $name ($phone)');
    return true;
  }

  /// Remove a contact by name (case-insensitive)
  Future<bool> removeContact(String name) async {
    final lower = name.toLowerCase();
    final index = _contacts.indexWhere(
      (c) => c.name.toLowerCase() == lower
    );
    
    if (index == -1) return false;
    
    final removed = _contacts.removeAt(index);
    await _saveContacts();
    notifyListeners();
    debugPrint('[Emergency] Removed contact: ${removed.name}');
    return true;
  }

  /// Get a list description of all contacts for TTS
  String listContactsDescription() {
    if (_contacts.isEmpty) {
      return 'No emergency contacts set. Say "add emergency contact" to add one.';
    }
    
    final descriptions = _contacts.asMap().entries.map((e) {
      final c = e.value;
      final rel = c.relationship.isNotEmpty ? ', ${c.relationship}' : '';
      return '${e.key + 1}. ${c.name}$rel';
    }).join('. ');
    
    return 'You have ${_contacts.length} emergency contacts. $descriptions.';
  }

  /// Set a single emergency contact (legacy compatibility)
  void setEmergencyContact(String contact) {
    if (contact.isNotEmpty && !_contacts.any((c) => c.phone == contact)) {
      _contacts.add(EmergencyContact(
        name: 'Emergency',
        phone: contact,
      ));
      _saveContacts();
    }
  }

  // ==================== SOS ====================

  /// Update current location
  Future<void> _updateLocation() async {
    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[Emergency] Location error: $e');
    }
  }

  /// Trigger emergency SOS — sends to ALL contacts simultaneously
  Future<bool> triggerSOS({String? customMessage}) async {
    await _updateLocation();
    
    if (_contacts.isEmpty) {
      debugPrint('[Emergency] No contacts set');
      return false;
    }
    
    String message = customMessage ?? 'EMERGENCY! I need help.';
    
    if (_lastPosition != null) {
      final lat = _lastPosition!.latitude;
      final lng = _lastPosition!.longitude;
      final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
      message += '\n\nMy location: $mapsUrl';
      message += '\nCoordinates: $lat, $lng';
    }
    
    // Send to ALL contacts simultaneously
    final futures = _contacts.map((contact) => _sendSMS(contact.phone, message));
    final results = await Future.wait(futures);
    
    final successCount = results.where((r) => r).length;
    debugPrint('[Emergency] SOS sent to $successCount/${_contacts.length} contacts');
    
    return successCount > 0;
  }

  /// Send SMS to a single contact
  Future<bool> _sendSMS(String phone, String message) async {
    try {
      final smsUri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': message},
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Emergency] SMS error for $phone: $e');
      return false;
    }
  }

  /// Call the first emergency contact
  Future<bool> callEmergency() async {
    if (_contacts.isEmpty) return false;
    
    try {
      final telUri = Uri(
        scheme: 'tel',
        path: _contacts.first.phone,
      );
      
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Emergency] Call error: $e');
      return false;
    }
  }

  // ==================== Live Location Sharing ====================

  /// Start sharing live location (sends periodic updates via SMS)
  void startLiveLocationSharing() {
    if (_contacts.isEmpty || _isLiveSharing) return;
    
    _isLiveSharing = true;
    debugPrint('[Emergency] Live location sharing started');
    
    // Send initial location
    _sendLiveLocationUpdate();
    
    // Set up periodic updates
    _liveLocationTimer = Timer.periodic(_liveLocationInterval, (_) {
      _sendLiveLocationUpdate();
    });
    
    notifyListeners();
  }

  /// Stop live location sharing
  void stopLiveLocationSharing() {
    _isLiveSharing = false;
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    debugPrint('[Emergency] Live location sharing stopped');
    notifyListeners();
  }

  /// Send a live location update to all contacts
  Future<void> _sendLiveLocationUpdate() async {
    await _updateLocation();
    
    if (_lastPosition == null) return;
    
    final lat = _lastPosition!.latitude;
    final lng = _lastPosition!.longitude;
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    final time = DateTime.now().toIso8601String().substring(11, 16);
    
    final message = 'VisionMate Live Location Update ($time)\n'
                     'Location: $mapsUrl';
    
    for (final contact in _contacts) {
      await _sendSMS(contact.phone, message);
    }
  }

  // ==================== Persistence ====================

  /// Load contacts from shared preferences
  Future<void> _loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_contactsKey);
      
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        _contacts = jsonList
            .map((j) => EmergencyContact.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      
      debugPrint('[Emergency] Loaded ${_contacts.length} contacts');
    } catch (e) {
      debugPrint('[Emergency] Error loading contacts: $e');
    }
  }

  /// Save contacts to shared preferences
  Future<void> _saveContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_contacts.map((c) => c.toJson()).toList());
      await prefs.setString(_contactsKey, jsonStr);
    } catch (e) {
      debugPrint('[Emergency] Error saving contacts: $e');
    }
  }

  // ==================== Utility ====================

  /// Get location description
  String getLocationDescription() {
    if (_lastPosition == null) {
      return 'Location unknown';
    }
    return 'Lat: ${_lastPosition!.latitude.toStringAsFixed(4)}, '
           'Lng: ${_lastPosition!.longitude.toStringAsFixed(4)}';
  }

  @override
  void dispose() {
    _liveLocationTimer?.cancel();
    super.dispose();
  }
}
