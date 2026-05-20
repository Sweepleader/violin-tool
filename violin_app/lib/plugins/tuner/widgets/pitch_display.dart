import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/audio_engine.dart';

class PitchDisplay extends StatelessWidget {
  final List<PitchResult> history;
  static const double maxCents = 50.0;

  const PitchDisplay({super.key, required this.history});

  PitchResult get _latest => history.last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Note name + cents
        Text(
          _latest.note,
          style: _noteStyle(theme).copyWith(
            color: _deviationColor,
            fontSize: 72,
            fontWeight: FontWeight.w300,
          ),
        ),
        Text(
          '${_latest.frequency.toStringAsFixed(1)} Hz',
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          _deviationText,
          style: theme.textTheme.titleMedium?.copyWith(
            color: _deviationColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Pitch curve
        SizedBox(
          height: 120,
          child: ClipRect(
            child: CustomPaint(
              size: Size.infinite,
              painter: _PitchCurvePainter(
                history: history,
                maxCents: maxCents,
                inTuneColor: AppColors.pitchInTune,
                sharpColor: AppColors.pitchSharp,
                flatColor: AppColors.pitchFlat,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Cents scale labels
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('-${maxCents.toInt()}', style: _labelStyle(theme)),
            const SizedBox(width: 8),
            Text('0', style: _labelStyle(theme).copyWith(color: AppColors.pitchInTune)),
            const SizedBox(width: 8),
            Text('+${maxCents.toInt()}', style: _labelStyle(theme)),
          ],
        ),
      ],
    );
  }

  Color get _deviationColor {
    final absCents = _latest.centsDeviation.abs();
    if (absCents < 5) return AppColors.pitchInTune;
    if (absCents < 15) return AppColors.secondary;
    return _latest.centsDeviation > 0 ? AppColors.pitchSharp : AppColors.pitchFlat;
  }

  String get _deviationText {
    final absCents = _latest.centsDeviation.abs();
    if (absCents < 2) return 'In Tune';
    final direction = _latest.centsDeviation > 0 ? 'Sharp' : 'Flat';
    return '$direction ${absCents.toStringAsFixed(0)} cents';
  }

  TextStyle _noteStyle(ThemeData theme) =>
      theme.textTheme.displayLarge ?? const TextStyle(fontSize: 72);
  static TextStyle _labelStyle(ThemeData theme) =>
      theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
      const TextStyle(fontSize: 11, color: Colors.grey);
}

class _PitchCurvePainter extends CustomPainter {
  final List<PitchResult> history;
  final double maxCents;
  final Color inTuneColor;
  final Color sharpColor;
  final Color flatColor;

  _PitchCurvePainter({
    required this.history,
    required this.maxCents,
    required this.inTuneColor,
    required this.sharpColor,
    required this.flatColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final stepX = size.width / (history.length - 1);
    final centerY = size.height / 2;
    final scaleY = centerY / maxCents;

    // Center line (in-tune)
    final centerPaint = Paint()
      ..color = inTuneColor.withAlpha(80)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, centerY), Offset(size.width, centerY), centerPaint);

    // Data line
    final path = Path();
    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final y = centerY - (history[i].centsDeviation.clamp(-maxCents, maxCents) * scaleY);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Gradient fill below line
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, centerY);
    fillPath.lineTo(0, centerY);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          sharpColor.withAlpha(60),
          inTuneColor.withAlpha(20),
          flatColor.withAlpha(60),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(_PitchCurvePainter old) => history != old.history;
}
