import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The floating pill-shaped nav bar with a center cutout, from the Figma
/// "home" frame (a black rounded bar with a notch and a separate circular
/// action sitting in it) and the moodboard comment "navigation like this".
///
/// Exactly 3 real destinations (Home / Nearby Rides / Profile) live in the
/// pill; the notch holds a single raised FAB for "Share Ride Plan", which
/// isn't a tab — it's an action — so it never shows a selected state.
class RydioBottomNav extends StatelessWidget {
  const RydioBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFabTap;

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.near_me_rounded, label: 'Nearby'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavIcon(item: _items[0], index: 0, current: currentIndex, onTap: onTap),
                  _NavIcon(item: _items[1], index: 1, current: currentIndex, onTap: onTap),
                  const SizedBox(width: 56), // room for the floating FAB
                  _NavIcon(item: _items[2], index: 2, current: currentIndex, onTap: onTap),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: _FabButton(onTap: onFabTap),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.item,
    required this.index,
    required this.current,
    required this.onTap,
  });

  final ({IconData icon, String label}) item;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.paper.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color: selected ? AppColors.paper : AppColors.slateLight,
              size: 24,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 5 : 0,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabButton extends StatefulWidget {
  const _FabButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.paper, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: AppColors.paper, size: 30),
        ),
      ),
    );
  }
}
