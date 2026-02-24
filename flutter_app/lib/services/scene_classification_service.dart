import 'package:flutter/foundation.dart';
import '../models/detection.dart';

/// Scene Classification Service — Week 4, Day 3
/// 
/// Classifies the current environment using detected object patterns.
/// Combines YOLO detections with ContextService data for rich
/// scene understanding and announcement adaptation.
class SceneClassificationService extends ChangeNotifier {
  SceneType _currentScene = SceneType.unknown;
  double _confidence = 0;
  DateTime _lastClassification = DateTime.now();
  
  // Scene history for stability (prevents rapid flickering)
  final List<SceneType> _sceneHistory = [];
  static const int _stabilityWindow = 5;
  
  // Getters
  SceneType get currentScene => _currentScene;
  double get confidence => _confidence;
  
  /// Classify the current scene based on detected objects
  SceneType classifyScene(List<Detection> detections) {
    if (detections.isEmpty) return _currentScene; // Keep last known

    final classNames = detections.map((d) => d.className.toLowerCase()).toSet();
    
    // Score each scene type based on object patterns
    final scores = <SceneType, double>{};
    
    for (final sceneType in SceneType.values) {
      if (sceneType == SceneType.unknown) continue;
      scores[sceneType] = _scoreScene(sceneType, classNames, detections);
    }
    
    // Find best match
    SceneType bestScene = SceneType.unknown;
    double bestScore = 0;
    
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestScene = entry.key;
      }
    }
    
    // Require minimum confidence
    if (bestScore < 0.3) {
      bestScene = SceneType.unknown;
    }
    
    // Apply stability filter
    _sceneHistory.add(bestScene);
    if (_sceneHistory.length > _stabilityWindow) {
      _sceneHistory.removeAt(0);
    }
    
    // Use mode (most common) from recent history
    final stableScene = _getMostCommon(_sceneHistory);
    
    if (stableScene != _currentScene) {
      _currentScene = stableScene;
      _confidence = bestScore;
      _lastClassification = DateTime.now();
      notifyListeners();
      debugPrint('[Scene] Classified: ${_currentScene.name} (${(_confidence * 100).toInt()}%)');
    }
    
    return _currentScene;
  }
  
  /// Score how well detected objects match a scene type
  double _scoreScene(SceneType scene, Set<String> classNames, List<Detection> detections) {
    final patterns = _scenePatterns[scene];
    if (patterns == null) return 0;
    
    int matches = 0;
    int totalIndicators = patterns.length;
    
    for (final indicator in patterns) {
      if (classNames.contains(indicator)) {
        matches++;
      }
    }
    
    if (totalIndicators == 0) return 0;
    return matches / totalIndicators;
  }
  
  /// Get most common element in a list
  SceneType _getMostCommon(List<SceneType> list) {
    final counts = <SceneType, int>{};
    for (final item in list) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
  
  /// Object patterns that indicate each scene type
  static const Map<SceneType, List<String>> _scenePatterns = {
    SceneType.kitchen: [
      'refrigerator', 'oven', 'microwave', 'sink', 'bottle', 
      'cup', 'bowl', 'fork', 'knife', 'spoon', 'toaster',
    ],
    SceneType.livingRoom: [
      'couch', 'tv', 'remote', 'potted plant', 'book', 'vase',
    ],
    SceneType.bedroom: [
      'bed', 'clock', 'book', 'teddy bear', 'laptop',
    ],
    SceneType.office: [
      'laptop', 'keyboard', 'mouse', 'chair', 'cell phone', 'book',
    ],
    SceneType.diningArea: [
      'dining table', 'chair', 'cup', 'bowl', 'fork', 'knife', 
      'spoon', 'wine glass', 'bottle',
    ],
    SceneType.road: [
      'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'traffic light',
      'stop sign', 'person',
    ],
    SceneType.crossing: [
      'traffic light', 'person', 'car', 'stop sign',
    ],
    SceneType.park: [
      'bench', 'person', 'dog', 'bird', 'potted plant', 'bicycle',
      'sports ball', 'kite', 'frisbee',
    ],
    SceneType.bathroom: [
      'toilet', 'sink', 'toothbrush', 'hair drier', 'bottle',
    ],
  };
  
  /// Get human-readable scene description
  String get sceneDescription {
    return switch (_currentScene) {
      SceneType.kitchen => 'You appear to be in a kitchen',
      SceneType.livingRoom => 'You appear to be in a living room',
      SceneType.bedroom => 'You appear to be in a bedroom',
      SceneType.office => 'You appear to be in an office or workspace',
      SceneType.diningArea => 'You appear to be near a dining area',
      SceneType.road => 'You appear to be near a road. Be careful',
      SceneType.crossing => 'You appear to be at a road crossing. Be very careful',
      SceneType.park => 'You appear to be in a park or outdoor area',
      SceneType.bathroom => 'You appear to be in a bathroom',
      SceneType.unknown => 'Scene not identified',
    };
  }
  
  /// Get announcement urgency adjustment for current scene
  /// Road/crossing scenes need more urgent, frequent announcements
  double get urgencyMultiplier {
    return switch (_currentScene) {
      SceneType.road => 1.5,
      SceneType.crossing => 2.0,
      SceneType.park => 0.8,
      SceneType.kitchen => 1.0,
      SceneType.bathroom => 0.7,
      SceneType.bedroom => 0.5,
      SceneType.livingRoom => 0.6,
      _ => 1.0,
    };
  }
  
  /// Whether the current scene is outdoors
  bool get isOutdoor => _currentScene == SceneType.road || 
                         _currentScene == SceneType.crossing ||
                         _currentScene == SceneType.park;
  
  /// Whether the current scene requires extra safety
  bool get isHighRisk => _currentScene == SceneType.road || 
                         _currentScene == SceneType.crossing;
  
  /// Clear classification history (e.g., when detection restarts)
  void clearHistory() {
    _sceneHistory.clear();
    _currentScene = SceneType.unknown;
    _confidence = 0;
  }
  
  @override
  void dispose() {
    _sceneHistory.clear();
    super.dispose();
  }
}

/// Scene type classification
enum SceneType {
  kitchen,
  livingRoom,
  bedroom,
  office,
  diningArea,
  road,
  crossing,
  park,
  bathroom,
  unknown,
}
