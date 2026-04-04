import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../main.dart' show vmTeal;

/// Overlay widget — glowing bounding boxes with pill-chip labels.
/// Matches the LinkedIn demo scene1.png aesthetic.
class DetectionOverlay extends StatelessWidget {
  final List<Detection> detections;
  final List<RiskAssessment> risks;
  final Size previewSize;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.risks,
    required this.previewSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / previewSize.width;
        final scaleY = constraints.maxHeight / previewSize.height;

        return Stack(
          children: risks.map((risk) {
            final bbox = risk.detection.boundingBox;
            final color = _getRiskColor(risk.level);
            final label =
                '${risk.detection.className} · ${risk.detection.distanceDescription}';

            return Positioned(
              left:   bbox.left   * scaleX,
              top:    bbox.top    * scaleY,
              width:  bbox.width  * scaleX,
              height: bbox.height * scaleY,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Bounding box with glow ──────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withAlpha(100),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // ── Pill-chip label at top-left ─────────────────────────
                  Positioned(
                    top: -14,
                    left: 0,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(230),
                        borderRadius: const BorderRadius.only(
                          topLeft:     Radius.circular(8),
                          topRight:    Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _getRiskColor(RiskLevel level) {
    return switch (level) {
      RiskLevel.critical => const Color(0xFFFF4F4F),
      RiskLevel.high     => const Color(0xFFFF8C00),
      RiskLevel.medium   => const Color(0xFFFFD000),
      RiskLevel.low      => vmTeal,
      RiskLevel.safe     => const Color(0xFF00E57A),
    };
  }
}
