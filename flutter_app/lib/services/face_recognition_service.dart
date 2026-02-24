import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Week 8: On-device face recognition with voice-assigned labels
/// Uses ML Kit for detection and cosine similarity on simplified embeddings
class FaceRecognitionService extends ChangeNotifier {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  /// Stored face profiles: name → embedding vector
  final Map<String, List<double>> _faceProfiles = {};
  static const int maxProfiles = 20;
  static const double _recognitionThreshold = 0.75;
  static const String _storageKey = 'face_profiles';

  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _lastRecognizedFace;
  DateTime? _lastRecognitionTime;

  // Callbacks
  Function(String message)? onSpeak;
  Function(String name, String position)? onFaceRecognized;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String? get lastRecognizedFace => _lastRecognizedFace;
  List<String> get savedFaces => _faceProfiles.keys.toList();
  int get savedFaceCount => _faceProfiles.length;

  /// Initialize — load saved face profiles
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final Map<String, dynamic> data = jsonDecode(json);
        for (final entry in data.entries) {
          _faceProfiles[entry.key] =
              (entry.value as List).map((e) => (e as num).toDouble()).toList();
        }
      }
      _isInitialized = true;
      debugPrint('[FaceRec] Initialized with ${_faceProfiles.length} profiles');
    } catch (e) {
      debugPrint('[FaceRec] Init error: $e');
      _isInitialized = true; // Still mark as initialized
    }
  }

  /// Process an input image for face detection + recognition
  Future<List<RecognizedFace>> processImage(InputImage inputImage) async {
    if (!_isInitialized || _isProcessing) return [];
    _isProcessing = true;

    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        _isProcessing = false;
        return [];
      }

      final results = <RecognizedFace>[];
      for (final face in faces) {
        final embedding = _extractEmbedding(face);
        final match = _findBestMatch(embedding);

        final position = _getFacePosition(face, inputImage);
        final result = RecognizedFace(
          name: match?.name,
          confidence: match?.confidence ?? 0,
          position: position,
          boundingBox: face.boundingBox,
          isSmiling: face.smilingProbability != null &&
              face.smilingProbability! > 0.5,
        );
        results.add(result);

        // Announce recognized face (with cooldown)
        if (match != null && match.confidence >= _recognitionThreshold) {
          _announceRecognition(match.name, position);
        }
      }

      _isProcessing = false;
      notifyListeners();
      return results;
    } catch (e) {
      debugPrint('[FaceRec] Process error: $e');
      _isProcessing = false;
      return [];
    }
  }

  /// Extract a simplified embedding from face landmarks
  /// Uses landmark positions, head angles, and proportions as a feature vector
  List<double> _extractEmbedding(Face face) {
    final embedding = <double>[];

    // Head rotation angles (normalized)
    embedding.add((face.headEulerAngleX ?? 0) / 90.0);
    embedding.add((face.headEulerAngleY ?? 0) / 90.0);
    embedding.add((face.headEulerAngleZ ?? 0) / 90.0);

    // Classification probabilities
    embedding.add(face.smilingProbability ?? 0);
    embedding.add(face.leftEyeOpenProbability ?? 0);
    embedding.add(face.rightEyeOpenProbability ?? 0);

    // Face proportions from bounding box
    final box = face.boundingBox;
    final aspectRatio = box.width / max(box.height, 1);
    embedding.add(aspectRatio);

    // Landmark-based features (relative positions within face bounding box)
    final landmarks = <FaceLandmarkType>[
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.bottomMouth,
      FaceLandmarkType.leftEar,
      FaceLandmarkType.rightEar,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
    ];

    for (final type in landmarks) {
      final landmark = face.landmarks[type];
      if (landmark != null) {
        // Normalize to face bounding box
        final nx = (landmark.position.x - box.left) / max(box.width, 1);
        final ny = (landmark.position.y - box.top) / max(box.height, 1);
        embedding.addAll([nx, ny]);
      } else {
        embedding.addAll([0.0, 0.0]);
      }
    }

    // Inter-landmark distances (key face geometry)
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final mouth = face.landmarks[FaceLandmarkType.bottomMouth];

    if (leftEye != null && rightEye != null) {
      final eyeDistance = _distance(leftEye.position, rightEye.position);
      embedding.add(eyeDistance / max(box.width, 1));
    } else {
      embedding.add(0);
    }

    if (nose != null && mouth != null) {
      final noseMouthDist = _distance(nose.position, mouth.position);
      embedding.add(noseMouthDist / max(box.height, 1));
    } else {
      embedding.add(0);
    }

    if (leftEye != null && nose != null) {
      final eyeNoseDist = _distance(leftEye.position, nose.position);
      embedding.add(eyeNoseDist / max(box.height, 1));
    } else {
      embedding.add(0);
    }

    // Contour-based features (face shape)
    final faceContour = face.contours[FaceContourType.face];
    if (faceContour != null && faceContour.points.length >= 10) {
      // Sample 10 evenly-spaced contour points
      final step = faceContour.points.length ~/ 10;
      for (int i = 0; i < 10; i++) {
        final pt = faceContour.points[min(i * step, faceContour.points.length - 1)];
        embedding.add((pt.x - box.left) / max(box.width, 1));
        embedding.add((pt.y - box.top) / max(box.height, 1));
      }
    } else {
      // Pad with zeros
      for (int i = 0; i < 20; i++) {
        embedding.add(0);
      }
    }

    return embedding;
  }

  double _distance(Point<int> a, Point<int> b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  /// Find the best matching stored profile
  _FaceMatch? _findBestMatch(List<double> embedding) {
    if (_faceProfiles.isEmpty) return null;

    String? bestName;
    double bestSimilarity = 0;

    for (final entry in _faceProfiles.entries) {
      final similarity = _cosineSimilarity(embedding, entry.value);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestName = entry.key;
      }
    }

    if (bestName != null && bestSimilarity >= _recognitionThreshold) {
      return _FaceMatch(name: bestName, confidence: bestSimilarity);
    }
    return null;
  }

  /// Cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      // Pad the shorter one with zeros
      final maxLen = max(a.length, b.length);
      while (a.length < maxLen) {
        a.add(0);
      }
      while (b.length < maxLen) {
        b.add(0);
      }
    }

    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }

    final magnitude = sqrt(magA) * sqrt(magB);
    if (magnitude == 0) return 0;
    return dot / magnitude;
  }

  /// Get face position relative to frame
  String _getFacePosition(Face face, InputImage inputImage) {
    final box = face.boundingBox;
    final frameWidth = inputImage.metadata?.size.width ?? 640;
    final centerX = box.center.dx / frameWidth;

    if (centerX < 0.33) return 'to your left';
    if (centerX > 0.67) return 'to your right';
    return 'ahead';
  }

  /// Announce recognized face with cooldown
  void _announceRecognition(String name, String position) {
    final now = DateTime.now();
    if (_lastRecognizedFace == name &&
        _lastRecognitionTime != null &&
        now.difference(_lastRecognitionTime!) < const Duration(seconds: 10)) {
      return; // Cooldown active
    }

    _lastRecognizedFace = name;
    _lastRecognitionTime = now;
    onSpeak?.call('$name is $position');
    onFaceRecognized?.call(name, position);
    debugPrint('[FaceRec] Recognized: $name ($position)');
  }

  /// Save a face with a voice-assigned label
  /// Call this when user says "Remember this face as [name]"
  Future<bool> saveFace(String name, InputImage inputImage) async {
    if (_faceProfiles.length >= maxProfiles) {
      onSpeak?.call('Maximum $maxProfiles faces stored. '
          'Say "forget" followed by a name to remove one.');
      return false;
    }

    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        onSpeak?.call('No face detected. Please look at the camera.');
        return false;
      }
      if (faces.length > 1) {
        onSpeak?.call(
            'Multiple faces detected. Please ensure only one person is visible.');
        return false;
      }

      final embedding = _extractEmbedding(faces.first);
      _faceProfiles[name.toLowerCase()] = embedding;
      await _saveProfiles();

      onSpeak?.call('Face saved as $name. I will recognize them next time.');
      debugPrint('[FaceRec] Saved face: $name');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[FaceRec] Save error: $e');
      onSpeak?.call('Could not save face. Please try again.');
      return false;
    }
  }

  /// Remove a saved face by name
  Future<bool> forgetFace(String name) async {
    final key = name.toLowerCase();
    if (!_faceProfiles.containsKey(key)) {
      onSpeak?.call('No saved face named $name.');
      return false;
    }

    _faceProfiles.remove(key);
    await _saveProfiles();
    onSpeak?.call('Forgotten $name.');
    debugPrint('[FaceRec] Removed face: $name');
    notifyListeners();
    return true;
  }

  /// List all saved faces via voice
  void listFaces() {
    if (_faceProfiles.isEmpty) {
      onSpeak?.call('No faces saved yet. '
          'Say "remember this face as" followed by a name to save one.');
      return;
    }

    final names = _faceProfiles.keys.join(', ');
    onSpeak?.call(
        '${_faceProfiles.length} faces saved: $names');
  }

  /// Persist profiles to SharedPreferences
  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, List<double>>{};
      for (final entry in _faceProfiles.entries) {
        data[entry.key] = entry.value;
      }
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[FaceRec] Save profiles error: $e');
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}

/// A recognized face result
class RecognizedFace {
  final String? name;
  final double confidence;
  final String position;
  final Rect boundingBox;
  final bool isSmiling;

  RecognizedFace({
    this.name,
    required this.confidence,
    required this.position,
    required this.boundingBox,
    this.isSmiling = false,
  });

  bool get isKnown => name != null && confidence >= 0.75;

  String get announcement {
    if (isKnown) {
      return '$name is $position${isSmiling ? ', smiling' : ''}';
    }
    return 'Unknown person $position';
  }
}

/// Internal match result
class _FaceMatch {
  final String name;
  final double confidence;

  _FaceMatch({required this.name, required this.confidence});
}
