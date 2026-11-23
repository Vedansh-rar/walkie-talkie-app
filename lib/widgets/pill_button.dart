import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pressable_scale.dart';

enum PillButtonStyle { dark, light, outline }

/// The rounded "pill" CTA style called out in the designer's own comment
/// ("buttons like this") — big, finger-friendly, with a press animation.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PillButtonStyle.dark,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final PillButtonStyle style;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bg = switch (style) {
      PillButtonStyle.dark => AppColors.ink,
      PillButtonStyle.light => AppColors.paper,
      PillButtonStyle.outline => Colors.transparent,
    };
    final fg = switch (style) {
      PillButtonStyle.dark => AppColors.paper,
      PillButtonStyle.light => AppColors.ink,
      PillButtonStyle.outline => AppColors.ink,
    };
    final border = style == PillButtonStyle.outline
        ? Border.all(color: AppColors.mist, width: 1.4)
        : null;

    return PressableScale(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(29),
          border: border,
          boxShadow: style == PillButtonStyle.dark
              ? [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
              ),
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              icon!,
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
