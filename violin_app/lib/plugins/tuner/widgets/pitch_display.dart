import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../tuner_state.dart';
import 'note_wheel.dart';

class PitchDisplay extends StatelessWidget {
  final TunerStateMachine sm;

  const PitchDisplay({super.key, required this.sm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = sm.state;
    final color = s == TunerState.inTune
        ? AppColors.pitchInTune
        : s == TunerState.locked
            ? const Color(0xFF534AB7)
            : s == TunerState.detecting
                ? const Color(0xFF1D9E75)
                : Colors.grey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Note wheel — horizontal chromatic carousel ──
        NoteWheel(currentNote: sm.noteDisplay, color: color),
        const SizedBox(height: 4),
        // ── Frequency + octave ──
        Text(
          '${sm.displayFrequency.toStringAsFixed(1)} Hz',
          style: theme.textTheme.bodyLarge?.copyWith(color: color),
        ),
        const SizedBox(height: 12),
        // ── Needle gauge ──
        _NeedleGauge(cents: sm.displayCents, color: color),
        const SizedBox(height: 4),
        // ── Status ──
        Text(
          s == TunerState.idle
              ? 'Listening…'
              : s == TunerState.detecting
                  ? 'Detecting…'
                  : s == TunerState.locked
                      ? 'Locked'
                      : 'In Tune ✓',
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _NeedleGauge extends StatelessWidget {
  final double cents;
  final Color color;
  const _NeedleGauge({required this.cents, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: CustomPaint(
        painter: _NeedlePainter(cents: cents, color: color),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  final double cents;
  final Color color;

  _NeedlePainter({required this.cents, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final pivotY = 16.0;
    final bottomY = 70.0;
    final maxAngle = pi / 3; // ±60° for ±50 cents
    final angle = (cents / 50.0).clamp(-1.0, 1.0) * maxAngle;

    // ✓ zone marker (green bar at center)
    final zonePaint = Paint()..color = AppColors.pitchInTune.withAlpha(60);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(centerX, bottomY - 4), width: 20, height: 8),
        zonePaint);

    // Scale baseline
    canvas.drawLine(Offset(16, bottomY), Offset(size.width - 16, bottomY),
        Paint()..color = Colors.grey.withAlpha(60)..strokeWidth = 0.5);

    // Tick marks
    for (final tick in [-50, -25, -10, 0, 10, 25, 50]) {
      final tx = centerX + (tick / 50.0) * (size.width / 2 - 16) * 0.9;
      final h = tick == 0 ? 12.0 : (tick.abs() == 50 ? 6.0 : 4.0);
      canvas.drawLine(Offset(tx, bottomY - h), Offset(tx, bottomY),
          Paint()..color = tick == 0 ? AppColors.pitchInTune : Colors.grey.withAlpha(80));

      // Label
      final tp = TextPainter(
        text: TextSpan(text: '${tick.abs()}', style: TextStyle(fontSize: 9, color: Colors.grey.withAlpha(120))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, bottomY + 4));
    }

    // Needle
    final needleLen = bottomY - pivotY;
    final dx = needleLen * sin(angle);
    final dy = needleLen * cos(angle);
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, pivotY),
      Offset(centerX + dx, pivotY + dy),
      needlePaint,
    );

    // Pivot dot
    canvas.drawCircle(Offset(centerX, pivotY), 4,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);

    // Deviation label
    final label = '${cents > 0 ? "+" : ""}${cents.toStringAsFixed(1)}¢';
    final lp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(centerX - lp.width / 2, pivotY + needleLen + 4));
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => cents != old.cents || color != old.color;
}

