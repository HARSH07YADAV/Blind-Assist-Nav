import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../models/detection.dart';

/// Traffic Detection Service — Week 4, Day 4
/// 
/// Safety-critical service for road crossing:
/// - Traffic light color/state classification by sampling bounding box pixels
/// - Crosswalk detection using horizontal stripe pattern analysis
/// - High-priority safety announcements
class TrafficDetectionService extends ChangeNotifier {
  TrafficLightState _currentLightState = TrafficLightState.unknown;
  bool _crosswalkDetected = false;
  DateTime _lastTrafficAnnouncement = DateTime.now();
  DateTime _lastCrosswalkTime = DateTime.now();
  
  // Cooldowns to avoid spamming
  static const Duration _trafficAnnounceCooldown = Duration(seconds: 3);
  static const Duration _crosswalkAnnounceCooldown = Duration(seconds: 5);
  
  // Getters
  TrafficLightState get currentLightState => _currentLightState;
  bool get crosswalkDetected => _crosswalkDetected;
  
  /// Analyze detected traffic lights and determine their state
  /// 
  /// YOLOv8n detects "traffic light" (class 9). This method samples
  /// the dominant color in the bounding box region to determine red/green/yellow.
  TrafficLightState analyzeTrafficLight(
    Detection trafficLightDetection,
    CameraImage image,
  ) {
    try {
      final box = trafficLightDetection.boundingBox;
      final y = image.planes[0].bytes;
      final u = image.planes[1].bytes;
      final v = image.planes[2].bytes;
      final yStride = image.planes[0].bytesPerRow;
      final uvStride = image.planes[1].bytesPerRow;
      final uvPixel = image.planes[1].bytesPerPixel ?? 1;
      
      // Sample colors from the bounding box region
      int redCount = 0;
      int greenCount = 0;
      int yellowCount = 0;
      int totalSamples = 0;
      
      // Divide the traffic light box into thirds (top=red, mid=yellow, bottom=green)
      final boxTop = box.top.toInt().clamp(0, image.height - 1);
      final boxBottom = box.bottom.toInt().clamp(0, image.height - 1);
      final boxLeft = box.left.toInt().clamp(0, image.width - 1);
      final boxRight = box.right.toInt().clamp(0, image.width - 1);
      final boxHeight = boxBottom - boxTop;
      
      if (boxHeight < 10) return TrafficLightState.unknown;
      
      // Sample points in the bounding box
      for (int row = boxTop; row < boxBottom; row += 3) {
        for (int col = boxLeft; col < boxRight; col += 3) {
          final yIdx = row * yStride + col;
          if (yIdx >= y.length) continue;
          
          final uvRow = row ~/ 2;
          final uvCol = col ~/ 2;
          final uvIdx = uvRow * uvStride + uvCol * uvPixel;
          if (uvIdx >= u.length || uvIdx >= v.length) continue;
          
          final yVal = y[yIdx];
          final uVal = u[uvIdx];
          final vVal = v[uvIdx];
          
          // Convert YUV to RGB
          final r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255);
          final g = (yVal - 0.344 * (uVal - 128) - 0.714 * (vVal - 128)).clamp(0, 255);
          final b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255);
          
          // Brightness threshold — only count bright pixels (the lit lamp)
          final brightness = (r + g + b) / 3;
          if (brightness < 80) continue;
          
          totalSamples++;
          
          // Classify color
          if (r > 150 && g < 100 && b < 100) {
            redCount++;
          } else if (g > 120 && r < 100 && b < 100) {
            greenCount++;
          } else if (r > 150 && g > 120 && b < 80) {
            yellowCount++;
          }
        }
      }
      
      if (totalSamples < 5) return TrafficLightState.unknown;
      
      // Determine dominant color
      final maxCount = math.max(redCount, math.max(greenCount, yellowCount));
      
      TrafficLightState newState;
      if (maxCount == 0) {
        newState = TrafficLightState.unknown;
      } else if (maxCount == redCount) {
        newState = TrafficLightState.red;
      } else if (maxCount == greenCount) {
        newState = TrafficLightState.green;
      } else {
        newState = TrafficLightState.yellow;
      }
      
