import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart' show vmTeal, vmTealDark, vmBg, vmSurface, vmBorder, vmCard, vmDim;
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';
import '../services/wake_word_service.dart';
import '../services/camera_service.dart';
import '../services/onnx_service.dart';

/// Settings screen — dark teal glassmorphism redesign.
/// All logic unchanged; only visual shell updated.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ── Colour helpers ─────────────────────────────────────────────────────────
  static const _teal   = vmTeal;
  static const _bg     = vmBg;
  static const _card   = vmCard;
  static const _border = vmBorder;
  static const _dim    = vmDim;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Speech
              _sectionHeader('Speech'),
              _buildSliderCard(
                context,
                title: 'Speech Speed',
                subtitle: _speechSpeedLabel(settings.speechRate),
                value: settings.speechRate,
                min: 0.1, max: 1.0,
                onChanged: (v) async {
                  await settings.setSpeechRate(v);
                  await context.read<TTSService>().updateSettings();
                },
              ),
              _buildSliderCard(
                context,
                title: 'Volume',
                subtitle: '${(settings.speechVolume * 100).toInt()}%',
                value: settings.speechVolume,
                min: 0.0, max: 1.0,
                onChanged: (v) async {
                  await settings.setSpeechVolume(v);
                  await context.read<TTSService>().updateSettings();
                },
              ),
              _buildSliderCard(
                context,
                title: 'Path Clear Interval',
                subtitle: '${settings.pathClearInterval} seconds',
                value: settings.pathClearInterval.toDouble(),
                min: 3, max: 30, divisions: 27,
                onChanged: (v) => settings.setPathClearInterval(v.toInt()),
              ),

              _divider(),

              // Verbosity
              _sectionHeader('Verbosity'),
              _buildVerbosityCard(context, settings),

              _divider(),

              // Language
              _sectionHeader('Language'),
              _buildLanguageCard(context, settings),

              _divider(),

              // Navigation
              _sectionHeader('Navigation'),
              _buildNavigationModeCard(context, settings),

              _divider(),

              // Detection
              _sectionHeader('Detection'),
              _buildSwitchCard(
                context,
                title: 'High Resolution',
                subtitle: 'Better accuracy, slightly slower',
                value: context.watch<CameraService>().isHighResolution,
                onChanged: (v) => context.read<CameraService>().setHighResolution(v),
              ),

              _divider(),

              // Accessibility
              _sectionHeader('Accessibility'),
              _buildSwitchCard(
                context,
                title: 'High Contrast Mode',
                subtitle: 'Yellow on black for low vision',
                value: settings.highContrast,
                onChanged: (v) => settings.setHighContrast(v),
              ),
              _buildSwitchCard(
                context,
                title: 'Vibration Feedback',
                subtitle: 'Haptic alerts for obstacles',
                value: settings.vibrationEnabled,
                onChanged: (v) => settings.setVibrationEnabled(v),
              ),
              _buildSwitchCard(
                context,
                title: 'Voice Commands',
                subtitle: 'Control app entirely by voice',
                value: settings.voiceCommandsEnabled,
                onChanged: (v) => settings.setVoiceCommandsEnabled(v),
              ),

              _divider(),

              // Emergency
              _sectionHeader('Emergency'),
              _buildEmergencyContactCard(context, settings),

              _divider(),

              // Reset
              _buildResetButton(context, settings),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: _teal, letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 28);

  // ── Glass card wrapper ─────────────────────────────────────────────────────
  Widget _glassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: child,
    );
  }

  // ── Slider card ───────────────────────────────────────────────────────────
  Widget _buildSliderCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required Function(double) onChanged,
  }) {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(subtitle,
                    style: GoogleFonts.inter(fontSize: 13, color: _dim)),
              ],
            ),
            Slider(
              value: value, min: min, max: max,
              divisions: divisions, onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  // ── Switch card ───────────────────────────────────────────────────────────
  Widget _buildSwitchCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return _glassCard(
      child: SwitchListTile(
        title: Text(title,
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(fontSize: 13, color: _dim)),
        value: value, onChanged: onChanged,
        activeColor: _teal,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // ── Verbosity card ────────────────────────────────────────────────────────
  Widget _buildVerbosityCard(BuildContext context, SettingsService settings) {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Announcement Style: ${settings.verbosityLevel.displayName}',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(settings.verbosityLevel.description,
                style: GoogleFonts.inter(fontSize: 13, color: _dim)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _vmModeBtn(context,
                    icon: Icons.volume_off_rounded, label: 'Minimal',
                    selected: settings.verbosityLevel == VerbosityLevel.minimal,
                    onTap: () => settings.setVerbosityLevel(VerbosityLevel.minimal))),
                const SizedBox(width: 8),
                Expanded(child: _vmModeBtn(context,
                    icon: Icons.volume_down_rounded, label: 'Normal',
                    selected: settings.verbosityLevel == VerbosityLevel.normal,
                    onTap: () => settings.setVerbosityLevel(VerbosityLevel.normal))),
                const SizedBox(width: 8),
                Expanded(child: _vmModeBtn(context,
                    icon: Icons.volume_up_rounded, label: 'Detailed',
                    selected: settings.verbosityLevel == VerbosityLevel.detailed,
                    onTap: () => settings.setVerbosityLevel(VerbosityLevel.detailed))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Language card ─────────────────────────────────────────────────────────
  Widget _buildLanguageCard(BuildContext context, SettingsService settings) {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Language: ${settings.language.displayName}',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Changes voice commands and speech output',
              style: GoogleFonts.inter(fontSize: 13, color: _dim),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: AppLanguage.values.length,
              itemBuilder: (context, i) {
                final lang = AppLanguage.values[i];
                final sel  = settings.language == lang;
                return GestureDetector(
                  onTap: () {
                    settings.setLanguage(lang);
                    context.read<TTSService>().setLanguage(lang);
                    context.read<VoiceCommandService>().setListeningLocale(lang.localeCode);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? _teal.withAlpha(30) : _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? _teal : _border,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      lang.displayName.split(' (').first,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? _teal : Colors.white70,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              '💡 Install language TTS voices in phone Settings → Text-to-Speech',
              style: GoogleFonts.inter(fontSize: 11, color: _dim),
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation mode card ──────────────────────────────────────────────────
  Widget _buildNavigationModeCard(BuildContext context, SettingsService settings) {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Navigation Mode',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _vmModeBtn(context,
                    icon: Icons.home_outlined, label: 'Indoor',
                    selected: settings.navigationMode == AppNavigationMode.indoor,
                    onTap: () => settings.setNavigationMode(AppNavigationMode.indoor))),
                const SizedBox(width: 12),
                Expanded(child: _vmModeBtn(context,
                    icon: Icons.directions_walk_rounded, label: 'Outdoor',
                    selected: settings.navigationMode == AppNavigationMode.outdoor,
                    onTap: () => settings.setNavigationMode(AppNavigationMode.outdoor))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode toggle button ────────────────────────────────────────────────────
  Widget _vmModeBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _teal.withAlpha(30) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _teal : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: selected ? _teal : Colors.white54),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? _teal : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Emergency contact card ────────────────────────────────────────────────
  Widget _buildEmergencyContactCard(BuildContext context, SettingsService settings) {
    return _glassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0x1FFF4F4F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x50FF4F4F)),
          ),
          child: const Icon(Icons.emergency_rounded, color: Color(0xFFFF4F4F), size: 22),
        ),
        title: Text('Emergency Contact',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        subtitle: Text(
          settings.emergencyContact.isEmpty ? 'Not set — tap to add' : settings.emergencyContact,
          style: GoogleFonts.inter(
              fontSize: 13, color: settings.emergencyContact.isEmpty ? const Color(0xFFFF4F4F) : _dim),
        ),
        trailing: const Icon(Icons.edit_outlined, color: vmTeal, size: 20),
        onTap: () => _showContactDialog(context, settings),
      ),
    );
  }

  void _showContactDialog(BuildContext context, SettingsService settings) {
    final controller = TextEditingController(text: settings.emergencyContact);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Emergency Contact',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Phone Number',
            labelStyle: GoogleFonts.inter(color: _dim),
            hintText: '+91 XXXXX XXXXX',
            hintStyle: GoogleFonts.inter(color: _dim),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: vmBorder),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: vmTeal, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: _dim)),
          ),
          ElevatedButton(
            onPressed: () {
              settings.setEmergencyContact(controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: vmTeal, foregroundColor: Colors.black,
            ),
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Reset button ──────────────────────────────────────────────────────────
  Widget _buildResetButton(BuildContext context, SettingsService settings) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: () async {
          await settings.resetToDefaults();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings reset to defaults')),
            );
          }
        },
        icon: const Icon(Icons.refresh_rounded, color: vmDim),
        label: Text('Reset to Defaults',
            style: GoogleFonts.inter(color: vmDim, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: vmBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  String _speechSpeedLabel(double rate) {
    if (rate < 0.3) return 'Slow';
    if (rate < 0.5) return 'Normal';
    if (rate < 0.7) return 'Fast';
    return 'Very Fast';
  }
}
