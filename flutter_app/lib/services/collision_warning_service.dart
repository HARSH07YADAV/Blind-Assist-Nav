import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/detection.dart';

/// Week 5: Collision warning system
/// 
/// Predicts object trajectories using tracking data and warns
/// the user 2-3 seconds before a potential collision.
/// "Moving object approaching from the left!"
class CollisionWarningService extends ChangeNotifier {
  // Position history for tracked objects: className -> list of position samples
  final Map<String, List<_PositionSample>> _objectHistory = {};
  
  // Active warnings to prevent duplicate alerts
  final Map<String, DateTime> _activeWarnings = {};
  
  // Configuration
  static const int _maxHistoryPerObject = 8;
  static const double _collisionZoneThreshold = 0.35; // Normalized center zone (0-1)
  static const double _minVelocity = 0.02; // Minimum normalized velocity to consider "moving"
  static const double _sizeGrowthThreshold = 1.15; // 15% size increase = approaching
  static const Duration _warningCooldown = Duration(seconds: 5);
  static const double _ttcWarningThreshold = 3.0; // Warn if TTC < 3 seconds
  
  bool _isEnabled = true;
  
  // Callback
  Function(String warning, CollisionUrgency urgency)? onCollisionWarning;
  
  bool get isEnabled => _isEnabled;
  
  /// Analyze detections for potential collisions
  /// Call this every frame with current detections
  List<CollisionWarning> analyzeFrame(
    List<Detection> detections, {
    required int frameWidth,
    required int frameHeight,
  }) {
    if (!_isEnabled) return [];
    
    final now = DateTime.now();
    final warnings = <CollisionWarning>[];
    
    // Update position history for each detection
    for (final detection in detections) {
      final key = _objectKey(detection);
      final normalizedCenterX = detection.boundingBox.centerX / frameWidth;
      final normalizedCenterY = detection.boundingBox.centerY / frameHeight;
      final normalizedArea = detection.boundingBox.area / (frameWidth * frameHeight);
      
      _objectHistory.putIfAbsent(key, () => []);
      _objectHistory[key]!.add(_PositionSample(
        centerX: normalizedCenterX,
        centerY: normalizedCenterY,
        area: normalizedArea,
        timestamp: now,
      ));
      
      // Trim history
      while (_objectHistory[key]!.length > _maxHistoryPerObject) {
        _objectHistory[key]!.removeAt(0);
      }
      
      // Need at least 3 samples to estimate velocity
      final history = _objectHistory[key]!;
      if (history.length < 3) continue;
      
      // Calculate velocity
      final velocity = _calculateVelocity(history);
      if (velocity == null) continue;
      
      // Check if object is moving toward the user
      final isApproaching = _isApproaching(history);
      if (!isApproaching) continue;
      
      // Estimate time-to-collision
      final ttc = _estimateTimeToCollision(history, velocity);
      if (ttc == null || ttc > _ttcWarningThreshold || ttc < 0) continue;
      
      // Check cooldown
      if (_activeWarnings.containsKey(key)) {
        final lastWarning = _activeWarnings[key]!;
        if (now.difference(lastWarning) < _warningCooldown) continue;
      }
      
      // Generate warning
      final direction = _getApproachDirection(velocity, normalizedCenterX);
      final urgency = ttc < 1.5 
          ? CollisionUrgency.critical 
          : CollisionUrgency.warning;
      
      final warningMessage = _buildWarningMessage(
        detection.className, direction, urgency,
      );
      
      warnings.add(CollisionWarning(
        objectName: detection.className,
        direction: direction,
        timeToCollision: ttc,
        urgency: urgency,
        message: warningMessage,
      ));
      
      _activeWarnings[key] = now;
      
      // Notify via callback
      onCollisionWarning?.call(warningMessage, urgency);
    }
    
    // Clean up stale history entries (objects not seen in 2 seconds)
    _objectHistory.removeWhere((key, history) {
      if (history.isEmpty) return true;
      return now.difference(history.last.timestamp) > const Duration(seconds: 2);
    });
    
    // Clean up old warnings
    _activeWarnings.removeWhere((_, time) =>
      now.difference(time) > const Duration(seconds: 10)
    );
    
    return warnings;
  }
  
