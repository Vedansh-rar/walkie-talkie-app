import 'package:flutter/material.dart';

/// Wraps any widget with a small, premium press-down animation — the kind
/// of tactile detail that makes big tappable cards and buttons feel
/// physical instead of flat. Shared by [ModeCard], [PillButton] and the
/// ride-plan cards so every "big widget" in the app responds the same way.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
