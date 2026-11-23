import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ride_plan.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pressable_scale.dart';

/// One shared ride in the Nearby Rides feed: host, title, time, meeting
/// point and a tag for which comms mode the group will use.
class RidePlanCard extends StatelessWidget {
  const RidePlanCard({super.key, required this.plan, this.onTap});

  final RidePlan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('EEE, MMM d · h:mm a').format(plan.rideTime);
    return PressableScale(
      onTap: onTap ?? () {},
      scaleDown: 0.985,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cloud,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.mist,
                  backgroundImage: (plan.hostPhotoUrl != null && plan.hostPhotoUrl!.isNotEmpty)
                      ? NetworkImage(plan.hostPhotoUrl!)
                      : null,
                  child: (plan.hostPhotoUrl == null || plan.hostPhotoUrl!.isEmpty)
                      ? Text(plan.hostName.isNotEmpty ? plan.hostName[0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(plan.hostName, style: AppTextStyles.title),
                ),
                _ModeTag(mode: plan.mode),
              ],
            ),
            const SizedBox(height: 16),
            Text(plan.title, style: AppTextStyles.title.copyWith(fontSize: 18)),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(plan.description, style: AppTextStyles.bodyMuted, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 14),
            _InfoRow(icon: Icons.schedule_rounded, text: timeLabel),
            if (plan.meetingPoint.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.place_rounded, text: plan.meetingPoint),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.mode});

  final RideCommsMode mode;

  @override
  Widget build(BuildContext context) {
    final isWalkie = mode == RideCommsMode.walkieTalkie;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWalkie ? AppColors.ink : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        mode.label,
        style: AppTextStyles.label.copyWith(
          color: isWalkie ? AppColors.paper : AppColors.accent,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.slate),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppTextStyles.bodyMuted)),
      ],
    );
  }
}
