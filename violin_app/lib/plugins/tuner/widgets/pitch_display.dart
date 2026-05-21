import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../instrument_config.dart';
import '../tuner_state.dart';
import 'note_wheel.dart';
import 'string_wheel.dart';

class PitchDisplay extends StatelessWidget {
  final TunerStateMachine sm;
  final InstrumentConfig instrument;

  const PitchDisplay({
    super.key,
    required this.sm,
    required this.instrument,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = sm.state;
    final color = s == TunerState.inTune
        ? AppColors.pitchInTune
        : s == TunerState.locked
            ? AppColors.tunerLocked
            : s == TunerState.detecting
                ? AppColors.tunerDetect
                : Colors.grey;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── String wheel ──
          StringWheel(
            frequency: sm.displayFrequency,
            color: color,
            instrument: instrument,
          ),
          const SizedBox(height: 4),
          // ── Note wheel ──
          NoteWheel(currentNote: sm.noteDisplay, color: color),
          const SizedBox(height: 4),
          // ── Frequency ──
          Text(
            '${sm.displayFrequency.toStringAsFixed(1)} Hz',
            style: theme.textTheme.bodyLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 16),
          // ── Needle gauge ──
          SizedBox(
            height: 90,
            width: MediaQuery.of(context).size.width * 0.618,
            child: CustomPaint(
              painter: _NeedlePainter(cents: sm.displayCents, color: color),
            ),
          ),
          const SizedBox(height: 4),
          // ── Deviation ──
          Text(
            _deviationText(sm.displayCents),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _deviationText(double cents) {
    final abs = cents.abs();
    if (abs < 2) return 'In Tune';
    return '${cents > 0 ? "+" : ""}${cents.toStringAsFixed(1)} \u{00A2}';
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
    final maxAngle = pi / 3;
    final angle = (cents / 50.0).clamp(-1.0, 1.0) * maxAngle;

    // In-tune zone
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(centerX, bottomY - 4), width: 20, height: 8),
      Paint()..color = AppColors.pitchInTune.withAlpha(60),
    );

    // Baseline
    final margin = size.width * 0.05;
    canvas.drawLine(
      Offset(margin, bottomY),
      Offset(size.width - margin, bottomY),
      Paint()..color = Colors.grey.withAlpha(60)..strokeWidth = 0.5,
    );

    // Ticks
    for (final tick in [-50, -25, -10, 0, 10, 25, 50]) {
      final tx = centerX + (tick / 50.0) * (size.width / 2 - margin) * 0.9;
      final h = tick == 0 ? 12.0 : (tick.abs() == 50 ? 6.0 : 4.0);
      canvas.drawLine(
        Offset(tx, bottomY - h), Offset(tx, bottomY),
        Paint()..color = tick == 0 ? AppColors.pitchInTune : Colors.grey.withAlpha(80),
      );
      final tp = TextPainter(
        text: TextSpan(
            text: '${tick.abs()}',
            style: TextStyle(fontSize: 9, color: Colors.grey.withAlpha(120))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, bottomY + 4));
    }

    // Needle
    final needleLen = bottomY - pivotY;
    final dx = needleLen * sin(angle);
    final dy = needleLen * cos(angle);
    canvas.drawLine(
      Offset(centerX, pivotY),
      Offset(centerX + dx, pivotY + dy),
      Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(centerX, pivotY), 4,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => cents != old.cents || color != old.color;
}
