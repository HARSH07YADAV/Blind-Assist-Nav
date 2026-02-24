import 'package:flutter/foundation.dart';
import '../models/detection.dart';

/// Landmark Service — Week 4, Day 5-6
/// 
/// Enhanced detection and classification of navigation-critical landmarks:
/// - Doors (open/closed classification via aspect ratio)
/// - Stairs (up/down based on position in frame)
/// - Elevators (door-like detection context)
/// - Signboards (triggers OCR for large flat regions)
/// 
/// Works alongside YOLOv8n COCO classes + custom heuristic detections!
class LandmarkService extends ChangeNotifier {
  final List<Landmark> _activeLandmarks = [];
  DateTime _lastLandmarkAnnouncement = DateTime.now();
  
  static const Duration _announceCooldown = Duration(seconds: 4);
  
  List<Landmark> get activeLandmarks => List.unmodifiable(_activeLandmarks);
  
  /// Analyze detections for navigation-critical landmarks
  /// Returns list of identified landmarks with spatial context
  List<Landmark> analyzeLandmarks(
    List<Detection> detections, {
    required int frameWidth,
    required int frameHeight,
  }) {
    final landmarks = <Landmark>[];
    
    for (final detection in detections) {
      final landmark = _classifyLandmark(detection, frameWidth, frameHeight);
      if (landmark != null) {
        landmarks.add(landmark);
      }
    }
    
    _activeLandmarks.clear();
    _activeLandmarks.addAll(landmarks);
    
    if (landmarks.isNotEmpty) {
      notifyListeners();
    }
    
    return landmarks;
  }
  
  /// Classify a detection as a landmark if applicable
  Landmark? _classifyLandmark(
    Detection detection,
    int frameWidth,
    int frameHeight,
  ) {
    final name = detection.className.toLowerCase();
    final box = detection.boundingBox;
    final position = detection.relativePosition;
    
    // --- DOOR detection ---
    if (name == 'door' || _isDoorLike(detection, frameWidth, frameHeight)) {
      final isOpen = _isDoorOpen(box);
      return Landmark(
        type: LandmarkType.door,
        detection: detection,
        subType: isOpen ? 'open' : 'closed',
        description: 'Door ${position.description}, appears ${isOpen ? "open" : "closed"}',
        navRelevance: NavRelevance.high,
      );
    }
    
    // --- STAIRS detection ---
    if (name == 'stairs' || name == 'staircase' || name == 'stairs_down') {
      final direction = _classifyStairsDirection(box, frameHeight);
      return Landmark(
        type: LandmarkType.stairs,
        detection: detection,
        subType: direction,
        description: 'Stairs $direction ${detection.distanceDescription}, ${position.description}',
        navRelevance: NavRelevance.critical,
      );
    }
    
    // --- ELEVATOR detection ---
    // Elevator doors look like regular doors but are typically larger and centered
    if (_isElevatorLike(detection, frameWidth, frameHeight)) {
      return Landmark(
        type: LandmarkType.elevator,
        detection: detection,
        subType: 'door',
        description: 'Elevator ${position.description}',
        navRelevance: NavRelevance.high,
      );
    }
    
    // --- SIGNBOARD / TEXT detection ---
    // Large flat rectangular regions could be signs
    if (_isSignboardLike(detection, frameWidth, frameHeight)) {
      return Landmark(
        type: LandmarkType.signboard,
        detection: detection,
        subType: 'readable',
        description: 'Sign or text board ${position.description}. Say "read this" to read it.',
        navRelevance: NavRelevance.medium,
      );
    }
    
    // --- BENCH (rest stop) ---
    if (name == 'bench') {
      return Landmark(
        type: LandmarkType.bench,
        detection: detection,
        subType: 'seating',
        description: 'Bench ${position.description}, ${detection.distanceDescription}',
        navRelevance: NavRelevance.low,
      );
    }
    
    // --- TOILET (bathroom landmark) ---
    if (name == 'toilet') {
      return Landmark(
        type: LandmarkType.bathroom,
        detection: detection,
        subType: 'toilet',
        description: 'Bathroom area detected ${position.description}',
        navRelevance: NavRelevance.medium,
      );
    }
    
    return null;
  }
  
