import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PitchDisplay extends StatelessWidget {
  final double frequency;
  final String noteName;
  final double centsDeviation;

  const PitchDisplay({
    super.key,
    required this.frequency,
    required this.noteName,
    required this.centsDeviation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _PitchMeterPainter(
          centsDeviation: centsDeviation,
          color: _deviationColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                noteName,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _deviationColor,
                ),
              ),
              Text(
                '${frequency.toStringAsFixed(1)} Hz',
                style: theme.textTheme.bodyLarge,
              ),
              Text(
                _deviationText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _deviationColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _deviationColor {
    final absCents = centsDeviation.abs();
    if (absCents < 5) return AppColors.pitchInTune;
    if (absCents < 15) return AppColors.secondary;
    return centsDeviation > 0 ? AppColors.pitchSharp : AppColors.pitchFlat;
  }

  String get _deviationText {
    final absCents = centsDeviation.abs();
    if (absCents < 2) return 'In Tune';
    final direction = centsDeviation > 0 ? 'Sharp' : 'Flat';
    return '$direction ${absCents.toStringAsFixed(0)} cents';
  }
}

class _PitchMeterPainter extends CustomPainter {
  final double centsDeviation;
  final Color color;

  _PitchMeterPainter({required this.centsDeviation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final needleAngle = -pi / 2 + (centsDeviation / 50) * (pi / 3);

    final arcPaint = Paint()
      ..color = Colors.grey.withAlpha(51)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: 80),
      -pi * 5 / 6,
      pi * 2 / 3,
      false,
      arcPaint,
    );

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final sweepAngle = (centsDeviation / 50) * (pi / 3);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: 80),
      -pi / 2,
      sweepAngle.clamp(-pi / 3, pi / 3),
      false,
      activePaint,
    );

    canvas.drawCircle(
      Offset(centerX, centerY),
      6,
      Paint()..color = color,
    );

    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 3;
    final needleEndX = centerX + 70 * cos(needleAngle);
    final needleEndY = centerY + 70 * sin(needleAngle);
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(needleEndX, needleEndY),
      needlePaint,
    );
  }

  @override
  bool shouldRepaint(_PitchMeterPainter oldDelegate) =>
      centsDeviation != oldDelegate.centsDeviation ||
      color != oldDelegate.color;
}
