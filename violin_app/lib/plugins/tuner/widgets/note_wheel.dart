import 'package:flutter/material.dart';

/// Horizontal chromatic wheel — center note highlighted, adjacent notes semi-transparent.
/// When the detected note changes, the wheel rotates left or right.
class NoteWheel extends StatefulWidget {
  final String currentNote;
  final Color color;

  const NoteWheel({super.key, required this.currentNote, required this.color});

  @override
  State<NoteWheel> createState() => _NoteWheelState();
}

class _NoteWheelState extends State<NoteWheel>
    with SingleTickerProviderStateMixin {
  static const _chromatic = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  static const _slotW = 52.0;
  static const _visibleSlots = 9;

  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _prevIdx = 0, _targetIdx = 0;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _targetIdx = _noteIndex(widget.currentNote);
    _prevIdx = _targetIdx;
    _offset = _targetIdx.toDouble();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(
        () => setState(() => _offset = _prevIdx + (_targetIdx - _prevIdx) * _anim.value));
  }

  @override
  void didUpdateWidget(NoteWheel old) {
    super.didUpdateWidget(old);
    if (old.currentNote != widget.currentNote) {
      _prevIdx = _targetIdx;
      _targetIdx = _noteIndex(widget.currentNote);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  int _noteIndex(String note) {
    final m = RegExp(r'^([A-G]#?)').firstMatch(note);
    if (m == null) return 0;
    return _chromatic.indexOf(m.group(1)!).clamp(0, 11);
  }

  @override
  Widget build(BuildContext context) {
    final visW = _visibleSlots * _slotW;
    // Items span far enough to cover sliding in from either edge
    final pad = 6;
    final totalSlots = _visibleSlots + pad * 2;

    return SizedBox(
      height: 64,
      width: visW,
      child: ClipRect(
        child: Stack(
          children: List.generate(totalSlots, (i) {
            final slotX = (i - _offset + 0.5) * _slotW; // 0.5 centers active slot
            final dist = (i - _offset - pad).abs();
            final isCenter = dist < 0.5;
            final opacity = (1.0 - (dist / 4.5).clamp(0.0, 1.0) * 0.82);
            final scale = 1.0 - (dist / 6.0).clamp(0.0, 0.4);
            final idx = (i % 12 + 12) % 12;

            return Positioned(
              left: slotX,
              top: 0, bottom: 0,
              width: _slotW,
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      _chromatic[idx],
                      style: TextStyle(
                        fontSize: isCenter ? 38 : 22,
                        fontWeight: isCenter ? FontWeight.w700 : FontWeight.w400,
                        color: isCenter ? widget.color : widget.color.withAlpha(80),
                        height: 1,
                      ),
                    ),
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
