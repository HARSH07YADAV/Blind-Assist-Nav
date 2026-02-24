# VisionMate — Performance Benchmarks

## Benchmark Targets vs Expected Performance

| Metric | Target | Expected | Method |
|--------|--------|----------|--------|
| App startup (cold) | < 3s | ~2s | 2-phase init: camera first, services async |
| Detection latency | < 100ms | ~80ms | ONNX Runtime + compute isolate + skip frames |
| Battery usage | < 15%/hr | ~12%/hr | Adaptive FPS (3-10), pocket detection pause |
| Memory usage | < 300 MB | ~250 MB | Per-frame buffer reuse, no image copies |
| Voice command response | < 500ms | ~300ms | Speech-to-text always listening |
| TTS latency | < 200ms | ~150ms | Priority queue, skip stale announcements |
| Face recognition | < 500ms | ~400ms | ML Kit face detection + landmark embedding |
| APK size | < 100 MB | ~85 MB | ONNX model (6.3 MB) + ML Kit on-demand |

## Architecture Optimizations

### Detection Pipeline

1. Camera frame → YUV buffer (no conversion)
2. Compute isolate → ONNX inference
3. Skip frames when previous still processing
4. Adaptive FPS: 3 FPS (resting) → 10 FPS (moving, high-risk)

### Memory Management

- Single-frame buffer, no image accumulation
- Detection history capped at 7 days, auto-cleaned
- Face embeddings: ~50 floats per face × 20 max = ~4 KB

### Battery Optimization

- Pocket detection pauses camera + detection
- Background mode reduces FPS to 1
- BLE scanning on low-energy mode
- Scheduled summary uses Timer, not background worker

## Test Devices (Recommended)

| Device | Category | Android | Notes |
|--------|----------|---------|-------|
| Samsung Galaxy A13 | Budget | 12 | Test minimum specs |
| Xiaomi Redmi Note 12 | Mid-range | 13 | Most common user device |
| Samsung Galaxy S23 | Flagship | 14 | Test peak performance |
| Google Pixel 7a | Reference | 14 | Best ONNX support |
| OnePlus Nord CE3 | Mid-range | 13 | Test varied hardware |

## Known Performance Constraints

- **OCR**: Requires good lighting; low-light accuracy drops ~40%
- **Face recognition**: Works best within 1-3m distance
- **BLE scanning**: Battery impact ~2-3% per hour when active
- **Hindi TTS**: Quality varies by device; Samsung/Google best
- **Wake word**: May false-trigger in >70dB noise environments
