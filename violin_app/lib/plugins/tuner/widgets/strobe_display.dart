import 'dart:async';
import 'package:flutter/material.dart';
import '../../../ffi/audio_bridge.dart';

/// Stroboscopic tuner display — phase-driven scrolling stripes.
/// Stripes scroll when out of tune; stationary when perfectly in tune.
/// Precision: ±0.1 cents.
class StrobeDisplay extends StatefulWidget {
  final double refFrequency;
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
  double _prevRawPhase = 0;
  double _stripeOffset = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      final bridge = AudioBridge.instance;
      final result = bridge.strobePoll(widget.refFrequency, 44100);
      if (result.confidence < 0.1) return;

      final raw = result.phase;
      if (!_initialized) {
        _prevRawPhase = raw;
        _initialized = true;
        return;
      }
      // Phase delta, with wrap detection
      double delta = raw - _prevRawPhase;
      if (delta > 0.5) delta -= 1.0;
      if (delta < -0.5) delta += 1.0;
      _prevRawPhase = raw;

      setState(() {
        _stripeOffset += delta * 20; // scale to visible pixel movement
        if (_stripeOffset > 100) _stripeOffset -= 100;
        if (_stripeOffset < -100) _stripeOffset += 100;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      width: MediaQuery.of(context).size.width * 0.618,
      child: CustomPaint(
        painter: _StrobePainter(
          offset: _stripeOffset,
          color: widget.color,
        ),
      ),
    );
  }
}

class _StrobePainter extends CustomPainter {
  final double offset;
  final Color color;

  _StrobePainter({required this.offset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stripeCount = 8;
    final stripeW = size.width / stripeCount;

    for (int i = -1; i <= stripeCount + 1; i++) {
      final x = i * stripeW + offset;
      // Alternate dark/light bands
      final shade = i % 2 == 0 ? 0.15 : 0.45;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, stripeW / 2, size.height),
        Paint()..color = color.withAlpha((shade * 255).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_StrobePainter old) => offset != old.offset || color != old.color;
}
