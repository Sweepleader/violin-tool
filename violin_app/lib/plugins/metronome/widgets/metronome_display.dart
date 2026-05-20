import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MetronomeDisplay extends StatelessWidget {
  final int bpm;
  final bool active;
  final int beatIndex;
  final int beatsPerMeasure;

  const MetronomeDisplay({
    super.key,
    required this.bpm,
    required this.active,
    this.beatIndex = 0,
    this.beatsPerMeasure = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _MetronomePainter(
          active: active,
          beatIndex: beatIndex,
          beatsPerMeasure: beatsPerMeasure,
        ),
      ),
    );
  }
}

class _MetronomePainter extends CustomPainter {
  final bool active;
  final int beatIndex;
  final int beatsPerMeasure;

  _MetronomePainter({
    required this.active,
    required this.beatIndex,
    required this.beatsPerMeasure,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background circle
    canvas.drawCircle(center, radius,
        Paint()..color = Colors.grey.withAlpha(51));

    // Beat dots
    for (int i = 0; i < beatsPerMeasure; i++) {
      final angle = -pi / 2 + (2 * pi * i / beatsPerMeasure);
      final dotCenter = Offset(
        center.dx + (radius - 16) * cos(angle),
        center.dy + (radius - 16) * sin(angle),
      );
      final isCurrentBeat = active && i == beatIndex;
      canvas.drawCircle(
        dotCenter,
        isCurrentBeat ? 8 : 4,
        Paint()
          ..color = isCurrentBeat
              ? AppColors.pitchInTune
              : Colors.grey.withAlpha(128),
      );
    }

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: active ? '${beatIndex + 1}' : '●',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: active ? AppColors.primary : Colors.grey,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(_MetronomePainter old) =>
      active != old.active || beatIndex != old.beatIndex;
}
