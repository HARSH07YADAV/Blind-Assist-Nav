import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:geolocator/geolocator.dart';
import '../models/detection.dart';

/// Path Memory Service — Week 4, Day 7
/// 
/// SQLite-backed location + detection memory that remembers
/// frequently walked paths and common obstacles at each location.
/// 
/// Features:
/// - Records GPS + detected objects at each location
/// - Groups locations into "spots" using geo-clustering
/// - Identifies familiar routes by matching location sequences
/// - Announces known objects at familiar locations
class PathMemoryService extends ChangeNotifier {
  Database? _db;
  bool _isInitialized = false;
  
  // Current location tracking
  Position? _lastPosition;
  DateTime _lastRecordTime = DateTime.now();
  
  // Geo-clustering: locations within this radius are the same "spot"
  static const double _spotRadiusMeters = 10.0;
  
  // Record at most once per N seconds
  static const Duration _recordCooldown = Duration(seconds: 15);
  
  // Familiar location threshold: visited N+ times
  static const int _familiarThreshold = 3;
  
  static const String _spotsTable = 'path_spots';
  static const String _observationsTable = 'path_observations';
  
  bool get isInitialized => _isInitialized;
  
  /// Initialize the path memory database
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'vision_mate_paths.db');
      
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          // Spots table — geographic locations the user visits
          await db.execute('''
            CREATE TABLE $_spotsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              visit_count INTEGER DEFAULT 1,
              first_visited TEXT NOT NULL,
              last_visited TEXT NOT NULL,
              label TEXT
            )
          ''');
          
          // Observations — objects detected at each spot
          await db.execute('''
            CREATE TABLE $_observationsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              spot_id INTEGER NOT NULL,
              class_name TEXT NOT NULL,
              relative_position TEXT,
              frequency INTEGER DEFAULT 1,
              last_seen TEXT NOT NULL,
              FOREIGN KEY (spot_id) REFERENCES $_spotsTable(id)
            )
          ''');
          
          // Index for fast geo-queries
          await db.execute(
            'CREATE INDEX idx_spots_geo ON $_spotsTable(latitude, longitude)'
          );
          await db.execute(
            'CREATE INDEX idx_obs_spot ON $_observationsTable(spot_id)'
          );
        },
      );
      
      _isInitialized = true;
      debugPrint('[PathMemory] Database initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('[PathMemory] Init error: $e');
    }
  }
  
  /// Record current location and detected objects
  Future<void> recordLocation(
    List<Detection> detections,
  ) async {
    if (!_isInitialized || _db == null) return;
    
    // Cooldown check
    final now = DateTime.now();
    if (now.difference(_lastRecordTime) < _recordCooldown) return;
    _lastRecordTime = now;
    
    try {
      // Get current GPS position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastPosition = position;
      
      // Find or create spot
      final spotId = await _findOrCreateSpot(
        position.latitude,
        position.longitude,
      );
      
      // Record detected objects at this spot
      for (final detection in detections) {
        await _recordObservation(
          spotId,
          detection.className,
          detection.relativePosition.name,
        );
      }
      
      debugPrint('[PathMemory] Recorded ${detections.length} objects at spot $spotId');
    } catch (e) {
      debugPrint('[PathMemory] Record error: $e');
    }
  }
  
  /// Find an existing spot near the given coordinates, or create a new one
  Future<int> _findOrCreateSpot(double lat, double lng) async {
    // Simple proximity search using bounding box
    // ~0.0001° latitude ≈ 11 meters
    final delta = _spotRadiusMeters / 111000; // Convert meters to degrees
    
    final rows = await _db!.query(
      _spotsTable,
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [lat - delta, lat + delta, lng - delta, lng + delta],
      limit: 1,
    );
    
    if (rows.isNotEmpty) {
      final spotId = rows.first['id'] as int;
      // Update visit count and last_visited
      await _db!.update(
        _spotsTable,
        {
          'visit_count': (rows.first['visit_count'] as int) + 1,
          'last_visited': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [spotId],
      );
      return spotId;
    }
    
    // Create new spot
    return await _db!.insert(_spotsTable, {
      'latitude': lat,
      'longitude': lng,
      'visit_count': 1,
      'first_visited': DateTime.now().toIso8601String(),
      'last_visited': DateTime.now().toIso8601String(),
    });
  }
  
  /// Record an object observation at a spot
  Future<void> _recordObservation(
    int spotId,
    String className,
    String relativePosition,
  ) async {
    // Check if this object was seen before at this spot
    final existing = await _db!.query(
      _observationsTable,
      where: 'spot_id = ? AND class_name = ? AND relative_position = ?',
      whereArgs: [spotId, className, relativePosition],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      // Update frequency
      await _db!.update(
        _observationsTable,
        {
          'frequency': (existing.first['frequency'] as int) + 1,
          'last_seen': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id'] as int],
      );
    } else {
      // New observation
      await _db!.insert(_observationsTable, {
        'spot_id': spotId,
        'class_name': className,
        'relative_position': relativePosition,
        'frequency': 1,
        'last_seen': DateTime.now().toIso8601String(),
      });
    }
  }
  
  /// Get memorized objects near the current location
  Future<PathMemory?> getMemoryForCurrentLocation() async {
    if (!_isInitialized || _db == null) return null;
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      return getMemoryForLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('[PathMemory] Location error: $e');
      return null;
    }
  }
  
  /// Get memorized objects at a specific location
  Future<PathMemory?> getMemoryForLocation(double lat, double lng) async {
    if (!_isInitialized || _db == null) return null;
    
    final delta = _spotRadiusMeters / 111000;
    
    final spots = await _db!.query(
      _spotsTable,
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [lat - delta, lat + delta, lng - delta, lng + delta],
    );
    
    if (spots.isEmpty) return null;
    
    final spot = spots.first;
    final spotId = spot['id'] as int;
    final visitCount = spot['visit_count'] as int;
    final isFamiliar = visitCount >= _familiarThreshold;
    
    // Get common objects at this spot (frequency >= 2)
    final observations = await _db!.query(
      _observationsTable,
      where: 'spot_id = ? AND frequency >= 2',
      whereArgs: [spotId],
      orderBy: 'frequency DESC',
      limit: 10,
    );
    
    final knownObjects = observations.map((row) => MemorizedObject(
      className: row['class_name'] as String,
      relativePosition: row['relative_position'] as String?,
      frequency: row['frequency'] as int,
    )).toList();
    
    return PathMemory(
      spotId: spotId,
      visitCount: visitCount,
      isFamiliar: isFamiliar,
      knownObjects: knownObjects,
      label: spot['label'] as String?,
    );
  }
  
  /// Generate a familiar route announcement
  Future<String?> getFamiliarRouteAnnouncement() async {
    final memory = await getMemoryForCurrentLocation();
    if (memory == null || !memory.isFamiliar) return null;
    
    final objects = memory.knownObjects.take(3);
    if (objects.isEmpty) return null;
    
    final label = memory.label ?? 'a familiar area';
    final descriptions = objects.map((o) {
      final pos = o.relativePosition ?? 'nearby';
      return '${o.className} usually $pos';
    }).join('. ');
    
    return 'You\'re on a familiar route near $label. $descriptions.';
  }
  
  /// Label a spot (e.g., "kitchen", "office entrance")
  Future<void> labelCurrentSpot(String label) async {
    if (!_isInitialized || _db == null) return;
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final delta = _spotRadiusMeters / 111000;
      
      await _db!.update(
        _spotsTable,
        {'label': label},
        where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
        whereArgs: [
          position.latitude - delta, position.latitude + delta,
          position.longitude - delta, position.longitude + delta,
        ],
      );
      
      debugPrint('[PathMemory] Labeled current spot: $label');
    } catch (e) {
      debugPrint('[PathMemory] Label error: $e');
    }
  }
  
  /// Get statistics
  Future<Map<String, int>> getStats() async {
    if (!_isInitialized || _db == null) return {};
    
    try {
      final spotCount = Sqflite.firstIntValue(
        await _db!.rawQuery('SELECT COUNT(*) FROM $_spotsTable')
      ) ?? 0;
      
      final obsCount = Sqflite.firstIntValue(
        await _db!.rawQuery('SELECT COUNT(*) FROM $_observationsTable')
      ) ?? 0;
      
      final familiarCount = Sqflite.firstIntValue(
        await _db!.rawQuery(
          'SELECT COUNT(*) FROM $_spotsTable WHERE visit_count >= ?',
          [_familiarThreshold],
        )
      ) ?? 0;
      
      return {
        'spots': spotCount,
        'observations': obsCount,
        'familiar_spots': familiarCount,
      };
    } catch (e) {
      debugPrint('[PathMemory] Stats error: $e');
      return {};
    }
  }
  
  /// Clear all path memory
  Future<void> clearAllMemory() async {
    if (!_isInitialized || _db == null) return;
    
    await _db!.delete(_observationsTable);
    await _db!.delete(_spotsTable);
    debugPrint('[PathMemory] All memory cleared');
  }
  
  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}

/// Memorized path information for a location
class PathMemory {
  final int spotId;
  final int visitCount;
  final bool isFamiliar;
  final List<MemorizedObject> knownObjects;
  final String? label;
  
  PathMemory({
    required this.spotId,
    required this.visitCount,
    required this.isFamiliar,
    required this.knownObjects,
    this.label,
  });
}

/// An object commonly seen at a location
class MemorizedObject {
  final String className;
  final String? relativePosition;
  final int frequency;
  
  MemorizedObject({
    required this.className,
    this.relativePosition,
    required this.frequency,
  });
}