      if (newState != _currentLightState) {
        _currentLightState = newState;
        notifyListeners();
        debugPrint('[Traffic] Light state: ${_currentLightState.name} '
            '(R:$redCount G:$greenCount Y:$yellowCount / $totalSamples samples)');
      }
      
      return _currentLightState;
    } catch (e) {
      debugPrint('[Traffic] Analysis error: $e');
      return TrafficLightState.unknown;
    }
  }
  
  /// Detect crosswalk by looking for horizontal stripe patterns
  /// Similar approach to stairs detection but in the lower-middle frame region
  bool detectCrosswalk(CameraImage image) {
    try {
      final y = image.planes[0].bytes;
      final width = image.width;
      final height = image.height;
      final stride = image.planes[0].bytesPerRow;
      
      // Check the middle-bottom portion of the frame (where crosswalk would be)
      final startY = height ~/ 2;
      final endY = height * 4 ~/ 5;
      
      int stripeTransitions = 0;
      
      // Look for alternating bright/dark horizontal bands
      for (int col = width ~/ 4; col < width * 3 ~/ 4; col += 8) {
        bool lastWasBright = false;
        int transitions = 0;
        
        for (int row = startY; row < endY; row += 4) {
          final idx = row * stride + col;
          if (idx >= y.length) continue;
          
          final brightness = y[idx];
          final isBright = brightness > 160; // White stripe threshold
          
          if (isBright != lastWasBright && row > startY) {
            transitions++;
          }
          lastWasBright = isBright;
        }
        
        // Crosswalk has multiple stripe transitions (4+ = likely crosswalk)
        if (transitions >= 4) {
          stripeTransitions++;
        }
      }
      
      // If multiple columns show stripe patterns, it's likely a crosswalk
      final wasCrosswalk = _crosswalkDetected;
      _crosswalkDetected = stripeTransitions >= 3;
      
      if (_crosswalkDetected && !wasCrosswalk) {
        debugPrint('[Traffic] Crosswalk detected ($stripeTransitions cols with stripes)');
        notifyListeners();
      }
      
      return _crosswalkDetected;
    } catch (e) {
      debugPrint('[Traffic] Crosswalk detection error: $e');
      return false;
    }
  }
  
  /// Get safety announcement for current traffic state
  String? getTrafficAnnouncement() {
    final now = DateTime.now();
    if (now.difference(_lastTrafficAnnouncement) < _trafficAnnounceCooldown) {
      return null;
    }
    
    String? message;
    
    switch (_currentLightState) {
      case TrafficLightState.red:
        message = 'Red light detected. Wait, do not cross.';
        break;
      case TrafficLightState.green:
        message = 'Green light detected. It may be safe to cross. Be careful.';
        break;
      case TrafficLightState.yellow:
        message = 'Yellow light detected. Prepare to stop.';
        break;
      case TrafficLightState.unknown:
        break;
    }
    
    if (message != null) {
      _lastTrafficAnnouncement = now;
    }
    
    return message;
  }
  
  /// Get crosswalk announcement
  String? getCrosswalkAnnouncement() {
    if (!_crosswalkDetected) return null;
    
    final now = DateTime.now();
    if (now.difference(_lastCrosswalkTime) < _crosswalkAnnounceCooldown) {
      return null;
    }
    
    _lastCrosswalkTime = now;
    return 'Crosswalk detected ahead. Look for traffic signals before crossing.';
  }
  
  /// Check if any traffic light is detected in the detections list
  Detection? findTrafficLight(List<Detection> detections) {
    for (final d in detections) {
      if (d.className.toLowerCase() == 'traffic light') {
        return d;
      }
    }
    return null;
  }
  
  /// Reset state
  void reset() {
    _currentLightState = TrafficLightState.unknown;
    _crosswalkDetected = false;
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}

/// Traffic light state
enum TrafficLightState {
  red,
  green,
  yellow,
  unknown,
}
