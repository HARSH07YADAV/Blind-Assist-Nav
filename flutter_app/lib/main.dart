import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/camera_service.dart';
import 'services/onnx_service.dart';
import 'services/tts_service.dart';
import 'services/haptic_service.dart';
import 'services/settings_service.dart';
import 'services/history_service.dart';
import 'services/emergency_service.dart';
import 'services/voice_command_service.dart';
import 'services/tracking_service.dart';
import 'services/background_service.dart';
import 'services/navigation_guidance_service.dart';
import 'services/accessibility_activation_service.dart';
import 'services/ocr_service.dart';
import 'services/context_service.dart';
import 'services/currency_service.dart';
import 'services/learning_service.dart';
import 'services/feedback_service.dart';
import 'services/earcon_service.dart';
import 'services/wake_word_service.dart';
import 'services/conversation_flow_service.dart';
import 'services/depth_estimation_service.dart';
import 'services/scene_classification_service.dart';
import 'services/traffic_detection_service.dart';
import 'services/landmark_service.dart';
import 'services/path_memory_service.dart';
// Week 5: Safety & Emergency
import 'services/fall_detection_service.dart';
import 'services/collision_warning_service.dart';
import 'services/offline_mode_service.dart';
// Week 6: Accessibility & Onboarding
import 'services/onboarding_service.dart';
import 'services/tutorial_service.dart';
import 'services/personalization_wizard_service.dart';
// Week 8: Advanced features
import 'services/face_recognition_service.dart';
import 'services/indoor_navigation_service.dart';
import 'services/daily_summary_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const Color vmTeal      = Color(0xFF00E5CC);
const Color vmTealDark  = Color(0xFF00BFA5);
const Color vmBg        = Color(0xFF050D14);
const Color vmSurface   = Color(0xFF0A1A26);
const Color vmBorder    = Color(0x3D00E5CC); // teal 24%
const Color vmCard      = Color(0x0DFFFFFF); // white 5%
const Color vmDim       = Color(0x99FFFFFF); // white 60%
// ────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Transparent status bar, light icons
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const VisionMateApp());
}

