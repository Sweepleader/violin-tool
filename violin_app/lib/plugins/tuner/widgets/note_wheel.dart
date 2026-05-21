import 'package:flutter/material.dart';

/// Horizontal chromatic wheel — center note highlighted, adjacent notes semi-transparent.
/// When the detected note changes, the wheel rotates left or right like a mechanical dial.
class NoteWheel extends StatefulWidget {
  final String currentNote;
  final Color color;

  const NoteWheel({
    super.key,
    required this.currentNote,
    required this.color,
  });

  @override
  State<NoteWheel> createState() => _NoteWheelState();
}

class _NoteWheelState extends State<NoteWheel>
    with SingleTickerProviderStateMixin {
  static const _chromatic = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _prevIndex = 0;
  int _targetIndex = 0;
  double _offset = 0; // current display offset in slot units

  @override
  void initState() {
    super.initState();
    _targetIndex = _noteIndex(widget.currentNote);
    _prevIndex = _targetIndex;
    _offset = _targetIndex.toDouble();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() {
      setState(() {
        _offset = _prevIndex + (_targetIndex - _prevIndex) * _anim.value;
      });
    });
  }

  @override
  void didUpdateWidget(NoteWheel old) {
    super.didUpdateWidget(old);
    if (old.currentNote != widget.currentNote) {
      _prevIndex = _targetIndex; // start from where we ended
      _targetIndex = _noteIndex(widget.currentNote);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _noteIndex(String note) {
    final match = RegExp(r'^([A-G]#?)').firstMatch(note);
    if (match == null) return 0;
    final idx = _chromatic.indexOf(match.group(1)!);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    const slotWidth = 56.0;
    const visibleSlots = 9;
    final totalSlots = visibleSlots + 2; // extra for smooth wrapping

    final centerSlot = totalSlots ~/ 2;
    final centerOffset = _offset - centerSlot;

    return SizedBox(
      height: 64,
      child: ClipRect(
        child: Stack(
          children: List.generate(totalSlots, (slot) {
            // Which chromatic note to show at this slot
            final slotCenter = centerOffset + slot;
            final noteIdx = (slotCenter.round() % 12 + 12) % 12;
            final dist = (slotCenter - _offset).abs(); // distance from true center

            // Opacity falls off with distance
            final opacity = (1.0 - (dist / 4.5).clamp(0.0, 1.0) * 0.85);
            final scale = 1.0 - (dist / 6.0).clamp(0.0, 0.4);

            final isCenter = dist < 0.5;

            return Positioned(
              left: slot * slotWidth,
              top: 0,
              bottom: 0,
              width: slotWidth,
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      _chromatic[noteIdx],
                      style: TextStyle(
                        fontSize: isCenter ? 40 : 24,
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
