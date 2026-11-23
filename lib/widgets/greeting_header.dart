import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The "Good Morning, [Name]" greeting-card widget style the designer
/// pointed to directly in a comment ("use these style of widgets to
/// showcase user info") — avatar + time-aware greeting + name, with a
/// bell/notification affordance.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    this.photoUrl,
    this.onBellTap,
  });

  final String name;
  final String? photoUrl;
  final VoidCallback? onBellTap;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = name.trim().split(' ').first;
    return Row(
      children: [
        _Avatar(photoUrl: photoUrl, fallback: name),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: AppTextStyles.bodyMuted),
              Text(firstName, style: AppTextStyles.headline),
            ],
          ),
        ),
        _BellButton(onTap: onBellTap),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.photoUrl, required this.fallback});

  final String? photoUrl;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final initial = fallback.trim().isEmpty ? '?' : fallback.trim()[0].toUpperCase();
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.cloud,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.mist, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: (photoUrl != null && photoUrl!.isNotEmpty)
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _InitialAvatar(initial: initial),
            )
          : _InitialAvatar(initial: initial),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(initial, style: AppTextStyles.title.copyWith(color: AppColors.ink)),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.cloud,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
      ),
    );
  }
}
