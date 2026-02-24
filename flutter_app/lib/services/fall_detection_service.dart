import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Week 5: Improved fall detection service
/// 
/// Uses accelerometer + gyroscope sensor fusion for accurate fall detection.
/// 3-phase algorithm: free-fall → impact → post-fall stillness.
/// 30-second auto-SOS countdown with voice cancel.
class FallDetectionService extends ChangeNotifier {
  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
  // State
  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _fallDetected = false;
  bool _awaitingResponse = false;
  int _countdownSeconds = 30;
  Timer? _countdownTimer;
  DateTime? _lastFallTime;
  
  // Sensor data buffers
  final List<_AccelSample> _accelHistory = [];
  final List<_GyroSample> _gyroHistory = [];
  static const int _historySize = 20; // ~1 second at 50ms sampling
  
  // Fall detection thresholds
  static const double _freeFallThreshold = 3.0;    // m/s² (gravity ~9.8, free fall ~0)
  static const double _impactThreshold = 25.0;      // m/s² impact spike
  static const double _stillnessThreshold = 2.0;    // m/s² variance for post-fall stillness
  static const double _gyroFallThreshold = 5.0;     // rad/s rapid orientation change
  static const Duration _fallCooldown = Duration(seconds: 60);
  static const int _autoSOSCountdown = 30;
  
  // Countdown voice announcement marks (seconds remaining)
  static const List<int> _announcementMarks = [25, 20, 15, 10, 5, 4, 3, 2, 1];
  
  // Fall detection phases
  bool _freeFallDetected = false;
  DateTime? _freeFallTime;
  bool _impactDetected = false;
  DateTime? _impactTime;
  
  // Callbacks
  Function? onFallDetected;
  Function(int secondsRemaining)? onCountdownTick;
  Function? onAutoSOS;
  Function? onFallCancelled;
  Function(String)? onFeedback;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  bool get fallDetected => _fallDetected;
  bool get awaitingResponse => _awaitingResponse;
  int get countdownSeconds => _countdownSeconds;
  
  /// Initialize sensor listeners
  Future<void> initialize() async {
    try {
      _accelSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen(_onAccelerometerEvent);
      
      _gyroSubscription = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen(_onGyroscopeEvent);
      
      _isInitialized = true;
      debugPrint('[FallDetection] Initialized with accel + gyro fusion');
    } catch (e) {
      debugPrint('[FallDetection] Init error: $e');
      _isInitialized = false;
    }
  }
  
  /// Handle accelerometer data
  void _onAccelerometerEvent(AccelerometerEvent event) {
    if (!_isEnabled || _awaitingResponse) return;
    
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z
    );
    
    _accelHistory.add(_AccelSample(
      magnitude: magnitude,
      x: event.x, y: event.y, z: event.z,
      timestamp: DateTime.now(),
    ));
    
    // Keep buffer size bounded
    while (_accelHistory.length > _historySize) {
      _accelHistory.removeAt(0);
    }
    
