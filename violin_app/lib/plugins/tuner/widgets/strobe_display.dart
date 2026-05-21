import 'dart:async';
import 'package:flutter/material.dart';
import '../../../ffi/audio_bridge.dart';

/// Peterson-style stroboscopic tuner.
/// 8 horizontal bands, each representing a harmonic of the reference frequency.
/// Band scroll speed = frequency error × harmonic multiplier.
/// All bands stationary = perfectly in tune.
class StrobeDisplay extends StatefulWidget {
  final double refFrequency; // target frequency (e.g., A4 = 440.0)
  final Color color;

  const StrobeDisplay({
    super.key,
    required this.refFrequency,
    required this.color,
  });

  @override
  State<StrobeDisplay> createState() => _StrobeDisplayState();
}

class _StrobeDisplayState extends State<StrobeDisplay> {
  Timer? _timer;
  double _prevPhase = 0;
  bool _init = false;

  // 8 harmonic bands: 1×, 2×, 3×, 4×, 5×, 6×, 7×, 8×
  static const _bandCount = 8;
  final List<double> _offsets = List.filled(_bandCount, 0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), _poll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _poll(Timer t) {
    final bridge = AudioBridge.instance;
    final result = bridge.strobePoll(widget.refFrequency, 44100);
    if (result.confidence < 0.1) return;

    if (!_init) {
      _prevPhase = result.phase;
      _init = true;
      return;
    }

    // Phase delta with wrap-around detection
    double delta = result.phase - _prevPhase;
    if (delta > 0.5) delta -= 1.0;
    if (delta < -0.5) delta += 1.0;
    _prevPhase = result.phase;

    // delta > 0 → input is sharp (higher freq → phase advances)
    // delta < 0 → input is flat
    if (delta.abs() < 1e-6) return; // no change, skip setState

    setState(() {
      for (int i = 0; i < _bandCount; i++) {
        _offsets[i] += delta * (i + 1) * 120; // harmonic multiplier × visual scale
        // Keep offsets bounded to avoid floating point drift
        if (_offsets[i] > 1000) _offsets[i] -= 1000;
        if (_offsets[i] < -1000) _offsets[i] += 1000;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const bandH = 10.0;
    const gap = 1.0;
    final w = MediaQuery.of(context).size.width * 0.618;

    return SizedBox(
      height: _bandCount * (bandH + gap) + 4,
      width: w,
      child: ClipRect(
        child: Column(
          children: List.generate(_bandCount, (i) {
            // Top bands = higher harmonics = more sensitive
            final idx = _bandCount - 1 - i;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _bandCount - 1 ? gap : 0),
              child: SizedBox(
                height: bandH,
                child: CustomPaint(
                  painter: _StrobeBandPainter(
                    offset: _offsets[idx],
                    harmonic: idx + 1,
                    color: widget.color,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StrobeBandPainter extends CustomPainter {
  final double offset;
  final int harmonic;
  final Color color;

  _StrobeBandPainter({
    required this.offset,
    required this.harmonic,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stripeW = 14.0;
    final count = (size.width / stripeW).ceil() + 2;

    // Higher harmonics use thinner, more transparent stripes for subtlety
    final alpha = (0.25 + harmonic * 0.07).clamp(0.3, 0.7);

    for (int s = -1; s <= count; s++) {
      final x = s * stripeW + (offset % stripeW);
      final shade = s % 2 == 0 ? alpha : alpha * 0.3;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, stripeW / 2, size.height),
        Paint()..color = color.withAlpha((shade * 255).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_StrobeBandPainter old) =>
      offset != old.offset || color != old.color;
}
