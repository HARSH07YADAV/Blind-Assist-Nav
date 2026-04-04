import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart' show vmTeal, vmBg, vmSurface, vmBorder, vmCard, vmDim;
import '../services/history_service.dart';

/// History screen — dark teal glassmorphism redesign.
/// All logic unchanged; only visual shell updated.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  Map<String, int> _classCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = context.read<HistoryService>();
    final entries = await history.getRecentHistory(limit: 100);
    final counts  = await history.getClassCounts(days: 7);
    setState(() {
      _entries     = entries;
      _classCounts = counts;
      _isLoading   = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vmBg,
      appBar: AppBar(
        title: Text(
          'Detection History',
          style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_sweep_outlined, color: vmDim),
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: vmTeal, strokeWidth: 2.5),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: vmCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: vmBorder),
                ),
                child: const Icon(Icons.history_rounded, size: 44, color: vmDim),
              ),
              const SizedBox(height: 20),
              Text(
                'No history yet',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Start detecting objects and they will be logged here.',
                style: GoogleFonts.inter(fontSize: 14, color: vmDim, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummary(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildEntry(_entries[i]),
          ),
        ),
      ],
    );
  }

  // ── 7-day summary strip ───────────────────────────────────────────────────
  Widget _buildSummary() {
    final topClasses = _classCounts.entries.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: vmSurface,
        border: Border(bottom: BorderSide(color: vmBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: vmTeal, letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: topClasses.map((e) {
              final color = _getClassColor(e.key);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: color.withAlpha(120)),
                ),
                child: Text(
                  '${e.key.capitalizeFirst}  ×${e.value}',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Detection entry tile ──────────────────────────────────────────────────
  Widget _buildEntry(HistoryEntry entry) {
    final color = _getClassColor(entry.className);

    return Container(
      decoration: BoxDecoration(
        color: vmCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: vmBorder),
      ),
      child: Row(
        children: [
          // Coloured left border accent
          Container(
            width: 4,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          // Avatar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(100)),
              ),
              child: Center(
                child: Text(
                  entry.className[0].toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ),
          ),
          // Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.className.capitalizeFirst,
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatTime(entry.timestamp)} · ${_formatDistance(entry.distanceMeters)}',
                    style: GoogleFonts.inter(fontSize: 12, color: vmDim),
                  ),
                ],
              ),
            ),
          ),
          // Confidence badge
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(entry.confidence * 100).toInt()}%',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _getClassColor(String className) {
    const palette = [
      vmTeal,
      Color(0xFFFF4F4F),
      Color(0xFF00E57A),
      Color(0xFFFF8C00),
      Color(0xFF8A7FFF),
      Color(0xFFFF6EC7),
      Color(0xFF4FC3F7),
    ];
    return palette[className.hashCode.abs() % palette.length];
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours  < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays   < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDistance(double? d) {
    if (d == null || d < 0) return 'Unknown distance';
    if (d < 1) return '${(d * 100).toInt()} cm';
    return '${d.toStringAsFixed(1)} m';
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear History',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Delete all detection history?',
          style: GoogleFonts.inter(color: vmDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: vmDim)),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<HistoryService>().clearAllHistory();
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4F4F),
              foregroundColor: Colors.white,
            ),
            child: Text('Clear All', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// Small String extension for display
extension _Cap on String {
  String get capitalizeFirst =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