    // Run fall detection algorithm
    _detectFall();
  }
  
  /// Handle gyroscope data
  void _onGyroscopeEvent(GyroscopeEvent event) {
    if (!_isEnabled || _awaitingResponse) return;
    
    final rotationRate = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z
    );
    
    _gyroHistory.add(_GyroSample(
      rotationRate: rotationRate,
      timestamp: DateTime.now(),
    ));
    
    while (_gyroHistory.length > _historySize) {
      _gyroHistory.removeAt(0);
    }
  }
  
  /// 3-phase fall detection algorithm with sensor fusion
  void _detectFall() {
    if (_accelHistory.length < 10) return;
    
    final now = DateTime.now();
    
    // Cooldown check
    if (_lastFallTime != null && now.difference(_lastFallTime!) < _fallCooldown) {
      return;
    }
    
    final latest = _accelHistory.last;
    
    // === Phase 1: Free-fall detection ===
    // During free fall, total acceleration drops near 0 (no gravity felt)
    if (!_freeFallDetected && latest.magnitude < _freeFallThreshold) {
      _freeFallDetected = true;
      _freeFallTime = now;
      debugPrint('[FallDetection] Phase 1: Free-fall detected (accel=${latest.magnitude.toStringAsFixed(1)})');
      return;
    }
    
    // === Phase 2: Impact detection ===
    // Within 1 second of free-fall, detect sudden impact spike
    if (_freeFallDetected && !_impactDetected) {
      final timeSinceFreeFall = now.difference(_freeFallTime!);
      
      // Timeout: if no impact within 1.5s, reset
      if (timeSinceFreeFall > const Duration(milliseconds: 1500)) {
        _resetPhases();
        return;
      }
      
      if (latest.magnitude > _impactThreshold) {
        _impactDetected = true;
        _impactTime = now;
        debugPrint('[FallDetection] Phase 2: Impact detected (accel=${latest.magnitude.toStringAsFixed(1)})');
        return;
      }
    }
    
    // === Phase 3: Post-fall stillness confirmation ===
    // Within 3 seconds of impact, check for relative stillness + gyro confirmation
    if (_freeFallDetected && _impactDetected) {
      final timeSinceImpact = now.difference(_impactTime!);
      
      // Need at least 500ms after impact for stillness check
      if (timeSinceImpact < const Duration(milliseconds: 500)) return;
      
      // Timeout: if no stillness within 3s after impact, reset
      if (timeSinceImpact > const Duration(seconds: 3)) {
        _resetPhases();
        return;
      }
      
      // Check stillness: recent acceleration variance should be low
      final recentSamples = _accelHistory.where((s) => 
        now.difference(s.timestamp) < const Duration(milliseconds: 500)
      ).toList();
      
      if (recentSamples.length < 3) return;
      
      final magnitudes = recentSamples.map((s) => s.magnitude).toList();
      final maxMag = magnitudes.reduce(math.max);
      final minMag = magnitudes.reduce(math.min);
      final variance = maxMag - minMag;
      
      // Check gyroscope: confirm rapid orientation change occurred during fall
      bool gyroConfirmed = _checkGyroConfirmation();
      
      if (variance < _stillnessThreshold && gyroConfirmed) {
        debugPrint('[FallDetection] Phase 3: Stillness confirmed — FALL DETECTED');
        _onFallConfirmed();
      }
    }
  }
  
  /// Check gyroscope data for rapid orientation change during the fall event
  bool _checkGyroConfirmation() {
    if (_gyroHistory.isEmpty) {
      // If gyroscope not available, still allow fall detection via accel alone
      return true;
    }
    
    // Check if any rapid rotation occurred in the last 2 seconds
    final now = DateTime.now();
    final recentGyro = _gyroHistory.where((s) =>
      now.difference(s.timestamp) < const Duration(seconds: 2)
    );
    
    for (final sample in recentGyro) {
      if (sample.rotationRate > _gyroFallThreshold) {
        return true;
      }
    }
    
    // Allow if we don't have enough gyro data (some devices may not have gyro)
    return _gyroHistory.length < 5;
  }
  
  /// Reset detection phases
  void _resetPhases() {
    _freeFallDetected = false;
    _freeFallTime = null;
    _impactDetected = false;
    _impactTime = null;
  }
  
  /// Fall confirmed — start countdown
  void _onFallConfirmed() {
    _resetPhases();
    _lastFallTime = DateTime.now();
    _fallDetected = true;
    _awaitingResponse = true;
    _countdownSeconds = _autoSOSCountdown;
    
    // Notify callback
    onFallDetected?.call();
    onFeedback?.call('Fall detected! Say "I\'m okay" or press any button within $_countdownSeconds seconds.');
    
    // Start countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      
      // Voice announcements at specific marks
      if (_announcementMarks.contains(_countdownSeconds)) {
        onCountdownTick?.call(_countdownSeconds);
      }
      
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _awaitingResponse = false;
        _fallDetected = false;
        debugPrint('[FallDetection] Countdown expired — triggering auto-SOS');
        onAutoSOS?.call();
        notifyListeners();
      }
      
      notifyListeners();
    });
    
    notifyListeners();
  }
  
  /// User confirmed they are okay — cancel SOS
  void confirmUserOkay() {
    if (!_awaitingResponse) return;
    
    debugPrint('[FallDetection] User confirmed OK — cancelling SOS');
    _countdownTimer?.cancel();
    _awaitingResponse = false;
    _fallDetected = false;
    _accelHistory.clear();
    _gyroHistory.clear();
    
    onFallCancelled?.call();
    onFeedback?.call("Glad you're safe. SOS cancelled.");
    notifyListeners();
  }
  
  /// User confirms they need help — trigger SOS immediately
  void confirmNeedHelp() {
    if (!_awaitingResponse) return;
    
    debugPrint('[FallDetection] User needs help — triggering SOS immediately');
    _countdownTimer?.cancel();
    _awaitingResponse = false;
    _fallDetected = false;
    
    onAutoSOS?.call();
    notifyListeners();
  }
  
  /// Enable/disable fall detection
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _countdownTimer?.cancel();
      _awaitingResponse = false;
      _fallDetected = false;
      _resetPhases();
    }
    notifyListeners();
  }
  
  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

/// Accelerometer sample with timestamp
class _AccelSample {
  final double magnitude;
  final double x, y, z;
  final DateTime timestamp;
  
  _AccelSample({
    required this.magnitude,
    required this.x, required this.y, required this.z,
    required this.timestamp,
  });
}

/// Gyroscope sample with timestamp
class _GyroSample {
  final double rotationRate;
  final DateTime timestamp;
  
  _GyroSample({
    required this.rotationRate,
    required this.timestamp,
  });
}
