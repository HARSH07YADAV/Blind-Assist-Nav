import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Week 8: BLE beacon-based indoor navigation
/// Scans for BLE beacons, maps UUIDs to location labels,
/// and announces proximity changes to the user
class IndoorNavigationService extends ChangeNotifier {
  /// Beacon registry: device ID → location label
  final Map<String, BeaconLocation> _beaconRegistry = {};
  static const String _storageKey = 'beacon_registry';

  /// Currently detected beacons with proximity
  final Map<String, BeaconReading> _activeBeacons = {};

  bool _isInitialized = false;
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _cleanupTimer;

  /// Current closest known location
  String? _currentLocation;
  ProximityZone? _currentZone;

  // Callbacks
  Function(String message)? onSpeak;
  Function(String location, ProximityZone zone)? onLocationChanged;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  String? get currentLocation => _currentLocation;
  ProximityZone? get currentZone => _currentZone;
  int get registeredBeaconCount => _beaconRegistry.length;
  List<String> get registeredLocations =>
      _beaconRegistry.values.map((b) => b.label).toList();

  /// Initialize — load saved beacon registry
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final Map<String, dynamic> data = jsonDecode(json);
        for (final entry in data.entries) {
          _beaconRegistry[entry.key] = BeaconLocation.fromJson(entry.value);
        }
      }
      _isInitialized = true;
      debugPrint(
          '[IndoorNav] Initialized with ${_beaconRegistry.length} beacons');
    } catch (e) {
      debugPrint('[IndoorNav] Init error: $e');
      _isInitialized = true;
    }
  }

  /// Start BLE scanning for nearby beacons
  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        onSpeak?.call('Bluetooth is not supported on this device.');
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        onSpeak?.call('Please turn on Bluetooth for indoor navigation.');
        return;
      }

      _isScanning = true;
      notifyListeners();

      // Start scanning with low energy mode
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          _processScanResults(results);
        },
        onError: (e) {
          debugPrint('[IndoorNav] Scan error: $e');
        },
      );

      // Cleanup stale beacons every 10 seconds
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _cleanupStaleBeacons(),
      );

      // Restart scan when it times out
      FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _isScanning) {
          // Restart scan
          Future.delayed(const Duration(seconds: 2), () {
            if (_isScanning) {
              FlutterBluePlus.startScan(
                timeout: const Duration(seconds: 30),
                androidScanMode: AndroidScanMode.lowLatency,
              );
            }
          });
        }
      });

      onSpeak?.call('Indoor navigation started. Scanning for beacons.');
      debugPrint('[IndoorNav] Scanning started');
    } catch (e) {
      debugPrint('[IndoorNav] Start scan error: $e');
      _isScanning = false;
      onSpeak?.call('Could not start indoor navigation.');
    }
  }

  /// Stop BLE scanning
  Future<void> stopScanning() async {
    _isScanning = false;
    _cleanupTimer?.cancel();
    _scanSubscription?.cancel();

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('[IndoorNav] Stop scan error: $e');
    }

    _activeBeacons.clear();
    notifyListeners();
    debugPrint('[IndoorNav] Scanning stopped');
  }

  /// Process BLE scan results
  void _processScanResults(List<ScanResult> results) {
    for (final result in results) {
      final deviceId = result.device.remoteId.str;
      final rssi = result.rssi;
      final zone = _rssiToZone(rssi);

      _activeBeacons[deviceId] = BeaconReading(
        deviceId: deviceId,
        rssi: rssi,
        zone: zone,
        lastSeen: DateTime.now(),
        deviceName: result.device.platformName,
      );

      // Check if this is a registered beacon
      if (_beaconRegistry.containsKey(deviceId)) {
        final beacon = _beaconRegistry[deviceId]!;
        _handleKnownBeacon(beacon, zone);
      }
    }
  }

  /// Handle a detected known beacon
  void _handleKnownBeacon(BeaconLocation beacon, ProximityZone zone) {
    final previousLocation = _currentLocation;
    final previousZone = _currentZone;

    // Update current location to the closest known beacon
    if (_currentLocation != beacon.label || _currentZone != zone) {
      // Only announce zone changes or new locations
      if (previousLocation != beacon.label) {
        _currentLocation = beacon.label;
        _currentZone = zone;
        _announceLocation(beacon.label, zone);
        onLocationChanged?.call(beacon.label, zone);
        notifyListeners();
      } else if (previousZone != zone) {
        _currentZone = zone;
        // Only announce significant zone changes
        if (zone == ProximityZone.immediate) {
          onSpeak?.call('You are right at the ${beacon.label}.');
        }
        notifyListeners();
      }
    }
  }

  /// Announce location change
  void _announceLocation(String location, ProximityZone zone) {
    switch (zone) {
      case ProximityZone.immediate:
        onSpeak?.call('You are at the $location.');
        break;
      case ProximityZone.near:
        onSpeak?.call('You are near the $location.');
        break;
      case ProximityZone.far:
        onSpeak?.call('The $location is nearby.');
        break;
      case ProximityZone.unknown:
        break;
    }
    debugPrint('[IndoorNav] Location: $location (${zone.name})');
  }

  /// Convert RSSI to proximity zone
  ProximityZone _rssiToZone(int rssi) {
    if (rssi >= -50) return ProximityZone.immediate; // < 1m
    if (rssi >= -70) return ProximityZone.near; // 1-3m
    if (rssi >= -90) return ProximityZone.far; // 3-10m
    return ProximityZone.unknown;
  }

  /// Clean up beacons not seen recently
  void _cleanupStaleBeacons() {
    final now = DateTime.now();
    _activeBeacons.removeWhere(
      (_, reading) => now.difference(reading.lastSeen) > const Duration(seconds: 15),
    );
  }

  /// Register a new beacon with a location label
  /// Called when user says "Save this location as [name]"
  Future<bool> saveLocation(String label) async {
    if (_activeBeacons.isEmpty) {
      onSpeak?.call('No beacons detected nearby. '
          'Make sure you are near a Bluetooth beacon.');
      return false;
    }

    // Find the strongest (closest) beacon
    String? closestId;
    int strongestRssi = -200;
    for (final entry in _activeBeacons.entries) {
      if (entry.value.rssi > strongestRssi) {
        strongestRssi = entry.value.rssi;
        closestId = entry.key;
      }
    }

    if (closestId == null) {
      onSpeak?.call('Could not identify nearest beacon.');
      return false;
    }

    _beaconRegistry[closestId] = BeaconLocation(
      deviceId: closestId,
      label: label.toLowerCase(),
      registeredAt: DateTime.now(),
    );

    await _saveRegistry();
    onSpeak?.call('Location saved as $label.');
    debugPrint('[IndoorNav] Saved beacon $closestId as $label');
    notifyListeners();
    return true;
  }

  /// Announce current indoor location
  void whereAmI() {
    if (!_isScanning) {
      onSpeak?.call('Indoor navigation is not active. '
          'Say "start indoor navigation" to begin.');
      return;
    }

    if (_currentLocation != null && _currentZone != null) {
      _announceLocation(_currentLocation!, _currentZone!);
    } else if (_activeBeacons.isNotEmpty) {
      onSpeak?.call(
          '${_activeBeacons.length} beacons detected but none are registered. '
          'Say "save this location as" followed by a name to register one.');
    } else {
      onSpeak?.call('No beacons detected nearby.');
    }
  }

  /// Persist beacon registry
  Future<void> _saveRegistry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      for (final entry in _beaconRegistry.entries) {
        data[entry.key] = entry.value.toJson();
      }
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[IndoorNav] Save registry error: $e');
    }
  }

  @override
  void dispose() {
    stopScanning();
    super.dispose();
  }
}

/// Proximity zone based on RSSI signal strength
enum ProximityZone {
  immediate, // < 1m (RSSI >= -50)
  near, // 1-3m (RSSI >= -70)
  far, // 3-10m (RSSI >= -90)
  unknown, // > 10m or unreliable
}

/// A registered beacon location
class BeaconLocation {
  final String deviceId;
  final String label;
  final DateTime registeredAt;

  BeaconLocation({
    required this.deviceId,
    required this.label,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'label': label,
        'registeredAt': registeredAt.toIso8601String(),
      };

  factory BeaconLocation.fromJson(Map<String, dynamic> json) => BeaconLocation(
        deviceId: json['deviceId'],
        label: json['label'],
        registeredAt: DateTime.parse(json['registeredAt']),
      );
}

/// A live beacon reading
class BeaconReading {
  final String deviceId;
  final int rssi;
  final ProximityZone zone;
  final DateTime lastSeen;
  final String deviceName;

  BeaconReading({
    required this.deviceId,
    required this.rssi,
    required this.zone,
    required this.lastSeen,
    required this.deviceName,
  });
}
