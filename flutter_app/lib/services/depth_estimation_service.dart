import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/detection.dart';

/// Depth Estimation Service — Week 4, Day 1-2
/// 
/// Provides accurate monocular depth estimation using per-class
/// real-world height priors and pinhole camera geometry.
/// 
/// Formula: distance = (realHeight × focalLength) / pixelHeight
/// 
/// Improvements over basic heuristic:
/// - 50+ class height priors covering all COCO classes
/// - Temporal smoothing to reduce distance jitter
/// - Width-based fallback for flat/wide objects (e.g., dining table)
/// - Precise human-readable distance descriptions
class DepthEstimationService extends ChangeNotifier {
  bool _isInitialized = false;
  
  // Smoothing: store recent distances per tracked object class
  final Map<String, List<double>> _distanceHistory = {};
  static const int _smoothingWindow = 5;
  
  // Camera focal length estimation (will be calibrated on first frame)
  double _focalLengthPx = 0;
  
  bool get isInitialized => _isInitialized;
  
  /// Known real-world heights (meters) for COCO classes + custom classes
  static const Map<String, double> objectHeights = {
    // People & animals
    'person': 1.7, 'dog': 0.5, 'cat': 0.3, 'horse': 1.6,
    'cow': 1.4, 'sheep': 0.7, 'elephant': 3.0, 'bear': 1.5,
    'zebra': 1.4, 'giraffe': 5.5, 'bird': 0.2,
    // Vehicles
    'car': 1.5, 'truck': 2.8, 'bus': 3.2, 'train': 3.5,
    'motorcycle': 1.1, 'bicycle': 1.0, 'boat': 1.5, 'airplane': 4.0,
    // Furniture
    'chair': 0.9, 'couch': 0.85, 'bed': 0.6, 'dining table': 0.75,
    'toilet': 0.4, 'bench': 0.85,
    // Electronics
    'tv': 0.5, 'laptop': 0.25, 'cell phone': 0.15, 'keyboard': 0.05,
    'mouse': 0.04, 'remote': 0.2, 'microwave': 0.35, 'oven': 0.85,
    'toaster': 0.2, 'refrigerator': 1.7,
    // Household
    'bottle': 0.25, 'cup': 0.12, 'wine glass': 0.22, 'bowl': 0.1,
    'vase': 0.3, 'clock': 0.3, 'scissors': 0.15, 'book': 0.25,
    'potted plant': 0.4, 'teddy bear': 0.3, 'hair drier': 0.25,
    'toothbrush': 0.18, 'sink': 0.35,
    // Accessories
    'backpack': 0.5, 'handbag': 0.3, 'suitcase': 0.7,
    'umbrella': 1.0, 'tie': 0.5,
    // Sports
    'frisbee': 0.03, 'skis': 1.7, 'snowboard': 0.3,
    'sports ball': 0.22, 'kite': 0.8, 'baseball bat': 0.9,
    'baseball glove': 0.25, 'skateboard': 0.15, 'surfboard': 0.6,
    'tennis racket': 0.7,
    // Food (visible height when placed)
    'banana': 0.05, 'apple': 0.08, 'sandwich': 0.08, 'orange': 0.08,
    'broccoli': 0.15, 'carrot': 0.03, 'hot dog': 0.05, 'pizza': 0.03,
    'donut': 0.05, 'cake': 0.15, 'fork': 0.02, 'knife': 0.02,
    'spoon': 0.02,
    // Infrastructure
    'traffic light': 1.0, 'fire hydrant': 0.75, 'stop sign': 0.75,
    'parking meter': 1.2,
    // Custom (from heuristic detections)
    'stairs': 2.0, 'door': 2.0, 'elevator': 2.2, 'crosswalk': 0.1,
    'signboard': 0.6,
  };
  
  /// Known real-world widths — used as fallback for flat/wide objects
  static const Map<String, double> _objectWidths = {
    'dining table': 1.2, 'bed': 1.5, 'couch': 2.0,
    'tv': 0.8, 'laptop': 0.35, 'keyboard': 0.45,
    'bench': 1.5, 'skateboard': 0.8, 'surfboard': 0.5,
    'crosswalk': 3.0,
  };

