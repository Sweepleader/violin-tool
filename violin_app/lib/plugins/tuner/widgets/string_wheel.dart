import 'package:flutter/material.dart';
import '../instrument_config.dart';

/// Horizontal violin string wheel — G-D-A-E, 4 positions.
/// The closest string to current frequency is highlighted.
/// When the string changes, the wheel rotates like a mechanical dial.
class StringWheel extends StatefulWidget {
  final double frequency;
  final Color color;
  final InstrumentConfig instrument;

  const StringWheel({
    super.key,
    required this.frequency,
    required this.color,
    required this.instrument,
  });

  @override
  State<StringWheel> createState() => _StringWheelState();
}

class _StringWheelState extends State<StringWheel>
    with SingleTickerProviderStateMixin {
  static const _slotW = 52.0;
  static const _visibleSlots = 9; // same as note wheel for alignment
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _prevIdx = 0, _targetIdx = 0;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _targetIdx = _stringIndex(widget.frequency);
    _prevIdx = _targetIdx;
    _offset = _targetIdx.toDouble();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(
        () => setState(() => _offset = _prevIdx + (_targetIdx - _prevIdx) * _anim.value));
  }

  @override
  void didUpdateWidget(StringWheel old) {
    super.didUpdateWidget(old);
    if (old.frequency != widget.frequency) {
      _prevIdx = _targetIdx;
      _targetIdx = _stringIndex(widget.frequency);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  int _stringIndex(double freq) {
    final name = widget.instrument.closestString(freq);
    return widget.instrument.stringNames.indexOf(name);
  }

  @override
  Widget build(BuildContext context) {
    final visW = _visibleSlots * _slotW;
    final pad = 6;
    final totalSlots = _visibleSlots + pad * 2;
    final strings = widget.instrument.stringNames;

    return SizedBox(
      height: 44,
      width: visW,
      child: ClipRect(
        child: Stack(
          children: List.generate(totalSlots, (i) {
            final slotX = (i - _offset + 0.5) * _slotW;
            final dist = (i - _offset - pad).abs();
            final isCenter = dist < 0.5;

            // Map slot to a string label (wrap around the 4 strings)
            final sIdx = (i % 4 + 4) % 4;
            // Only show strings, hide padding slots
            final stringPos = (sIdx - _offset).abs();
            final visible = stringPos < 5; // hide far-away strings

            return Positioned(
              left: slotX, top: 0, bottom: 0, width: _slotW,
              child: visible
                  ? Center(
                      child: Opacity(
                        opacity: isCenter ? 1.0 : 0.35,
                        child: Text(
                          strings[sIdx],
                          style: TextStyle(
                            fontSize: isCenter ? 32 : 20,
                            fontWeight: isCenter ? FontWeight.w700 : FontWeight.w400,
                            color: isCenter ? widget.color : widget.color.withAlpha(80),
                            height: 1,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(),
            );
          }),
        ),
      ),
    );
  }
}
