import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_service.dart';

/// Week 8: End-of-day voice report with usage statistics
/// Queries HistoryService for detection stats and generates a natural language summary
class DailySummaryService extends ChangeNotifier {
  final HistoryService _historyService;

  Timer? _scheduledTimer;
  DateTime? _sessionStart;
  int _sessionCount = 0;
  double _totalSessionMinutes = 0;
  bool _isInitialized = false;

  /// Default summary time: 8:00 PM
  int _summaryHour = 20;
  int _summaryMinute = 0;

  static const String _lastSummaryKey = 'last_daily_summary';
  static const String _sessionDataKey = 'daily_session_data';

  // Callbacks
  Function(String message)? onSpeak;

  // Getters
  bool get isInitialized => _isInitialized;
  int get summaryHour => _summaryHour;

  DailySummaryService({required HistoryService historyService})
      : _historyService = historyService;

  /// Initialize and schedule the daily summary
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _summaryHour = prefs.getInt('summary_hour') ?? 20;
      _summaryMinute = prefs.getInt('summary_minute') ?? 0;

      // Load session data
      final sessionJson = prefs.getString(_sessionDataKey);
      if (sessionJson != null) {
        // Parse existing session minutes for today
        _totalSessionMinutes =
            prefs.getDouble('today_session_minutes') ?? 0;
        _sessionCount = prefs.getInt('today_session_count') ?? 0;
      }

      _scheduleSummary();
      _isInitialized = true;
      debugPrint('[DailySummary] Initialized, summary at $_summaryHour:$_summaryMinute');
    } catch (e) {
      debugPrint('[DailySummary] Init error: $e');
      _isInitialized = true;
    }
  }

  /// Record session start (when user starts detection)
  void startSession() {
    _sessionStart = DateTime.now();
    _sessionCount++;
    debugPrint('[DailySummary] Session started (#$_sessionCount)');
  }

  /// Record session end (when user stops detection)
  Future<void> endSession() async {
    if (_sessionStart != null) {
      final duration =
          DateTime.now().difference(_sessionStart!).inMinutes.toDouble();
      _totalSessionMinutes += duration;
      _sessionStart = null;
      debugPrint(
          '[DailySummary] Session ended (${duration.toInt()} min, total: ${_totalSessionMinutes.toInt()} min)');

      // Persist session data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('today_session_minutes', _totalSessionMinutes);
        await prefs.setInt('today_session_count', _sessionCount);
      } catch (e) {
        debugPrint('[DailySummary] Save session error: $e');
      }
    }
  }

  /// Schedule the daily summary at the configured time
  void _scheduleSummary() {
    _scheduledTimer?.cancel();

    final now = DateTime.now();
    var nextSummary = DateTime(
      now.year, now.month, now.day, _summaryHour, _summaryMinute,
    );

    // If the time has passed today, schedule for tomorrow
    if (nextSummary.isBefore(now)) {
      nextSummary = nextSummary.add(const Duration(days: 1));
    }

    final delay = nextSummary.difference(now);
    _scheduledTimer = Timer(delay, () {
      _deliverScheduledSummary();
      // Reschedule for tomorrow
      _scheduleSummary();
    });

    debugPrint('[DailySummary] Next summary in ${delay.inHours}h ${delay.inMinutes % 60}m');
  }

  /// Deliver the scheduled summary
  Future<void> _deliverScheduledSummary() async {
    // Check if we already delivered today
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSummary = prefs.getString(_lastSummaryKey);
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (lastSummary == today) {
        debugPrint('[DailySummary] Already delivered today');
        return;
      }

      await prefs.setString(_lastSummaryKey, today);
    } catch (e) {
      debugPrint('[DailySummary] Check error: $e');
    }

    await generateAndSpeak();
  }

  /// Generate the summary and speak it (also used by voice command)
  Future<void> generateAndSpeak() async {
    final summary = await generateSummary();
    onSpeak?.call(summary);
    debugPrint('[DailySummary] Delivered: $summary');
  }

  /// Generate a natural language summary for today
  Future<String> generateSummary() async {
    final today = DateTime.now();
    final parts = <String>[];

    // Header
    final dayName = _getDayName(today.weekday);
    parts.add("Here's your $dayName summary.");

    // Detection statistics
    try {
      final history = await _historyService.getHistoryForDate(today);
      final totalDetections = history.length;

      if (totalDetections > 0) {
        parts.add('You encountered $totalDetections objects today.');

        // Get class counts for today
        final classCounts = await _historyService.getClassCounts(days: 1);
        if (classCounts.isNotEmpty) {
          // Top 3 most common objects
          final sorted = classCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top = sorted.take(3).map(
            (e) => '${e.value} ${e.key}${e.value > 1 ? 's' : ''}',
          );
          parts.add('Most common: ${top.join(', ')}.');
        }

        // Danger analysis
        final dangerCount = history
            .where((h) =>
                h.dangerLevel == 'critical' || h.dangerLevel == 'high')
            .length;
        if (dangerCount > 0) {
          parts.add('$dangerCount high-risk detections were flagged.');
        } else {
          parts.add('No high-risk situations today. Great!');
        }
      } else {
        parts.add('No detections recorded today.');
      }
    } catch (e) {
      parts.add('Detection data is not available.');
      debugPrint('[DailySummary] History error: $e');
    }

    // Usage duration
    final totalMinutes = _totalSessionMinutes.toInt();
    if (totalMinutes > 0) {
      if (totalMinutes >= 60) {
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        parts.add(
            'You used VisionMate for about $hours hour${hours > 1 ? 's' : ''}'
            '${mins > 0 ? ' and $mins minutes' : ''}.');
      } else {
        parts.add('You used VisionMate for about $totalMinutes minutes.');
      }
      parts.add('$_sessionCount detection session${_sessionCount > 1 ? 's' : ''} today.');
    }

    // Closing
    parts.add('Stay safe. Good night!');

    return parts.join(' ');
  }

  /// Set summary delivery time
  Future<void> setSummaryTime(int hour, int minute) async {
    _summaryHour = hour;
    _summaryMinute = minute;
    _scheduleSummary();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('summary_hour', hour);
      await prefs.setInt('summary_minute', minute);
    } catch (e) {
      debugPrint('[DailySummary] Save time error: $e');
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    onSpeak?.call('Daily summary will be delivered at $displayHour:${minute.toString().padLeft(2, '0')} $period.');
    notifyListeners();
  }

  /// Reset session data (call at midnight or start of day)
  Future<void> resetDailyData() async {
    _sessionCount = 0;
    _totalSessionMinutes = 0;
    _sessionStart = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('today_session_minutes', 0);
      await prefs.setInt('today_session_count', 0);
    } catch (e) {
      debugPrint('[DailySummary] Reset error: $e');
    }
  }

  String _getDayName(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return names[weekday - 1];
  }

  @override
  void dispose() {
    _scheduledTimer?.cancel();
    super.dispose();
  }
}
