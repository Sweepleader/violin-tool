import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../tuner_state.dart';

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
        // ── Note name + octave ──
        _NoteBlock(sm: sm, color: color),
        const SizedBox(height: 8),
        // ── Needle gauge ──
        _NeedleGauge(cents: sm.displayCents, color: color),
        const SizedBox(height: 8),
        // ── Chromatic strip ──
        _ChromaticStrip(
          currentNote: sm.noteDisplay,
          frequency: sm.displayFrequency,
          color: color,
        ),
        const SizedBox(height: 12),
        // ── Status text ──
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

class _NoteBlock extends StatelessWidget {
  final TunerStateMachine sm;
  final Color color;
  const _NoteBlock({required this.sm, required this.color});

  @override
  Widget build(BuildContext context) {
    final note = sm.noteDisplay;
    // Extract note name and octave
    final match = RegExp(r'^([A-G]#?)(\d+)?').firstMatch(note);
    final name = match?.group(1) ?? note;
    final octave = match?.group(2) ?? '';

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        border: Border.all(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(name,
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1)),
          ),
          if (octave.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(octave,
                    style: TextStyle(fontSize: 13, color: color)),
              ),
            ),
        ],
      ),
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

class _ChromaticStrip extends StatelessWidget {
  final String currentNote;
  final double frequency;
  final Color color;
  const _ChromaticStrip({
    required this.currentNote,
    required this.frequency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const all = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final match = RegExp(r'^([A-G]#?)').firstMatch(currentNote);
    final curName = match?.group(1) ?? '';
    final idx = all.indexOf(curName);

    final notes = <String>[];
    for (int i = -4; i <= 4; i++) {
      final ni = (idx + i + 12) % 12;
      notes.add(all[ni]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: notes.map((n) {
              final active = n == curName;
              return Container(
                width: 28,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? color.withAlpha(40) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: active ? Border.all(color: color.withAlpha(100)) : null,
                ),
                child: Text(n,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? color : Colors.grey.withAlpha(100))),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text('${frequency.toStringAsFixed(1)} Hz',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