  /// Calculate velocity vector (normalized units per second)
  _Velocity? _calculateVelocity(List<_PositionSample> history) {
    if (history.length < 2) return null;
    
    // Use first and last samples for velocity
    final first = history.first;
    final last = history.last;
    final dt = last.timestamp.difference(first.timestamp).inMilliseconds / 1000.0;
    
    if (dt < 0.1) return null; // Too short interval
    
    final vx = (last.centerX - first.centerX) / dt;
    final vy = (last.centerY - first.centerY) / dt;
    final speed = math.sqrt(vx * vx + vy * vy);
    
    if (speed < _minVelocity) return null; // Too slow to be relevant
    
    return _Velocity(vx: vx, vy: vy, speed: speed);
  }
  
  /// Check if object is approaching (getting larger in frame)
  bool _isApproaching(List<_PositionSample> history) {
    if (history.length < 3) return false;
    
    // Compare area of first third and last third of samples
    final thirdLen = history.length ~/ 3;
    if (thirdLen < 1) return false;
    
    final earlyArea = history.sublist(0, thirdLen)
        .map((s) => s.area).reduce((a, b) => a + b) / thirdLen;
    final lateArea = history.sublist(history.length - thirdLen)
        .map((s) => s.area).reduce((a, b) => a + b) / thirdLen;
    
    // Object is approaching if it's getting bigger
    return lateArea > earlyArea * _sizeGrowthThreshold;
  }
  
  /// Estimate time-to-collision in seconds
  double? _estimateTimeToCollision(
    List<_PositionSample> history,
    _Velocity velocity,
  ) {
    final last = history.last;
    
    // Distance to center zone
    final distToCenter = (last.centerX - 0.5).abs();
    
    // If already in center zone and approaching, TTC is based on size growth
    if (distToCenter < _collisionZoneThreshold) {
      // Estimate from size growth rate
      if (history.length >= 3) {
        final first = history[history.length - 3];
        final dt = last.timestamp.difference(first.timestamp).inMilliseconds / 1000.0;
        if (dt > 0 && last.area > first.area) {
          final growthRate = (last.area - first.area) / dt;
          if (growthRate > 0) {
            // Rough estimate: collision when area doubles
            final remainingGrowth = last.area; // needs to grow by this much more
            return remainingGrowth / growthRate;
          }
        }
      }
    }
    
    // TTC from lateral movement toward center
    if (velocity.vx.abs() > _minVelocity) {
      final distX = (0.5 - last.centerX);
      // Check if moving toward center
      if ((distX > 0 && velocity.vx > 0) || (distX < 0 && velocity.vx < 0)) {
        return distX.abs() / velocity.vx.abs();
      }
    }
    
    return null;
  }
  
  /// Determine approach direction
  String _getApproachDirection(_Velocity velocity, double currentX) {
    if (currentX < 0.35) return 'from the left';
    if (currentX > 0.65) return 'from the right';
    if (velocity.vy > 0) return 'from ahead';
    return 'nearby';
  }
  
  /// Build human-readable warning message
  String _buildWarningMessage(
    String objectName,
    String direction,
    CollisionUrgency urgency,
  ) {
    if (urgency == CollisionUrgency.critical) {
      return 'Warning! $objectName approaching fast $direction!';
    }
    return 'Moving $objectName approaching $direction.';
  }
  
  /// Generate a unique key for tracking an object
  String _objectKey(Detection detection) {
    // Use class name + approximate position zone for uniqueness
    final zoneX = (detection.boundingBox.centerX / 100).round();
    final zoneY = (detection.boundingBox.centerY / 100).round();
    return '${detection.className}_${zoneX}_$zoneY';
  }
  
  /// Enable/disable collision warnings
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _objectHistory.clear();
      _activeWarnings.clear();
    }
    notifyListeners();
  }
  
  /// Clear all tracking data
  void clearHistory() {
    _objectHistory.clear();
    _activeWarnings.clear();
  }
}

/// Collision warning urgency levels
enum CollisionUrgency {
  warning,   // 2-3 seconds to collision
  critical,  // < 1.5 seconds to collision
}

/// A collision warning result
class CollisionWarning {
  final String objectName;
  final String direction;
  final double timeToCollision;
  final CollisionUrgency urgency;
  final String message;
  
  CollisionWarning({
    required this.objectName,
    required this.direction,
    required this.timeToCollision,
    required this.urgency,
    required this.message,
  });
}

/// Internal position sample
class _PositionSample {
  final double centerX;
  final double centerY;
  final double area;
  final DateTime timestamp;
  
  _PositionSample({
    required this.centerX,
    required this.centerY,
    required this.area,
    required this.timestamp,
  });
}

/// Internal velocity vector
class _Velocity {
  final double vx;
  final double vy;
  final double speed;
  
  _Velocity({required this.vx, required this.vy, required this.speed});
}