  /// Check if detection looks like a door (tall and narrow)
  bool _isDoorLike(Detection detection, int frameWidth, int frameHeight) {
    final box = detection.boundingBox;
    final aspectRatio = box.height / (box.width > 0 ? box.width : 1);
    final relativeHeight = box.height / frameHeight;
    
    // Doors are typically taller than wide (aspect ratio 1.5-3.5)
    // and take up significant vertical space
    return aspectRatio > 1.5 && aspectRatio < 3.5 && relativeHeight > 0.3;
  }
  
  /// Determine if a door appears open or closed
  bool _isDoorOpen(BoundingBox box) {
    // Open doors tend to be wider (lower aspect ratio) due to perspective
    final aspectRatio = box.height / (box.width > 0 ? box.width : 1);
    return aspectRatio < 2.0; // Open doors appear wider
  }
  
  /// Classify stairs as going up or down based on position
  String _classifyStairsDirection(BoundingBox box, int frameHeight) {
    final topFraction = box.top / frameHeight;
    
    // If stairs are in the lower portion of frame, they go down
    // If in upper portion, they go up
    if (topFraction > 0.5) {
      return 'going down';
    } else {
      return 'going up';
    }
  }
  
  /// Check if detection could be an elevator
  /// Elevator doors: large, centered, door-like proportions
  bool _isElevatorLike(Detection detection, int frameWidth, int frameHeight) {
    final box = detection.boundingBox;
    final centerX = box.centerX / frameWidth;
    final aspectRatio = box.height / (box.width > 0 ? box.width : 1);
    final relativeWidth = box.width / frameWidth;
    final relativeHeight = box.height / frameHeight;
    
    // Elevator doors: roughly centered, large, metal/reflective
    // They're typically wider than regular doors
    return aspectRatio > 1.0 && aspectRatio < 2.5 &&
           relativeWidth > 0.2 && relativeHeight > 0.4 &&
           centerX > 0.25 && centerX < 0.75;
  }
  
  /// Check if detection could be a signboard
  /// Signs: wide, flat rectangles, usually in upper portion of frame
  bool _isSignboardLike(Detection detection, int frameWidth, int frameHeight) {
    final box = detection.boundingBox;
    final aspectRatio = box.width / (box.height > 0 ? box.height : 1);
    final relativeArea = box.area / (frameWidth * frameHeight);
    final topFraction = box.top / frameHeight;
    
    // Signs are wider than tall, reasonably sized, often in upper frame
    return aspectRatio > 1.5 && relativeArea > 0.02 && 
           relativeArea < 0.3 && topFraction < 0.5;
  }
  
  /// Get announcement for the most important landmark
  String? getTopLandmarkAnnouncement() {
    if (_activeLandmarks.isEmpty) return null;
    
    final now = DateTime.now();
    if (now.difference(_lastLandmarkAnnouncement) < _announceCooldown) {
      return null;
    }
    
    // Sort by navigation relevance
    final sorted = List<Landmark>.from(_activeLandmarks)
      ..sort((a, b) => b.navRelevance.index.compareTo(a.navRelevance.index));
    
    _lastLandmarkAnnouncement = now;
    return sorted.first.description;
  }
  
  /// Find a specific landmark type
  Landmark? findLandmark(LandmarkType type) {
    for (final l in _activeLandmarks) {
      if (l.type == type) return l;
    }
    return null;
  }
  
  /// Find landmarks matching a keyword
  List<Landmark> findByKeyword(String keyword) {
    final lower = keyword.toLowerCase();
    return _activeLandmarks.where((l) {
      return l.type.name.contains(lower) || 
             l.description.toLowerCase().contains(lower) ||
             l.detection.className.toLowerCase().contains(lower);
    }).toList();
  }
  
  /// Clear all landmarks
  void clearLandmarks() {
    _activeLandmarks.clear();
  }
  
  @override
  void dispose() {
    _activeLandmarks.clear();
    super.dispose();
  }
}

/// A recognized navigation landmark
class Landmark {
  final LandmarkType type;
  final Detection detection;
  final String subType;      // e.g., 'open', 'closed', 'going up', 'going down'
  final String description;  // Human-readable description
  final NavRelevance navRelevance;
  
  Landmark({
    required this.type,
    required this.detection,
    required this.subType,
    required this.description,
    required this.navRelevance,
  });
}

/// Types of navigation landmarks
enum LandmarkType {
  door,
  stairs,
  elevator,
  signboard,
  bench,
  bathroom,
}

/// Navigation relevance level
enum NavRelevance {
  low,
  medium,
  high,
  critical,
}
