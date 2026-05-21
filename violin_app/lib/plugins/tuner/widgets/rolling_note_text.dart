import 'package:flutter/material.dart';

/// Character-by-character rolling text — like Apple calendar wheel or split-flap display.
/// When [text] changes, each character animates upward individually.
class RollingNoteText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const RollingNoteText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<RollingNoteText> createState() => _RollingNoteTextState();
}

class _RollingNoteTextState extends State<RollingNoteText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  String _old = '';
  String _new = '';

  @override
  void initState() {
    super.initState();
    _old = widget.text;
    _new = widget.text;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(
        parent: _controller, curve: Curves.easeOutCubic);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(RollingNoteText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _old = oldWidget.text;
      _new = widget.text;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Map individual characters to rolling offsets
  static final _chars = 'ABCDEFG#0123456789-';
  int _charIndex(String ch) => _chars.indexOf(ch);

  @override
  Widget build(BuildContext context) {
    final t = _anim.value;
    final oldLen = _old.length;
    final newLen = _new.length;
    final maxLen = oldLen > newLen ? oldLen : newLen;

    return SizedBox(
      height: _measure(widget.style, '0').height * 1.1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(maxLen, (i) {
          final oldCh = i < oldLen ? _old[i] : '';
          final newCh = i < newLen ? _new[i] : '';
          if (oldCh == newCh) {
            return Text(oldCh, style: widget.style);
          }
          return _RollingChar(
            oldChar: oldCh,
            newChar: newCh,
            t: t,
            style: widget.style,
          );
        }),
      ),
    );
  }

  Size _measure(TextStyle style, String text) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    return tp.size;
  }
}

class _RollingChar extends StatelessWidget {
  final String oldChar;
  final String newChar;
  final double t;
  final TextStyle style;

  const _RollingChar({
    required this.oldChar,
    required this.newChar,
    required this.t,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final h = _measure(style, '0').height;
    // Old slides UP and out; new slides UP from below
    return SizedBox(
      width: _measure(style, oldChar.isEmpty ? newChar : oldChar).width,
      height: h,
      child: ClipRect(
        child: Stack(
          children: [
            // New — slides up from below
            Positioned(
              top: h * (1 - t),
              child: Text(newChar, style: style),
            ),
            // Old — slides up and fades
            Positioned(
              top: h * (1 - t) - h * t,
              child: Opacity(
                opacity: 1 - t,
                child: Text(oldChar, style: style),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Size _measure(TextStyle style, String text) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    return tp.size;
  }
}
