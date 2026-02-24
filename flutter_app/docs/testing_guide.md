# VisionMate Testing Guide

## Automated Tests

### Running Unit Tests

```bash
cd flutter_app
flutter test
```

### Test Coverage Summary

| Test File | Component | Tests |
|-----------|-----------|-------|
| `test/models/detection_model_test.dart` | Detection model, BoundingBox, DangerLevel, RiskLevel | 25+ |
| `test/core/risk_calculator_test.dart` | RiskCalculator scoring, sorting, recommendations | 15+ |
| `test/services/depth_estimation_test.dart` | DepthEstimationService distance computation | 15+ |
| `test/services/scene_classification_test.dart` | SceneClassificationService pattern matching | 15+ |
| `test/services/collision_warning_test.dart` | CollisionWarningService frame analysis | 10+ |
| `test/services/onboarding_service_test.dart` | OnboardingService tour lifecycle | 15+ |
| `test/services/tutorial_service_test.dart` | TutorialService scenario progression | 15+ |
| `test/services/personalization_wizard_test.dart` | PersonalizationWizardService setup flow | 15+ |

---

## Device Testing Checklist

### Prerequisites

- Android device with camera
- TalkBack screen reader enabled
- Headphones (for TTS validation)

### Core Feature Tests

| # | Test Case | Steps | Expected Result | Pass? |
|---|-----------|-------|-----------------|-------|
| 1 | App startup | Open app cold | Camera preview visible in < 3s | ☐ |
| 2 | Object detection | Point at chair/person | TTS announces object + distance | ☐ |
| 3 | Start/Stop | Tap Start button | Detection starts, button turns red | ☐ |
| 4 | Emergency SOS | Tap SOS button | Location SMS sent to contacts | ☐ |
| 5 | Voice: "What's ahead" | Say command | TTS lists detected objects | ☐ |
| 6 | Voice: "Find the door" | Say command | TTS announces door location | ☐ |
| 7 | Voice: "Read this" | Point at text | OCR reads text aloud | ☐ |
| 8 | Voice: "Battery status" | Say command | TTS announces battery level | ☐ |
| 9 | Wake word | Say "Hey Vision" | Microphone activates | ☐ |
| 10 | Flashlight | Tap Torch button | Camera flash toggles | ☐ |

### Accessibility Tests

| # | Test Case | Steps | Expected | Pass? |
|---|-----------|-------|----------|-------|
| 1 | TalkBack navigation | Swipe through buttons | All buttons announce labels | ☐ |
| 2 | Focus order | Tab through controls | Logical top-to-bottom order | ☐ |
| 3 | Button size | Measure touch targets | All buttons ≥ 80px | ☐ |
| 4 | High contrast | Enable in settings | Yellow-on-black theme | ☐ |
| 5 | Beginner mode | Set beginner mode | Only Start/SOS/Settings visible | ☐ |

### Safety Tests

| # | Test Case | Steps | Expected | Pass? |
|---|-----------|-------|----------|-------|
| 1 | Fall detection | Simulate drop | 30s countdown, voice "Are you okay?" | ☐ |
| 2 | Fall cancel | Say "I'm okay" | SOS cancelled | ☐ |
| 3 | Collision warning | Walk toward obstacle | TTS warning 2-3s before | ☐ |
| 4 | Offline mode | Airplane mode | Detection + TTS still work | ☐ |

---

## Blind User Testing Protocol

### Participant Criteria

- Legally blind or severely visually impaired
- Comfortable with smartphone basics
- Ages 18-65
- Mix of experienced and new assistive tech users

### Session Structure (45-60 min per user)

1. **Setup (5 min)** — Install app, brief verbal introduction
2. **Onboarding (5 min)** — Let the guided tour run, observe
3. **Free exploration (10 min)** — User explores independently
4. **Guided tasks (15 min)**:
   - "Walk to the nearest door"
   - "Find and read a sign"
   - "Navigate around 3 obstacles"
   - "Call for help using voice"
5. **Settings customization (5 min)** — Change speech speed, verbosity
6. **Debrief interview (10 min)** — Open-ended feedback

### Feedback Form

For each task, rate 1-5:

- **Clarity**: Was the announcement clear?
- **Timeliness**: Was the warning early enough?
- **Accuracy**: Was the information correct?
- **Confidence**: Did you feel safe?

Open questions:

- What was most confusing?
- What one thing would you change?
- Would you use this app daily?

---

## Known Limitations

- OCR requires good lighting and steady hand
- ≤1m depth estimation can be inaccurate for small objects
- Hindi TTS quality depends on device
- Wake word may false-trigger in noisy environments
- Fall detection may trigger on sudden phone movements (not actual falls)
