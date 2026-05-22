import 'package:flutter/material.dart';

class PlayheadOverlay extends StatefulWidget {
  final bool visible;
  final double? lockedX;
  final ValueChanged<double>? onPositionSelected;

  const PlayheadOverlay({
    super.key,
    this.visible = false,
    this.lockedX,
    this.onPositionSelected,
  });

  @override
  State<PlayheadOverlay> createState() => _PlayheadOverlayState();
}

class _PlayheadOverlayState extends State<PlayheadOverlay> {
  double _x = 200;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final x = widget.lockedX ?? _x;
    final isLocked = widget.lockedX != null;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: isLocked
            ? null
            : (d) => setState(() => _x = (_x + d.delta.dx).clamp(20.0, 600.0)),
        onPanEnd: isLocked
            ? null
            : (_) => widget.onPositionSelected?.call(_x),
        child: Stack(
          children: [
            Positioned(
              left: x - 1.5, top: 0, bottom: 0,
              child: Container(
                width: 3,
                color: Colors.amber.withAlpha(180),
              ),
            ),
            if (!isLocked)
              Positioned(
                left: x - 10, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    width: 20, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(120),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.drag_handle, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
