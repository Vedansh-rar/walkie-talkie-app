import 'package:flutter/material.dart';

/// The big hold-to-talk button. [onStart]/[onStop] fire on press and
/// release — including a release caused by the finger sliding off the
/// button, so the mic never gets stuck open.
class PttButton extends StatelessWidget {
  final bool isTalking;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const PttButton({super.key, required this.isTalking, required this.onStart, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final color = isTalking ? Colors.redAccent : Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTapDown: (_) => onStart(),
      onTapUp: (_) => onStop(),
      onTapCancel: onStop,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 24, spreadRadius: isTalking ? 6 : 0),
          ],
        ),
        child: Icon(isTalking ? Icons.mic : Icons.mic_none, color: Colors.white, size: 64),
      ),
    );
  }
}