  /// Initialize the depth estimation service
  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint('[Depth] Initialized with ${objectHeights.length} class priors');
    notifyListeners();
  }

  /// Estimate distance for a detection using pinhole camera model
  /// 
  /// Uses the formula: distance = (realHeight × focalLength) / pixelHeight
  /// Falls back to width-based estimation for flat objects
  double estimateDistance({
    required String className,
    required double boxHeightPx,
    required double boxWidthPx,
    required double frameHeight,
    required double frameWidth,
  }) {
    _calibrateFocalLength(frameHeight);
    
    final heightPrior = objectHeights[className.toLowerCase()];
    final widthPrior = _objectWidths[className.toLowerCase()];
    
    double distance = -1;
    
    // Primary: height-based estimation
    if (heightPrior != null && boxHeightPx > 10) {
      distance = (heightPrior * _focalLengthPx) / boxHeightPx;
    }
    
    // Fallback: width-based estimation for flat/wide objects
    if ((distance < 0 || heightPrior == null) && widthPrior != null && boxWidthPx > 10) {
      final widthFocal = frameWidth * 0.9; // Horizontal focal length
      distance = (widthPrior * widthFocal) / boxWidthPx;
    }
    
    // Final fallback: generic estimation using 0.5m default height
    if (distance < 0 && boxHeightPx > 10) {
      distance = (0.5 * _focalLengthPx) / boxHeightPx;
    }
    
    if (distance < 0) return -1;
    
    // Apply temporal smoothing
    distance = _smoothDistance(className, distance);
    
    return distance.clamp(0.2, 25.0);
  }
  
  /// Calibrate focal length based on frame dimensions
  /// Typical smartphone: ~28mm equivalent → focal length ≈ frame_height × 0.9
  void _calibrateFocalLength(double frameHeight) {
    if (_focalLengthPx == 0) {
      _focalLengthPx = frameHeight * 0.9;
      debugPrint('[Depth] Focal length calibrated: $_focalLengthPx px');
    }
  }
  
  /// Smooth distance readings to reduce jitter
  double _smoothDistance(String className, double rawDistance) {
    final history = _distanceHistory.putIfAbsent(className, () => []);
    history.add(rawDistance);
    
    if (history.length > _smoothingWindow) {
      history.removeAt(0);
    }
    
    // Use median for robustness against outliers
    final sorted = List<double>.from(history)..sort();
    return sorted[sorted.length ~/ 2];
  }
  
  /// Get precise human-readable distance description
  String getDistanceDescription(double meters) {
    if (meters < 0) return 'unknown distance';
    if (meters < 0.5) return 'within arm\'s reach';
    if (meters < 1.0) return 'about one step away';
    if (meters < 1.5) return 'about two steps away';
    if (meters < 2.0) return 'about three steps away';
    if (meters < 3.0) return 'approximately ${meters.toStringAsFixed(0)} meters ahead';
    if (meters < 5.0) return 'about ${meters.toStringAsFixed(0)} meters ahead';
    if (meters < 10.0) return 'about ${meters.toStringAsFixed(0)} meters away';
    return 'far away, about ${meters.toStringAsFixed(0)} meters';
  }
  
  /// Estimate distance for a Detection object (convenience method)
  double estimateForDetection(Detection detection, {
    required double frameHeight,
    required double frameWidth,
  }) {
    return estimateDistance(
      className: detection.className,
      boxHeightPx: detection.boundingBox.height,
      boxWidthPx: detection.boundingBox.width,
      frameHeight: frameHeight,
      frameWidth: frameWidth,
    );
  }
  
  /// Clear distance history (call when detection is restarted)
  void clearHistory() {
    _distanceHistory.clear();
  }
  
  @override
  void dispose() {
    _distanceHistory.clear();
    super.dispose();
  }
}
