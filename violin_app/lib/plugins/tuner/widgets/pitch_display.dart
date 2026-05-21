import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../instrument_config.dart';
import '../tuner_state.dart';
import 'note_wheel.dart';
import 'string_wheel.dart';
import 'strobe_display.dart';

class PitchDisplay extends StatelessWidget {
  final TunerStateMachine sm;
  final InstrumentConfig instrument;
  final bool strobeMode;
  final VoidCallback? onToggleMode;

  const PitchDisplay({
    super.key,
    required this.sm,
    required this.instrument,
    this.strobeMode = false,
    this.onToggleMode,
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
          // ── Needle gauge / Strobe ──
          if (strobeMode)
            StrobeDisplay(
              refFrequency:
                  instrument.stringFreqs[instrument.stringNames.indexOf(
                      instrument.closestString(sm.displayFrequency))],
              detectedFrequency: sm.displayFrequency,
              color: color,
            )
          else
            SizedBox(
              height: 90,
              width: MediaQuery.of(context).size.width * 0.618,
              child: CustomPaint(
                painter: _NeedlePainter(cents: sm.displayCents, color: color),
              ),
            ),
          const SizedBox(height: 4),
          // ── Deviation ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _deviationText(sm.displayCents),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onToggleMode != null) ...[
                const SizedBox(width: 16),
                _ModeButton(
                    label: 'Needle', active: !strobeMode, onTap: onToggleMode),
                const SizedBox(width: 4),
                _ModeButton(
                    label: 'Strobe', active: strobeMode, onTap: onToggleMode),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _deviationText(double cents) {
    final abs = cents.abs();
    if (abs < 2) return 'In Tune';
    return '${cents > 0 ? "+" : ""}${cents.toStringAsFixed(1)} c';
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _ModeButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? Colors.white.withAlpha(60) : Colors.grey.withAlpha(40)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: active ? Colors.white : Colors.grey.withAlpha(120))),
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
    final maxAngle = pi / 3;
    final angle = (cents / 50.0).clamp(-1.0, 1.0) * maxAngle;

    // Needle geometry (shared by ticks)
    final needleLen = bottomY - pivotY;

    // Ticks — positioned along the same arc as the needle
    for (final tick in [-50, -25, -10, 0, 10, 25, 50]) {
      final tickAngle = (tick / 50.0).clamp(-1.0, 1.0) * maxAngle;
      final tx = centerX + needleLen * sin(tickAngle);
      final ty = pivotY + needleLen * cos(tickAngle);
      final h = tick == 0 ? 12.0 : (tick.abs() == 50 ? 6.0 : 4.0);
      canvas.drawLine(
        Offset(tx, ty - h),
        Offset(tx, ty + 2),
        Paint()..color = tick == 0 ? AppColors.pitchInTune : Colors.grey.withAlpha(80),
      );
      final tp = TextPainter(
        text: TextSpan(
            text: '${tick.abs()}',
            style: TextStyle(fontSize: 9, color: Colors.grey.withAlpha(120))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, ty + 6));
    }

    // Needle
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