class VisionMateApp extends StatelessWidget {
  const VisionMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => CameraService()),
        ChangeNotifierProvider(create: (_) => OnnxService()),
        ChangeNotifierProvider(create: (_) => TTSService()),
        ChangeNotifierProvider(create: (_) => HapticService()),
        ChangeNotifierProvider(create: (_) => HistoryService()),
        ChangeNotifierProvider(create: (_) => EmergencyService()),
        ChangeNotifierProvider(create: (_) => VoiceCommandService()),
        ChangeNotifierProvider(create: (_) => TrackingService()),
        ChangeNotifierProvider(create: (_) => BackgroundService()),
        ChangeNotifierProvider(create: (_) => NavigationGuidanceService()),
        ChangeNotifierProvider(create: (_) => AccessibilityActivationService()),
        ChangeNotifierProvider(create: (_) => OcrService()),
        ChangeNotifierProvider(create: (_) => ContextService()),
        ChangeNotifierProvider(create: (_) => CurrencyService()),
        ChangeNotifierProvider(create: (_) => LearningService()),
        ChangeNotifierProvider(create: (_) => FeedbackService()),
        ChangeNotifierProvider(create: (_) => EarconService()),
        ChangeNotifierProvider(create: (_) => WakeWordService()),
        ChangeNotifierProvider(create: (_) => ConversationFlowService()),
        // Week 4: Smarter Detection & Navigation
        ChangeNotifierProvider(create: (_) => DepthEstimationService()),
        ChangeNotifierProvider(create: (_) => SceneClassificationService()),
        ChangeNotifierProvider(create: (_) => TrafficDetectionService()),
        ChangeNotifierProvider(create: (_) => LandmarkService()),
        ChangeNotifierProvider(create: (_) => PathMemoryService()),
        // Week 5: Safety & Emergency
        ChangeNotifierProvider(create: (_) => FallDetectionService()),
        ChangeNotifierProvider(create: (_) => CollisionWarningService()),
        ChangeNotifierProvider(create: (_) => OfflineModeService()),
        // Week 6: Accessibility & Onboarding
        ChangeNotifierProvider(create: (_) => OnboardingService()),
        ChangeNotifierProvider(create: (_) => TutorialService()),
        ChangeNotifierProvider(create: (_) => PersonalizationWizardService()),
        // Week 8: Advanced Features
        ChangeNotifierProvider(create: (_) => FaceRecognitionService()),
        ChangeNotifierProvider(create: (_) => IndoorNavigationService()),
        ChangeNotifierProxyProvider<HistoryService, DailySummaryService>(
          create: (context) => DailySummaryService(
            historyService: context.read<HistoryService>(),
          ),
          update: (_, history, previous) => previous ?? DailySummaryService(
            historyService: history,
          ),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'VisionMate',
            debugShowCheckedModeBanner: false,
            theme: settings.highContrast 
              ? _highContrastTheme()
              : _defaultTheme(),
            home: const PermissionWrapper(),
            routes: {
              '/settings': (context) => const SettingsScreen(),
              '/history': (context) => const HistoryScreen(),
            },
          );
        },
      ),
    );
  }

  ThemeData _defaultTheme() {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: vmBg,
      colorScheme: const ColorScheme.dark(
        primary:         vmTeal,
        onPrimary:       Colors.black,
        secondary:       vmTealDark,
        onSecondary:     Colors.black,
        surface:         vmSurface,
        onSurface:       Colors.white,
        error:           Color(0xFFFF4F4F),
        onError:         Colors.white,
      ),
      textTheme: base.copyWith(
        bodyLarge:   base.bodyLarge?.copyWith(color: Colors.white, fontSize: 18),
        bodyMedium:  base.bodyMedium?.copyWith(color: vmDim, fontSize: 15),
        titleLarge:  base.titleLarge?.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        labelSmall:  base.labelSmall?.copyWith(color: vmTeal, letterSpacing: 1.5),
      ),
      cardTheme: CardThemeData(
        color:        vmCard,
        elevation:    0,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: vmBorder, width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? vmTeal : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? vmTeal.withAlpha(80)
              : Colors.grey.withAlpha(50),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor:   vmTeal,
        thumbColor:         vmTeal,
        inactiveTrackColor: vmBorder,
        overlayColor:       Color(0x2900E5CC),
      ),
      dividerTheme: const DividerThemeData(
        color:     vmBorder,
        thickness: 1,
        space:     32,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:     Colors.transparent,
        elevation:           0,
        centerTitle:         false,
        foregroundColor:     Colors.white,
        titleTextStyle:      GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor:             Colors.transparent,
          statusBarIconBrightness:    Brightness.light,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: vmSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: vmBorder),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor:  vmSurface,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior:         SnackBarBehavior.floating,
        shape:            RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  ThemeData _highContrastTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary:   Colors.yellow,
        onPrimary: Colors.black,
        secondary: Colors.cyan,
        onSecondary: Colors.black,
        surface:   Colors.black,
        onSurface: Colors.white,
        error:     Colors.red,
        onError:   Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge:  TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 18, color: Colors.white),
        titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.yellow),
      ),
    );
  }
}

/// Handles permission requests before showing main screen
class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _permissionsGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request all needed permissions
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();
    
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    
    setState(() {
      _permissionsGranted = cameraGranted;
      _checking = false;
    });
    
    if (_permissionsGranted) {
      // Initialize settings
      if (mounted) {
        await context.read<SettingsService>().initialize();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: vmBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: vmCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: vmBorder, width: 1.5),
                ),
                child: const Icon(Icons.remove_red_eye_outlined, color: vmTeal, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'VisionMate',
                style: GoogleFonts.inter(
                  fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI Navigation for the Blind',
                style: GoogleFonts.inter(fontSize: 14, color: vmDim, letterSpacing: 1.5),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  color: vmTeal, strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing systems...',
                style: GoogleFonts.inter(fontSize: 14, color: vmDim),
              ),
            ],
          ),
        ),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        backgroundColor: vmBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: vmCard,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: vmBorder, width: 1.5),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, size: 48, color: vmTeal),
                ),
                const SizedBox(height: 32),
                Text(
                  'Camera Permission Required',
                  style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'VisionMate needs camera access to detect obstacles and help you navigate safely.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, color: vmDim, height: 1.6),
                ),
                const SizedBox(height: 48),
                Semantics(
                  button: true,
                  label: 'Grant camera permission',
                  child: SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: ElevatedButton.icon(
                      onPressed: _checkPermissions,
                      icon: const Icon(Icons.check_circle_outline, size: 28),
                      label: Text(
                        'Grant Permission',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: vmTeal,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
