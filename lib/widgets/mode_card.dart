import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pressable_scale.dart';

/// The big black "Walkie Talkie Mode" / "Inter-Com Mode" choice cards from
/// the Figma home frame — kept oversized and high-contrast per the brief
/// ("bigger widgets so it's easier to use"), with a subtle glow and press
/// animation so the pair feels like the single most important choice on
/// the screen, which it is.
class ModeCard extends StatelessWidget {
  const ModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scaleDown: 0.97,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent ? AppColors.accent : AppColors.paper.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.paper, size: 28),
            ),
            const SizedBox(height: 28),
            Text(title, style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.body.copyWith(color: AppColors.slateLight),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Start',
                  style: AppTextStyles.title.copyWith(color: AppColors.paper),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.paper, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
